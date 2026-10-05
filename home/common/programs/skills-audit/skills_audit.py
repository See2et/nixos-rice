"""Capture skill updates and run a tool-free Codex audit of pinned source text."""

import argparse
import difflib
import hashlib
import json
import os
from pathlib import Path
import shlex
import signal
import stat
import subprocess
import sys
import tempfile
import tomllib
from urllib.parse import urlencode, urlsplit

ASSETS = Path(__file__).resolve().parent
REPOSITORY = Path("/etc/nixos")
MAX_FILE = 128 * 1024
MAX_TEXT = 512 * 1024
MAX_FILES = 2000
MAX_PROMPT = 512 * 1024
TIMEOUT = 600
# This is an identity list, not a declaration that these sources are safe.
PERSONAL = {("github", "See2et", "agent-skills")}
DISABLED_FEATURES = (
    "plugins", "remote_plugin", "hooks", "apps", "browser_use",
    "browser_use_external", "computer_use", "in_app_browser", "shell_tool",
    "unified_exec", "code_mode", "code_mode_host", "skill_search",
    "skill_mcp_dependency_install",
)


def dump(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(path)


def display(value):
    # Escape control characters from filenames/URLs before showing them on a terminal.
    return json.dumps(str(value), ensure_ascii=False)


def resolve(lock, reference, seen=()):
    if isinstance(reference, str):
        return reference
    key = tuple(reference)
    if key in seen:
        raise ValueError("cyclic follows in lock")
    node = lock["root"]
    for name in reference:
        node = resolve(lock, lock["nodes"][node]["inputs"][name], (*seen, key))
    return node


def sources(lock):
    nodes = lock["nodes"]
    root = nodes[lock["root"]]
    if "skills" not in root.get("inputs", {}):
        return {}
    result = {}

    def walk(reference, path, ancestors):
        node_id = resolve(lock, reference)
        if node_id in ancestors:
            raise ValueError("cyclic skills input")
        node = nodes[node_id]
        if path != "skills":
            result[path] = {k: node[k] for k in ("locked", "original", "flake") if k in node}
        for name, child in node.get("inputs", {}).items():
            walk(child, path + "/" + name, (*ancestors, node_id))

    walk(root["inputs"]["skills"], "skills", ())
    return result


def identity(source):
    if not source:
        return None
    locked = source.get("locked", {})
    if locked.get("type") == "github":
        return ("github", locked.get("owner"), locked.get("repo"))
    if locked.get("type") == "git":
        parsed = urlsplit(locked.get("url", ""))
        parts = parsed.path.strip("/").removesuffix(".git").split("/")
        if parsed.hostname == "github.com" and len(parts) == 2:
            return ("github", *parts)
    return None


def significant(source):
    if not source:
        return None
    value = json.loads(json.dumps(source))
    for key in ("lastModified", "revCount"):
        value.get("locked", {}).pop(key, None)
    return value


def changes(before, after):
    old, new = sources(before), sources(after)
    result = []
    for name in sorted(old.keys() | new.keys()):
        previous, current = old.get(name), new.get(name)
        if significant(previous) == significant(current):
            continue
        personal = identity(current or previous) in PERSONAL
        # A change of origin, even to an allowlisted repository, needs automatic review.
        if previous and current and identity(previous) != identity(current):
            personal = False
        result.append({"name": name, "before": previous, "after": current,
                       "classification": "personal" if personal else "external"})
    return result


def pinned_url(source):
    locked = source["locked"]
    revision = locked.get("rev", "")
    if len(revision) != 40 or any(c not in "0123456789abcdef" for c in revision):
        raise ValueError("source has no supported immutable revision")
    kind = locked.get("type")
    if kind == "github":
        owner, repo = locked["owner"], locked["repo"]
        if any(not item or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-" for c in item) for item in (owner, repo)):
            raise ValueError("invalid GitHub identity")
        return f"github:{owner}/{repo}/{revision}"
    if kind == "git":
        url = locked["url"]
        parsed = urlsplit(url)
        if parsed.scheme not in ("ssh", "https") or not parsed.hostname or parsed.query or parsed.fragment:
            raise ValueError("unsupported Git source URL")
        query = {"rev": revision}
        if "ref" in locked:
            query["ref"] = locked["ref"]
        return "git+" + url + "?" + urlencode(query)
    raise ValueError("unsupported source type; inspect manually")


def fetch(source):
    # prefetch fetches source trees without evaluating their flake or executing scripts.
    fetched = subprocess.run(["nix", "flake", "prefetch", "--json", pinned_url(source)],
                             text=True, capture_output=True, timeout=120, check=True)
    data = json.loads(fetched.stdout)
    if data.get("hash") != source["locked"].get("narHash"):
        raise ValueError("prefetched hash does not match saved lock")
    return Path(data["storePath"])


def inventory(root, budget):
    texts, skipped = {}, []
    count = 0
    for directory, dirs, files in os.walk(root, followlinks=False):
        dirs.sort()
        files.sort()
        for name in list(dirs):
            path = Path(directory) / name
            if path.is_symlink():
                skipped.append(str(path.relative_to(root)) + ": symlink directory")
                dirs.remove(name)
            elif name == ".git":
                dirs.remove(name)
        for name in files:
            path = Path(directory) / name
            relative = str(path.relative_to(root))
            count += 1
            if count > MAX_FILES:
                skipped.append("remaining files: file-count limit")
                return texts, skipped
            info = path.lstat()
            if not stat.S_ISREG(info.st_mode):
                skipped.append(relative + ": symlink or non-regular file")
                continue
            if info.st_size > MAX_FILE or info.st_size > budget[0]:
                skipped.append(relative + ": text-size limit")
                continue
            raw = path.read_bytes()
            try:
                text = raw.decode("utf-8")
                if "\x00" in text:
                    raise UnicodeError()
            except UnicodeError:
                skipped.append(relative + ": binary or non-UTF-8")
                continue
            budget[0] -= len(raw)
            texts[relative] = text
    return texts, skipped


def prepare(record):
    manifest = json.loads((record / "manifest.json").read_text())
    payload = []
    unreviewed = []
    budget = [MAX_TEXT]
    for change in manifest["changes"]:
        item = dict(change)
        versions = {}
        for version in ("after", "before"):
            if not change[version]:
                versions[version] = {}
                continue
            try:
                root = fetch(change[version])
                texts, skipped = inventory(root, budget)
                versions[version] = texts
                unreviewed.extend(f"{change['name']} {version}: {s}" for s in skipped)
            except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
                versions[version] = {}
                # Do not persist arbitrary subprocess stderr (which may contain credentials).
                unreviewed.append(f"{change['name']} {version}: source unavailable ({type(error).__name__})")
        item["files"] = {}
        for name in sorted(versions["before"].keys() | versions["after"].keys()):
            old = versions["before"].get(name, "")
            new = versions["after"].get(name, "")
            item["files"][name] = {
                "before": "\n".join(f"{i}: {line}" for i, line in enumerate(old.splitlines(), 1)),
                "after": "\n".join(f"{i}: {line}" for i, line in enumerate(new.splitlines(), 1)),
                "diff": "".join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                                     fromfile="before/" + name, tofile="after/" + name)),
            }
        payload.append(item)
    instruction = (ASSETS / "prompt.txt").read_text()
    def encode():
        return instruction + "\n" + json.dumps({"sources": payload, "unreviewed": unreviewed}, ensure_ascii=False)
    prompt = encode()
    # Numbering and unified diffs can amplify input size substantially.
    while len(prompt.encode()) > MAX_PROMPT:
        largest = max(((len(json.dumps(data)), item, name)
                       for item in payload for name, data in item["files"].items()),
                      key=lambda entry: entry[0], default=None)
        if largest is None:
            raise ValueError("audit metadata exceeds prompt limit")
        _, item, name = largest
        del item["files"][name]
        unreviewed.append(f"{item['name']}: {name}: prompt-size limit")
        prompt = encode()
    dump(record / "payload.json", {"sources": payload, "unreviewed": unreviewed})
    (record / "prompt.txt").write_text(prompt)
    manifest["unreviewed"] = unreviewed
    manifest["prompt_sha256"] = hashlib.sha256(prompt.encode()).hexdigest()
    dump(record / "manifest.json", manifest)
    return manifest


def isolation_overrides(ignore_user_config=True):
    """System defaults survive ignore-user-config; explicitly disable local integrations."""
    codehome = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
    servers, system_servers, skill_paths = set(), set(), set()
    for path in (Path("/etc/codex/config.toml"), Path("/etc/codex/managed_config.toml"), codehome / "config.toml"):
        if not path.exists():
            continue
        config = tomllib.loads(path.read_text())
        servers.update(config.get("mcp_servers", {}))
        if path != codehome / "config.toml":
            system_servers.update(config.get("mcp_servers", {}))
        for entry in config.get("skills", {}).get("config", []):
            if "path" in entry:
                skill_paths.add(str(Path(entry["path"]).expanduser().resolve()))
    for root in (Path.home() / ".agents/skills", codehome / "skills", Path("/etc/codex/skills")):
        if root.exists():
            visited = set()
            for directory, dirs, files in os.walk(root, followlinks=True):
                canonical = Path(directory).resolve()
                if canonical in visited:
                    dirs.clear()
                    continue
                visited.add(canonical)
                if len(visited) > 10000:
                    raise ValueError("installed skill discovery exceeds isolation limit")
                if "SKILL.md" in files:
                    path = Path(directory) / "SKILL.md"
                    # Support canonical and discovered paths, folder and file forms.
                    for candidate in (path, path.parent, path.resolve(), path.resolve().parent):
                        skill_paths.add(str(candidate))
    entries = ",".join("{path=" + json.dumps(path) + ",enabled=false}" for path in sorted(skill_paths))
    overrides = ["-c", "skills.config=[" + entries + "]", "-c", "mcp_servers={}"]
    for name in sorted(servers):
        if not name or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in name):
            raise ValueError("MCP name cannot be safely overridden")
        # Ignored user servers have no transport in the resulting config. Supply a
        # harmless transport so validation succeeds, while leaving them disabled.
        overrides += ["-c", "mcp_servers." + name + ".enabled=false"]
        if ignore_user_config and name not in system_servers:
            overrides += ["-c", "mcp_servers." + name + '.command="false"']
    return overrides


def codex_command(workspace, output):
    command = ["codex", "--no-daemon", "-a", "never", "exec", "--strict-config", "--ignore-user-config",
               "--ignore-rules", "--ephemeral", "--skip-git-repo-check", "--json",
               "--sandbox", "read-only", "-C", str(workspace),
               "--model", "gpt-6.1-sol", "-c", 'model_reasoning_effort="high"',
               "--enable", "skip_host_skill_discovery", "-c", "project_doc_max_bytes=0",
               "-c", "suppress_unstable_features_warning=true",
               "-c", 'web_search="disabled"', "--output-schema", str(ASSETS / "result.schema.json"),
               "--output-last-message", str(output)]
    for feature in DISABLED_FEATURES:
        command += ["--disable", feature]
    return command + isolation_overrides() + ["-"]


def verify_context(workspace, attempt):
    # This local debug command renders context without making an inference request.
    command = ["codex", "--no-daemon", "-C", str(workspace), "-a", "never",
               "--enable", "skip_host_skill_discovery", "-c", "project_doc_max_bytes=0",
               "-c", 'web_search="disabled"']
    for feature in DISABLED_FEATURES:
        command += ["--disable", feature]
    command += isolation_overrides(ignore_user_config=False) + ["debug", "prompt-input", "Audit context check."]
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    (attempt / "context-check.log").write_text(result.stderr)
    if result.returncode:
        raise ValueError("Codex context preflight failed; see context-check.log")
    context = json.loads(result.stdout)
    if not isinstance(context, list):
        raise ValueError("unsupported Codex context format")
    if "### Available skills" in json.dumps(context):
        raise ValueError("Skills catalog remains in audit context")
    dump(attempt / "context-check.json", {"skills_catalog_present": False})


def run_process(command, prompt, events, errors):
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=events, stderr=errors,
                               start_new_session=True)
    try:
        process.communicate(prompt.encode(), timeout=TIMEOUT)
        return process.returncode
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        raise


def validate_result(result):
    if set(result) != {"status", "summary", "findings", "unreviewed"}:
        raise ValueError("invalid result keys")
    if result["status"] not in ("findings", "no_findings", "incomplete") or not isinstance(result["summary"], str):
        raise ValueError("invalid result status")
    if not isinstance(result["findings"], list) or not isinstance(result["unreviewed"], list) or not all(isinstance(s, str) for s in result["unreviewed"]):
        raise ValueError("invalid result arrays")
    for finding in result["findings"]:
        if not isinstance(finding, dict) or set(finding) != {"source", "file", "line", "evidence", "impact"}:
            raise ValueError("invalid finding")
        if type(finding["line"]) is not int or finding["line"] < 1 or not all(isinstance(finding[k], str) for k in ("source", "file", "evidence", "impact")):
            raise ValueError("invalid finding fields")


def review(record):
    record = record.resolve(strict=True)
    manifest = json.loads((record / "manifest.json").read_text())
    # Retry an unavailable fetch; otherwise reuse the exact previously saved prompt.
    if not (record / "prompt.txt").exists() or manifest.get("unreviewed"):
        manifest = prepare(record)
    prompt = (record / "prompt.txt").read_text()
    if hashlib.sha256(prompt.encode()).hexdigest() != manifest["prompt_sha256"]:
        raise ValueError("saved prompt has changed")
    attempt = Path(tempfile.mkdtemp(prefix="attempt-", dir=record))
    (attempt / "prompt.txt").write_text(prompt)
    workspace = attempt / "workspace"
    workspace.mkdir()
    result = {"status": "incomplete", "summary": "監査は未完了です。",
              "findings": [], "unreviewed": []}
    try:
        verify_context(workspace, attempt)
        with (attempt / "events.jsonl").open("wb") as events, (attempt / "stderr.log").open("wb") as errors:
            code = run_process(codex_command(workspace, attempt / "answer.json"), prompt, events, errors)
        if code:
            raise ValueError(f"Codex exited with status {code}; see stderr.log")
        result = json.loads((attempt / "answer.json").read_text())
        validate_result(result)
        for line in (attempt / "events.jsonl").read_text().splitlines():
            event = json.loads(line)
            item = event.get("item", {})
            if event.get("type") in ("error", "turn.failed"):
                raise ValueError("Codex reported a failed turn")
            if item.get("type") == "error" and item.get("message", "").startswith(
                "Code Mode is unavailable because code-mode host is disabled."
            ):
                # This diagnostic confirms an intentionally disabled execution tool.
                continue
            if event.get("type", "").startswith("item.") and item.get("type") not in ("agent_message", "reasoning"):
                raise ValueError("Codex attempted tool use; audit environment requires inspection")
        result["unreviewed"] = sorted(set(result["unreviewed"] + manifest.get("unreviewed", [])))
        # Derive the status rather than trusting a contradictory model label.
        if result["unreviewed"] or result["status"] == "incomplete":
            result["status"] = "incomplete"
        elif result["findings"]:
            result["status"] = "findings"
        elif result["status"] == "findings":
            raise ValueError("findings status without findings")
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        result = {"status": "incomplete", "summary": "監査は未完了です。",
                  "findings": [], "unreviewed": [str(error) or type(error).__name__]}
    dump(attempt / "result.json", result)
    dump(record / "result.json", result)
    labels = {"findings": "指摘あり", "no_findings": "確認範囲で指摘なし", "incomplete": "未完了"}
    print("Skills監査: " + labels[result["status"]] + f"（指摘{len(result['findings'])}件）")
    print("結果: " + display(attempt / "result.json"))
    print("再実行: skills-audit " + shlex.quote(str(record)))
    return 0 if result["status"] != "incomplete" else 1


def target(args):
    # Only recognize unambiguous update invocations; never reinterpret other Nix commands.
    if args[:2] != ["flake", "update"]:
        return None
    value = None
    for i, arg in enumerate(args[2:], 2):
        if arg == "--flake":
            if i + 1 >= len(args):
                return None
            value = args[i + 1]
        elif arg.startswith("--flake="):
            value = arg.split("=", 1)[1]
        elif arg in ("--output-lock-file", "--reference-lock-file", "--no-write-lock-file", "--commit-lock-file") or arg.startswith(("--output-lock-file=", "--reference-lock-file=")):
            return None
    if value is None:
        return Path.cwd().resolve()
    if value.startswith("path:"):
        value = value[5:]
    if ":" in value or "?" in value or "#" in value:
        return None
    return Path(value).resolve()


def update(args):
    repo = target(args)
    if repo != REPOSITORY.resolve():
        return subprocess.call(["nix", *args])
    cache = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "skills-audit"
    try:
        cache.mkdir(mode=0o700, parents=True, exist_ok=True)
        cache.chmod(0o700)
        record = Path(tempfile.mkdtemp(prefix="update-", dir=cache))
        before = (repo / "flake.lock").read_bytes()
        (record / "before.lock").write_bytes(before)
    except OSError:
        print("Skills監査: 更新前記録を保存できないため未完了。Nix更新は実行します。", file=sys.stderr)
        return subprocess.call(["nix", *args])
    code = subprocess.call(["nix", *args])
    if code:
        print("Skills監査: Nix更新失敗。更新前lock: " + display(record / "before.lock"), file=sys.stderr)
        return code
    try:
        after = (repo / "flake.lock").read_bytes()
        (record / "after.lock").write_bytes(after)
        changed = changes(json.loads(before), json.loads(after))
        if not changed:
            print("Skills監査: Skillsの変更なし。")
            return 0
        dump(record / "manifest.json", {"changes": changed})
        for change in changed:
            print("Skills更新: " + change["classification"] + " " + display(change["name"]))
        print("手動確認・再実行: skills-audit " + shlex.quote(str(record)))
        if any(change["classification"] == "external" for change in changed):
            review(record)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        print("Skills監査: 未完了 (" + type(error).__name__ + ")。保存先: " + display(record), file=sys.stderr)
    # An audit failure does not change the successful Nix update's exit status.
    return 0


def main():
    os.umask(0o077)
    if len(sys.argv) > 1 and sys.argv[1] == "update":
        return update(sys.argv[2:])
    parser = argparse.ArgumentParser(description="保存したSkills更新をCodexで監査する")
    parser.add_argument("mode", choices=["review"])
    parser.add_argument("record", type=Path)
    args = parser.parse_args()
    try:
        return review(args.record)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print("Skills監査: 未完了 (" + type(error).__name__ + "): " + display(str(error)), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
