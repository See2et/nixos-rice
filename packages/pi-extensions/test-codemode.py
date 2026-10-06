import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("codemode", Path(__file__).with_name("configure-codemode.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CodeModeSettings(unittest.TestCase):
    def apply(self, data):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            path.write_text(json.dumps(data))
            module.configure(path)
            first = path.read_bytes()
            module.configure(path)
            self.assertEqual(path.read_bytes(), first)
            return json.loads(first)

    def test_missing_defaults_preserve_other_settings(self):
        data = {"defaultProvider": "openai", "defaultModel": "gpt-6.1-sol", "defaultThinkingLevel": "medium", "piNotify": {"notifyTools": ["custom"]}, "custom": {"value": 5}}
        actual = self.apply(data)
        for key, value in data.items():
            self.assertEqual(actual[key], value)
        self.assertEqual(actual["defaultTools"], ["+codemode"])
        self.assertEqual(actual["codemode"], {"mode": "on"})

    def test_explicit_disabled_builtin_tools_stay_disabled(self):
        self.assertEqual(self.apply({"defaultTools": []})["defaultTools"], ["codemode"])
        self.assertEqual(self.apply({"defaultTools": ["read", "-bash"]})["defaultTools"], ["read", "-bash", "codemode"])

    def test_modifiers_preserve_selection_and_enable_explicitly(self):
        actual = self.apply({"defaultTools": ["-bash", "+grep", "-codemode"], "extensions": ["-builtin:codemode", "-builtin:mcp", "/custom.ts"]})
        self.assertEqual(actual["defaultTools"], ["-bash", "+grep", "+codemode"])
        self.assertEqual(actual["extensions"], ["-builtin:mcp", "/custom.ts"])

    def test_existing_codemode_mode_and_budget_preserved(self):
        actual = self.apply({"defaultTools": ["codemode", "read"], "codemode": {"mode": "only", "inlineBudget": 500}})
        self.assertEqual(actual["defaultTools"], ["read", "codemode"])
        self.assertEqual(actual["codemode"], {"mode": "only", "inlineBudget": 500})

    def test_invalid_input_does_not_rewrite(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            for data in ({"defaultTools": None}, {"defaultTools": "read"}, {"codemode": []}, {"extensions": [5]}):
                path.write_text(json.dumps(data))
                before = path.read_bytes()
                with self.assertRaises(ValueError):
                    module.configure(path)
                self.assertEqual(path.read_bytes(), before)

    def test_symlink_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "owned.json"
            target.write_text("{}")
            link = Path(directory) / "settings.json"
            link.symlink_to(target)
            with self.assertRaises(ValueError):
                module.configure(link)
            self.assertTrue(link.is_symlink())
            self.assertEqual(target.read_text(), "{}")


if __name__ == "__main__":
    unittest.main()
