import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("configure-mcp.py")
URL = "https://miloa-beta.comni.pl/w/69f1f3e11d1ab359d844ba89/mcp"


class McpConfigTests(unittest.TestCase):
    def configure(self, path):
        return subprocess.run([sys.executable, str(SCRIPT), str(path), URL], capture_output=True, text=True)

    def test_create_merge_and_idempotence_without_touching_auth(self):
        with tempfile.TemporaryDirectory() as directory:
            agent = Path(directory)
            path = agent / "nested/mcp.json"
            auth = agent / "nested/mcp-auth.json"
            for existing in (None, {
                "autoEnableCodemode": False,
                "mcpServers": {
                    "other": {"command": "custom", "env": {"TOKEN": "fixture"}},
                    "miloa": {"url": "https://old.example/mcp", "enabled": False,
                              "exposure": "hidden", "oauth": {"clientId": "local"}},
                },
            }):
                with self.subTest(existing=existing):
                    path.parent.mkdir(parents=True, exist_ok=True)
                    auth.write_text("local auth fixture")
                    if existing is not None:
                        path.write_text(json.dumps(existing))
                    result = self.configure(path)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    expected = existing or {"mcpServers": {"miloa": {}}}
                    expected["mcpServers"]["miloa"]["url"] = URL
                    self.assertEqual(json.loads(path.read_text()), expected)
                    before = (path.read_bytes(), path.stat().st_mtime_ns)
                    self.assertEqual(self.configure(path).returncode, 0)
                    self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), before)
                    self.assertEqual(auth.read_text(), "local auth fixture")
                    self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_invalid_input_and_symlink_are_not_rewritten(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "mcp.json"
            for content in ("invalid JSON", "[]", '{"mcpServers": null}',
                            '{"mcpServers": {"miloa": []}}'):
                with self.subTest(content=content):
                    path.write_text(content)
                    self.assertNotEqual(self.configure(path).returncode, 0)
                    self.assertEqual(path.read_text(), content)
            target = Path(directory) / "owned.json"
            target.write_text("{}")
            path.unlink()
            path.symlink_to(target)
            self.assertNotEqual(self.configure(path).returncode, 0)
            self.assertTrue(path.is_symlink())
            self.assertEqual(target.read_text(), "{}")


if __name__ == "__main__":
    unittest.main()
