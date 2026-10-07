#!/usr/bin/env python3
"""Offline command integration: synthetic repo, real Git, fake Nix/npm/prefetch.

Protect routing and transaction boundaries, not npm's dependency resolver or Nix's
builder. The real configured Pi build is a separate integration gate.
"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "pi-extensions/update.py"
spec = importlib.util.spec_from_file_location("updater", SCRIPT)
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)

FAKE_TOOL = '''#!PYTHON
import json, os, pathlib, subprocess, sys
p = pathlib.Path.cwd()
args = sys.argv[1:]
tool = pathlib.Path(sys.argv[0]).name
with open(os.environ["TOOL_LOG"], "a") as log:
    log.write(json.dumps([tool, *args]) + "\\n")
stage = "hash" if tool == "prefetch-npm-deps" else ("build" if args[:1] == ["build"] else tool)
if os.environ.get("FAIL") == stage:
    print("synthetic " + stage + " failure", file=sys.stderr)
    sys.exit(7)
if tool == "nix" and args[:2] == ["flake", "update"]:
    lock = json.loads((p / "flake.lock").read_text())
    parent = lock["nodes"][lock["nodes"][lock["root"]]["inputs"]["pi-extensions"]]
    entries = {e["name"]: e for e in json.loads((p / "pi-extensions/inventory.json").read_text())}
    child = (p / "pi-extensions/flake.nix").read_text()
    for route in args[2:]:
        assert route.startswith("pi-extensions/")
        name = route.split("/")[1]
        entry = entries[name]
        assert f"    {name} = {{" in child
        assert f'      url = "{entry["url"]}";' in child
        if name not in parent["inputs"]:
            parent["inputs"][name] = name
            lock["nodes"][name] = {"flake": False, "locked": {}, "original": {}}
        node = lock["nodes"][parent["inputs"][name]]
        if entry["url"].startswith("github:"):
            owner, repo = entry["url"].removeprefix("github:").split("/")
            node["original"] = {"type": "github", "owner": owner, "repo": repo}
            node["locked"].update(node["original"])
        node["locked"]["rev"] = "new-" + name
    if os.environ.get("UNRELATED"):
        lock["nodes"]["pi-nix"]["locked"]["rev"] = "unwanted-upgrade"
    (p / "flake.lock").write_text(json.dumps(lock))
elif tool == "npm" and args[0] == "view":
    assert args[1].endswith("@latest")
    print(json.dumps("99.0.0"))
elif tool == "npm" and args[0] == "install":
    for flag in ["--package-lock-only", "--ignore-scripts", "--legacy-peer-deps", "--save-exact"]:
        assert flag in args
    manifest = json.loads((p / "package.json").read_text())
    lock = json.loads((p / "package-lock.json").read_text())
    for argument in args[1:]:
        if not argument.startswith("--"):
            name, version = argument.rsplit("@", 1)
            assert version == "99.0.0"
            manifest["dependencies"][name] = version
            lock["packages"][""]["dependencies"][name] = version
            lock["packages"]["node_modules/" + name] = {"version": version}
    (p / "package.json").write_text(json.dumps(manifest))
    (p / "package-lock.json").write_text(json.dumps(lock))
elif tool == "prefetch-npm-deps":
    assert pathlib.Path(args[0]).is_file()
    print("sha256-eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHg=")
elif tool == "nix" and args[0] == "build":
    assert args[1:] == [".#pi", "--no-link", "--no-update-lock-file"]
    # Prove this is the current working tree, not HEAD-only, and new files are
    # visible to flakes. The live index itself must not be touched.
    assert (p / "user.txt").read_text() == "unstaged user change"
    assert (p / "new.nix").read_text() == "staged new source"
    assert "new.nix" in subprocess.check_output(["git", "ls-files"], text=True)
    original = pathlib.Path(os.environ["ORIGINAL_ROOT"])
    if os.environ.get("CONCURRENT"):
        (original / "user.txt").write_text("concurrent edit")
else:
    raise AssertionError([tool, args])
'''


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.repo = base / "repo"
        self.repo.mkdir()
        self.bin = base / "bin"
        self.bin.mkdir()
        for tool in ("nix", "npm", "prefetch-npm-deps"):
            target = self.bin / tool
            target.write_text(FAKE_TOOL.replace("PYTHON", sys.executable, 1))
            target.chmod(0o755)
        self.log = base / "tools.jsonl"
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"], TOOL_LOG=str(self.log), ORIGINAL_ROOT=str(self.repo), PYTHONDONTWRITEBYTECODE="1")
        for path in (*updater.MANAGED, updater.INVENTORY):
            target = self.repo / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / path, target)
        self.write("flake.nix", "{ outputs = _: {}; }")
        manifest = updater.read_json(self.repo / updater.NPM / "package.json")
        manifest["dependencies"]["user-only"] = "3.0.0"
        self.write(updater.NPM + "/package.json", json.dumps(manifest))
        lock = {"lockfileVersion": 3, "packages": {"": {"dependencies": manifest["dependencies"]}}}
        lock["packages"].update({"node_modules/" + n: {"version": v} for n, v in manifest["dependencies"].items()})
        self.write(updater.NPM + "/package-lock.json", json.dumps(lock))
        self.write("user.txt", "committed source")
        self.git("init", "-q")
        self.git("add", ".")
        self.git("-c", "user.name=Test", "-c", "user.email=test@invalid", "-c", "commit.gpgsign=false", "commit", "-qm", "fixture")
        # A staged lock change, unstaged Nix comment, staged new file, and an
        # unstaged working-tree change must all survive updates and failures.
        lock = updater.read_json(self.repo / "flake.lock")
        lock["nodes"]["pi-nix"]["locked"]["rev"] = "user-staged-pin"
        self.write("flake.lock", json.dumps(lock))
        self.git("add", "flake.lock")
        with open(self.repo / updater.NPM / "default.nix", "a") as f:
            f.write("\n# user unstaged comment\n")
        self.write("new.nix", "staged new source")
        self.git("add", "new.nix")
        self.write("user.txt", "unstaged user change")
        self.before = self.managed()
        self.index = self.git("diff", "--cached", "--binary")

    def write(self, path, content):
        (self.repo / path).write_text(content)

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True)

    def managed(self):
        return {p: (self.repo / p).read_bytes() for p in updater.MANAGED}

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def command(self, *names, **env):
        return subprocess.run([sys.executable, str(SCRIPT), *names], cwd=self.repo, env={**self.env, **env}, text=True, capture_output=True)

    def assert_preserved(self):
        self.assertEqual(self.index, self.git("diff", "--cached", "--binary"))
        self.assertEqual((self.repo / "user.txt").read_text(), "unstaged user change")
        self.assertIn("# user unstaged comment", (self.repo / updater.NPM / "default.nix").read_text())
        manifest = updater.read_json(self.repo / updater.NPM / "package.json")
        self.assertEqual(manifest["dependencies"]["user-only"], "3.0.0")
        lock = updater.read_json(self.repo / "flake.lock")
        self.assertEqual(lock["nodes"]["pi-nix"]["locked"]["rev"], "user-staged-pin")
        self.assertFalse((self.repo / "pi-extensions/flake.lock").exists())

    def test_all_and_named_routing(self):
        for names in ([], ["pi-interview"], ["pi-astraeus"], ["pi-astraeus", "pi-interview", "pi-interview"]):
            with self.subTest(names=names):
                # Restore only the disposable fixture between selections.
                for p, data in self.before.items():
                    (self.repo / p).write_bytes(data)
                if self.log.exists():
                    self.log.unlink()
                result = self.command(*names)
                self.assertEqual(result.returncode, 0, result.stderr)
                entries = updater.inventory(self.repo / updater.INVENTORY)
                selected = [e for e in entries if not names or e["name"] in names]
                expected_git = {e["name"] for e in selected if e["kind"] == "git"}
                expected_npm = {e["package"] for e in selected if e["kind"] == "npm"}
                calls = self.calls()
                routes = {arg.split("/")[1] for c in calls if c[:3] == ["nix", "flake", "update"] for arg in c[3:]}
                self.assertEqual(routes, expected_git)
                manifest = updater.read_json(self.repo / updater.NPM / "package.json")
                old = json.loads(self.before[updater.NPM + "/package.json"])
                for n, pin in old["dependencies"].items():
                    self.assertEqual(manifest["dependencies"][n], "99.0.0" if n in expected_npm else pin)
                self.assertEqual(sum(c[0] == "prefetch-npm-deps" for c in calls), bool(expected_npm))
                lock = updater.read_json(self.repo / "flake.lock")
                original = json.loads(self.before["flake.lock"])
                for e in entries:
                    if e["kind"] == "git":
                        n = e["name"]
                        self.assertEqual(lock["nodes"][n]["locked"]["rev"], "new-" + n if n in expected_git else original["nodes"][n]["locked"]["rev"])
                self.assertIn(["nix", "build", ".#pi", "--no-link", "--no-update-lock-file"], calls)
                self.assert_preserved()

    def test_validate_all_names_and_inventory_before_mutation(self):
        result = self.command("pi-interview", "missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unknown extension", result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.managed(), self.before)
        self.assertFalse((self.repo / ".git/update-pi-extensions.lock").exists())
        entries = updater.read_json(self.repo / updater.INVENTORY)
        entries.append(entries[0])
        self.write(updater.INVENTORY, json.dumps(entries))
        result = self.command()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate", result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.managed(), self.before)
        self.assert_preserved()

    def test_list_is_read_only(self):
        result = self.command("--list")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [e["name"] for e in updater.inventory(self.repo / updater.INVENTORY)])
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.managed(), self.before)
        self.assert_preserved()

    def test_tool_failures_do_not_publish(self):
        for stage in ("nix", "npm", "hash", "build"):
            with self.subTest(stage=stage):
                result = self.command(FAIL=stage)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("failed", result.stderr)
                self.assertEqual(self.managed(), self.before)
                self.assert_preserved()

    def test_unrelated_input_change_rejected(self):
        result = self.command("pi-astraeus", UNRELATED="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unrelated inputs", result.stderr)
        self.assertEqual(self.managed(), self.before)
        self.assert_preserved()

    def test_concurrent_source_edit_rejected(self):
        result = self.command("pi-interview", CONCURRENT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source changed", result.stderr)
        self.assertEqual(self.managed(), self.before)
        self.assertEqual((self.repo / "user.txt").read_text(), "concurrent edit")
        self.assertEqual(self.index, self.git("diff", "--cached", "--binary"))

    def test_new_npm_registration_only_needs_inventory(self):
        entries = updater.read_json(self.repo / updater.INVENTORY)
        entries.append({"name": "new-extension", "kind": "npm", "package": "new-extension"})
        self.write(updater.INVENTORY, json.dumps(entries))
        result = self.command("new-extension")
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = updater.read_json(self.repo / updater.NPM / "package.json")
        self.assertEqual(manifest["dependencies"].pop("new-extension"), "99.0.0")
        self.assertEqual(manifest, json.loads(self.before[updater.NPM + "/package.json"]))
        self.assert_preserved()

    def test_manual_generated_file_edit_is_not_discarded(self):
        original = (self.repo / updater.CHILD).read_text()
        edits = {
            "comment": original + "# user generated-file comment\n",
            "url": original.replace("github:tintinweb/pi-subagents", "github:example/user-source", 1),
            "name": original.replace("pi-subagents =", "pi-user-renamed =", 1),
        }
        for kind, content in edits.items():
            with self.subTest(kind=kind):
                self.write(updater.CHILD, content)
                before = self.managed()
                # Declaration-shaped edits must fail even when no Git update is
                # selected and the inventory-compatible lock could still build.
                result = self.command("pi-interview")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("manual edits", result.stderr)
                self.assertEqual(self.managed(), before)
                self.assertEqual(self.calls(), [])
                self.assertFalse((self.repo / ".git/update-pi-extensions.lock").exists())
                self.assert_preserved()

    def test_inventory_only_git_registration_and_source_sync(self):
        original = updater.read_json(self.repo / updater.INVENTORY)
        cases = {
            "registration": {"name": "pi-extra", "kind": "git", "url": "github:example/pi-extra"},
            "source-sync": {"name": "pi-subagents", "kind": "git", "url": "github:example/new-subagents-source", "packaging": "pi-subagents"},
        }
        for kind, change in cases.items():
            with self.subTest(kind=kind):
                for p, data in self.before.items():
                    (self.repo / p).write_bytes(data)
                if self.log.exists():
                    self.log.unlink()
                entries = [change if e["name"] == change["name"] else e for e in original]
                if not any(e["name"] == change["name"] for e in original):
                    entries.append(change)
                self.write(updater.INVENTORY, json.dumps(entries))
                # Only inventory has changed: the old generated checksum remains
                # valid, unlike a manually edited name or URL in the artifact.
                self.assertEqual((self.repo / updater.CHILD).read_bytes(), self.before[updater.CHILD])
                result = self.command(change["name"])
                self.assertEqual(result.returncode, 0, result.stderr)
                child = (self.repo / updater.CHILD).read_text()
                self.assertIn(f'    {change["name"]} = {{', child)
                self.assertIn(f'      url = "{change["url"]}";', child)
                updater.check_generated_child(child)
                calls = self.calls()
                self.assertEqual(calls, [
                    ["nix", "flake", "update", "pi-extensions/" + change["name"]],
                    ["nix", "build", ".#pi", "--no-link", "--no-update-lock-file"],
                ])
                lock = updater.read_json(self.repo / "flake.lock")
                parent = lock["nodes"][lock["nodes"][lock["root"]]["inputs"]["pi-extensions"]]
                node = lock["nodes"][parent["inputs"][change["name"]]]
                self.assertEqual(node["locked"]["rev"], "new-" + change["name"])
                self.assertEqual(node["original"]["repo"], change["url"].split("/")[1])
                for p in (updater.NPM + "/package.json", updater.NPM + "/package-lock.json", updater.NPM + "/default.nix"):
                    self.assertEqual((self.repo / p).read_bytes(), self.before[p])
                self.assert_preserved()

    def test_unsupported_git_aliases_rejected_before_mutation(self):
        original = updater.read_json(self.repo / updater.INVENTORY)
        for name in ("pi.extra", "1-extension", "if"):
            with self.subTest(name=name):
                self.write(updater.INVENTORY, json.dumps(original + [{"name": name, "kind": "git", "url": "github:example/source"}]))
                before = updater.source_state(self.repo)
                result = self.command(name)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("supported unquoted Nix identifier", result.stderr)
                self.assertIn(name, result.stderr)
                self.assertEqual(updater.source_state(self.repo), before)
                self.assertEqual(self.calls(), [])
                self.assertFalse((self.repo / ".git/update-pi-extensions.lock").exists())
                self.assert_preserved()

    def test_publish_write_failure_rolls_back(self):
        work = Path(self.temp.name) / "publish"
        work.mkdir()
        baseline = updater.source_state(self.repo)
        for p in updater.MANAGED:
            (work / p).parent.mkdir(parents=True, exist_ok=True)
            (work / p).write_bytes(self.before[p] + b"\nchanged")
        original = updater.atomic_write
        count = 0

        def failing_write(*args):
            nonlocal count
            count += 1
            if count == 2:
                raise OSError("synthetic write failure")
            original(*args)

        with patch.object(updater, "atomic_write", failing_write):
            with self.assertRaisesRegex(OSError, "write failure"):
                updater.publish(self.repo, work, baseline)
        self.assertEqual(self.managed(), self.before)
        self.assert_preserved()


class ArtifactTests(unittest.TestCase):
    def test_npm_aliases_keep_existing_naming_rules(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "inventory.json"
            entries = [{"name": "1.extra", "kind": "npm", "package": "@example/1.extra"}]
            path.write_text(json.dumps(entries))
            self.assertEqual(updater.inventory(path), entries)

    def test_generated_child_is_in_sync(self):
        self.assertEqual((ROOT / updater.CHILD).read_text(), updater.render_child(updater.inventory(ROOT / updater.INVENTORY)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
