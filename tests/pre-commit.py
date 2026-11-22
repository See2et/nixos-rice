#!/usr/bin/env python3
"""Exercise the real Husky/lint-staged hook and pinned formatter in disposable Git repos."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


def run(*argv, cwd=ROOT, env=None, check=True):
    return subprocess.run(argv, cwd=cwd, env=env, check=check, capture_output=True, text=True)


class PreCommit(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        system = run("nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem").stdout
        formatter = run(
            "nix", "build", "--no-link", "--print-out-paths", f".#formatter.{system}"
        ).stdout.strip()
        cls.formatter = Path(formatter) / "bin/treefmt-wrapper"

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="nixos-pre-commit-")
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name)
        self.env = os.environ.copy()
        for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "HUSKY"):
            self.env.pop(key, None)
        self.env["XDG_CONFIG_HOME"] = str(self.repo / "xdg")
        self.env["PATH"] = f"{self.repo / 'bin'}:{ROOT / 'node_modules/.bin'}:{self.env['PATH']}"
        (self.repo / "bin").mkdir()
        # Only substitute Nix's flake discovery: use the repository's actual pinned formatter.
        nix = self.repo / "bin/nix"
        nix.write_text(
            '#!/bin/sh\nset -eu\n[ "$1" = fmt ] && [ "$2" = -- ]\nshift 2\n'
            f'exec "{self.formatter}" --tree-root "$PWD" "$@"\n'
        )
        nix.chmod(0o755)
        run("git", "init", "--quiet", cwd=self.repo)
        (self.repo / ".husky").mkdir()
        shutil.copyfile(ROOT / ".husky/pre-commit", self.repo / ".husky/pre-commit")
        shutil.copyfile(ROOT / "package.json", self.repo / "package.json")
        (self.repo / ".gitignore").write_text("/bin/\n/xdg/\n/.husky/_/\n")
        (self.repo / "partial.nix").write_text("{\n  staged = 0;\n\n  unstaged = 0;\n}\n")
        run("git", "add", ".", cwd=self.repo)
        tree = run("git", "write-tree", cwd=self.repo).stdout.strip()
        env = self.env | {
            "GIT_AUTHOR_NAME": "Hook Test", "GIT_AUTHOR_EMAIL": "test@example.invalid",
            "GIT_COMMITTER_NAME": "Hook Test", "GIT_COMMITTER_EMAIL": "test@example.invalid",
        }
        commit = run("git", "commit-tree", tree, "-m", "fixture", cwd=self.repo, env=env).stdout.strip()
        run("git", "update-ref", "HEAD", commit, cwd=self.repo)
        run("node", str(ROOT / "node_modules/husky/bin.js"), cwd=self.repo, env=self.env)
        self.assertEqual(run("git", "config", "--get", "core.hooksPath", cwd=self.repo).stdout.strip(), ".husky/_")

    def hook(self):
        return run(str(self.repo / ".husky/_/pre-commit"), cwd=self.repo, env=self.env, check=False)

    def test_formats_staged_files_and_preserves_unstaged_edits(self):
        partial = self.repo / "partial.nix"
        partial.write_text("{\n  staged=1;\n\n  unstaged = 0;\n}\n")
        run("git", "add", "partial.nix", cwd=self.repo)
        partial.write_text("{\n  staged=1;\n\n  unstaged = 9;\n}\n")
        samples = {"with spaces.nix": "{value=1;}\n", "test.lua": "local x={a=1}\n", "test.json": '{"a":1}\n'}
        for name, content in samples.items():
            (self.repo / name).write_text(content)
            run("git", "add", name, cwd=self.repo)
        unrelated = self.repo / "untracked.nix"
        unrelated.write_text("{untouched=1;}\n")
        result = self.hook()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        staged = run("git", "show", ":partial.nix", cwd=self.repo).stdout
        self.assertIn("staged = 1;", staged)
        self.assertIn("unstaged = 0;", staged)
        self.assertIn("unstaged = 9;", partial.read_text())
        self.assertEqual(unrelated.read_text(), "{untouched=1;}\n")
        for name, original in samples.items():
            staged = run("git", "show", f":{name}", cwd=self.repo).stdout
            self.assertNotEqual(staged, original, name)
            self.assertEqual(staged, (self.repo / name).read_text(), name)
        self.assertEqual(run("git", "stash", "list", cwd=self.repo).stdout, "")

    def test_formatter_failure_blocks_hook_and_restores_changes(self):
        broken = self.repo / "broken.nix"
        broken.write_text("{ invalid = ; }\n")
        run("git", "add", "broken.nix", cwd=self.repo)
        before = run("git", "diff", "--cached", "--binary", cwd=self.repo).stdout
        result = self.hook()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(run("git", "diff", "--cached", "--binary", cwd=self.repo).stdout, before)
        self.assertEqual(broken.read_text(), "{ invalid = ; }\n")
        self.assertEqual(run("git", "stash", "list", cwd=self.repo).stdout, "")


if __name__ == "__main__":
    unittest.main()
