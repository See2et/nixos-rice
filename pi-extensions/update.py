#!/usr/bin/env python3
"""Update extension pins in an isolated, current-working-tree snapshot.

No Pi settings, live index, or activation is touched. External tool failures never
publish. Publication rolls back ordinary write errors, not process/host crashes.
"""
import argparse
import base64
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile

INVENTORY = "pi-extensions/inventory.json"
CHILD = "pi-extensions/flake.nix"
NPM = "packages/pi-extensions"
MANAGED = (CHILD, "flake.lock", f"{NPM}/package.json", f"{NPM}/package-lock.json", f"{NPM}/default.nix")
NAME = r"[a-z0-9][a-z0-9._-]*"
GIT_NAME = r"[a-z][a-z0-9_-]*"
NIX_KEYWORDS = {"assert", "else", "if", "in", "inherit", "let", "rec", "then", "with"}
PACKAGE = re.compile(rf"(?:@{NAME}/)?{NAME}")
HASH = re.compile(r'npmDepsHash\s*=\s*"(sha256-[A-Za-z0-9+/]{43}=)";')


class UpdateError(Exception):
    pass


def run(args, cwd, capture=False, env=None):
    print("+ " + " ".join(map(str, args)), file=sys.stderr)
    result = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE if capture else None, env=env)
    if result.returncode:
        raise UpdateError(f"{args[0]} failed (exit {result.returncode}); no update published")
    return result.stdout if capture else None


def read_json(path):
    return json.loads(path.read_text())


def inventory(path):
    entries = read_json(path)
    if not isinstance(entries, list) or not entries:
        raise UpdateError("inventory must be a nonempty ordered array")
    names, packages = set(), set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise UpdateError("inventory entries must be objects")
        name, kind = entry.get("name"), entry.get("kind")
        if not isinstance(name, str) or not PACKAGE.fullmatch(name) or name in names:
            raise UpdateError(f"invalid or duplicate extension name: {name!r}")
        names.add(name)
        if kind == "git":
            if not re.fullmatch(GIT_NAME, name) or name in NIX_KEYWORDS:
                raise UpdateError(f"Git input name must be a supported unquoted Nix identifier ({GIT_NAME}, excluding Nix keywords): {name}")
            url = entry.get("url")
            if not isinstance(url, str) or not url.startswith(("github:", "git+https://", "git+ssh://")) or any(c in url for c in ('"', '\\', '\n', '\r', '${')):
                raise UpdateError(f"invalid Git URL for {name}")
            if set(entry) - {"name", "kind", "url", "packaging", "agents"}:
                raise UpdateError(f"unknown metadata for {name}")
            if "packaging" in entry and entry["packaging"] != "pi-subagents":
                raise UpdateError(f"unsupported packaging for {name}")
            if "agents" in entry:
                agents = entry["agents"]
                if not isinstance(agents, dict) or set(agents) != {"prefix", "roles"} or not isinstance(agents["prefix"], str) or not re.fullmatch(NAME, agents["prefix"]):
                    raise UpdateError(f"invalid agents for {name}")
                roles = agents["roles"]
                if not isinstance(roles, list) or any(not isinstance(a, str) or not re.fullmatch(NAME, a) for a in roles) or len(set(roles)) != len(roles):
                    raise UpdateError(f"invalid agent roles for {name}")
        elif kind == "npm":
            package = entry.get("package")
            if set(entry) != {"name", "kind", "package"} or not isinstance(package, str) or not PACKAGE.fullmatch(package) or package in packages:
                raise UpdateError(f"invalid or duplicate npm package for {name}")
            packages.add(package)
        else:
            raise UpdateError(f"unknown route for {name}: {kind!r}")
    return entries


def render_child(entries):
    lines = ["{", '  # Generated from inventory.json by update.py; do not register inputs here.', '  description = "Pi extension Git sources (pins live in the root flake.lock)";', "", "  inputs = {"]
    for entry in entries:
        if entry["kind"] == "git":
            lines += [f'    {entry["name"]} = {{', f'      url = "{entry["url"]}";', '      flake = false;', '    };']
    lines += ["  };", "", "  # Never create a child flake.lock: the parent owns all revisions.", "  outputs = { ... }: { };", "}", ""]
    body = "\n".join(lines)
    checksum = hashlib.sha256(body.encode("utf-8")).hexdigest()
    return f"# Generated body SHA256: {checksum}\n{body}"


def check_generated_child(content):
    # The stored generation-time baseline catches accidental edits to names,
    # URLs, comments and outputs. It is not an adversarial integrity mechanism.
    # Inventory-only changes leave the OLD artifact intact and eligible for sync.
    header, separator, body = content.partition("\n")
    match = re.fullmatch(r"# Generated body SHA256: ([0-9a-f]{64})", header)
    if not separator or not match or match[1] != hashlib.sha256(body.encode("utf-8")).hexdigest():
        raise UpdateError("generated pi-extensions/flake.nix has manual edits or a missing generation checksum; move registrations to inventory and preserve other edits before updating")


def file_state(path):
    """Content and mode, including deletions and symlinks; no mtime assumptions."""
    if path.is_symlink():
        return ("link", os.readlink(path))
    if not path.exists():
        return None
    mode = path.stat().st_mode
    if not stat.S_ISREG(mode):
        raise UpdateError(f"not a regular source file: {path}")
    return ("file", stat.S_IMODE(mode), path.read_bytes())


def source_paths(root):
    raw = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root)
    paths = sorted(set(os.fsdecode(p) for p in raw.split(b"\0") if p))
    for p in paths:
        if Path(p).is_absolute() or ".." in Path(p).parts or ".git" in Path(p).parts:
            raise UpdateError(f"unsafe snapshot path: {p}")
    return paths


def source_state(root):
    return {p: file_state(root / p) for p in source_paths(root)}


def snapshot(root, dest, baseline):
    for p, state in baseline.items():
        if state is None:
            continue
        target = dest / p
        target.parent.mkdir(parents=True, exist_ok=True)
        if state[0] == "link":
            target.symlink_to(state[1])
        else:
            target.write_bytes(state[2])
            target.chmod(state[1])
    run(["git", "init", "-q"], dest)
    run(["git", "add", "--all"], dest)


def lock_tree(lock, node, seen=()):
    if node in seen:
        raise UpdateError("cyclic lock graph is not supported")
    if not isinstance(node, str):
        # Resolve follows paths from the lock root.
        ref = lock["root"]
        for part in node:
            ref = lock["nodes"][ref]["inputs"][part]
        return lock_tree(lock, ref, seen)
    value = lock["nodes"][node]
    return {**{k: v for k, v in value.items() if k != "inputs"}, "inputs": {k: lock_tree(lock, v, (*seen, node)) for k, v in value.get("inputs", {}).items()}}


def check_lock_preservation(before, after, selected):
    old = lock_tree(before, before["root"])
    new = lock_tree(after, after["root"])
    old_ext = old["inputs"].pop("pi-extensions")
    new_ext = new["inputs"].pop("pi-extensions")
    if old != new:
        raise UpdateError("Nix changed unrelated inputs; refusing publication")
    for name, tree in old_ext["inputs"].items():
        if name not in selected and new_ext["inputs"].get(name) != tree:
            raise UpdateError(f"Nix changed unselected Git input {name}; refusing publication")


def check_npm_preservation(before, after, selected):
    # npm may change the selected pins, but no other manifest data.
    for manifest in (before, after):
        for package in selected:
            manifest.get("dependencies", {}).pop(package, None)
    if before != after:
        raise UpdateError("npm changed unrelated direct dependencies or manifest fields; refusing publication")


def replace_hash(path, value):
    if not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", value) or len(base64.b64decode(value[7:], validate=True)) != 32:
        raise UpdateError(f"prefetch-npm-deps returned an invalid hash: {value!r}")
    content = path.read_text()
    if len(HASH.findall(content)) != 1:
        raise UpdateError("expected exactly one literal npmDepsHash in default.nix")
    path.write_text(HASH.sub(lambda _: f'npmDepsHash = "{value}";', content))


def stage_update(work, entries, selected):
    old_lock = read_json(work / "flake.lock")
    old_manifest = read_json(work / NPM / "package.json")
    check_generated_child((work / CHILD).read_text())
    (work / CHILD).write_text(render_child(entries))
    git_names = [e["name"] for e in selected if e["kind"] == "git"]
    npm_names = [e["package"] for e in selected if e["kind"] == "npm"]
    if git_names:
        run(["nix", "flake", "update", *[f"pi-extensions/{n}" for n in git_names]], work)
    if npm_names:
        env = dict(os.environ, npm_config_cache=str(work / ".npm-cache"))
        versions = []
        for name in npm_names:
            version = json.loads(run(["npm", "view", f"{name}@latest", "version", "--json"], work / NPM, capture=True, env=env))
            if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", version):
                raise UpdateError(f"registry returned no exact version for {name}: {version!r}")
            versions.append(f"{name}@{version}")
        # Keep cache and logs in the disposable snapshot, not the user's npm cache.
        run(["npm", "install", *versions, "--package-lock-only", "--ignore-scripts", "--legacy-peer-deps", "--save-exact"], work / NPM, env=env)
        check_npm_preservation(old_manifest, read_json(work / NPM / "package.json"), npm_names)
        value = run(["prefetch-npm-deps", str(work / NPM / "package-lock.json")], work, capture=True).strip()
        replace_hash(work / NPM / "default.nix", value)
    if (work / "pi-extensions/flake.lock").exists():
        raise UpdateError("unexpected child flake.lock; refusing publication")
    check_lock_preservation(old_lock, read_json(work / "flake.lock"), git_names)
    # Snapshot additions must be visible to the Git flake without touching live index.
    run(["git", "add", "--", *MANAGED, INVENTORY], work)
    run(["nix", "build", ".#pi", "--no-link", "--no-update-lock-file"], work)
    # A build must not mutate lock inputs either.
    check_lock_preservation(old_lock, read_json(work / "flake.lock"), git_names)


def atomic_write(path, data, mode):
    fd, temp = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
        os.chmod(temp, mode)
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def publish(root, work, baseline):
    if source_state(root) != baseline or (root / "pi-extensions/flake.lock").exists():
        raise UpdateError("source changed while updating; retry after reviewing concurrent edits")
    changes = {p: file_state(work / p) for p in MANAGED if file_state(work / p) != baseline.get(p)}
    for p, value in changes.items():
        if value is None or value[0] != "file" or (baseline.get(p) or (None,))[0] != "file":
            raise UpdateError(f"managed artifact must already be a tracked regular file: {p}")
    written = []
    try:
        for p, value in changes.items():
            if file_state(root / p) != baseline[p]:
                raise UpdateError(f"concurrent edit to {p}; refusing overwrite")
            atomic_write(root / p, value[2], baseline[p][1])
            written.append(p)
    except BaseException:
        for p in reversed(written):
            # Never roll back someone else's edit that occurred after our write.
            if file_state(root / p) == changes[p]:
                try:
                    atomic_write(root / p, baseline[p][2], baseline[p][1])
                except OSError as error:
                    print(f"ROLLBACK FAILED for {p}: {error}; restore from your reviewed diff", file=sys.stderr)
        raise
    return list(changes)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Update all Pi extensions, or only the named extensions. Validate and build in a temporary snapshot before publishing pins. Run from the repository checkout.")
    parser.add_argument("names", nargs="*", help="inventory extension names (multiple allowed; default: all)")
    parser.add_argument("--list", action="store_true", help="list extension names without updating")
    args = parser.parse_args(argv)
    try:
        root = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())
        entries = inventory(root / INVENTORY)
        by_name = {e["name"]: e for e in entries}
        unknown = sorted(set(args.names) - by_name.keys())
        if unknown:
            raise UpdateError(f"unknown extension(s): {', '.join(unknown)}; use --list")
        if args.list:
            for entry in entries:
                print(entry["name"])
            return 0
        selected = [by_name[n] for n in dict.fromkeys(args.names)] if args.names else entries
        check_generated_child((root / CHILD).read_text())
        # Everything above is read-only. Serialize updater runs, not user editors.
        git_lock = subprocess.check_output(["git", "rev-parse", "--git-path", "update-pi-extensions.lock"], cwd=root, text=True).strip()
        with open(root / git_lock, "a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise UpdateError("another extension updater is running") from None
            if (root / "pi-extensions/flake.lock").exists():
                raise UpdateError("remove the child flake.lock; only the root lock owns extension pins")
            baseline = source_state(root)
            for p in (*MANAGED, INVENTORY):
                if (baseline.get(p) or (None,))[0] != "file":
                    raise UpdateError(f"required source file is missing/untracked or not regular: {p}")
            with tempfile.TemporaryDirectory(prefix="pi-extension-update-") as temp:
                work = Path(temp)
                snapshot(root, work, baseline)
                if source_state(root) != baseline:
                    raise UpdateError("source changed while taking snapshot; retry")
                stage_update(work, entries, selected)
                changed = publish(root, work, baseline)
        print("Updated: " + (", ".join(changed) if changed else "no pin changes"))
        print("Review the diff. Activation remains user-only; use your normal rollout gate.")
        return 0
    except (UpdateError, OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print(f"update-pi-extensions: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
