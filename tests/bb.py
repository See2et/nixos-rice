#!/usr/bin/env python3
"""Safety boundaries for shared agent configuration and bb's private route."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


merge = load("agent_config", "home/common/programs/merge-agent-config.py")
tailnet = load("bb_tailnet", "modules/nixos/desktop/scripts/bb-tailnet.py")


class ConfigTests(unittest.TestCase):
    def test_merge_preserves_auth_and_other_servers_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            original = json.dumps({"oauth": {"token": "private"}, "mcpServers": {
                "other": {"command": "keep"},
                "miloa": {"url": "old", "oauth": {"token": "also-private"}},
            }})
            path.write_text(original)
            patch = {"mcpServers": {"miloa": {"url": "https://mcp.miloa.io"}}}
            merge.apply(path, patch)
            first = path.read_bytes()
            updated = json.loads(first)
            self.assertEqual(updated["oauth"], {"token": "private"})
            self.assertEqual(updated["mcpServers"]["other"], {"command": "keep"})
            self.assertEqual(updated["mcpServers"]["miloa"], {
                "url": "https://mcp.miloa.io", "oauth": {"token": "also-private"},
            })
            merge.apply(path, patch)
            self.assertEqual(path.read_bytes(), first)
            backup = path.with_name(path.name + ".pre-nix-bb")
            self.assertEqual(backup.read_text(), original)
            self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_invalid_or_linked_configuration_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text("not json")
            with self.assertRaises(ValueError):
                merge.apply(path, {})
            self.assertEqual(path.read_text(), "not json")
            link = path.with_name("linked.json")
            link.symlink_to(path)
            with self.assertRaises(ValueError):
                merge.apply(link, {})
            self.assertTrue(link.is_symlink())


class TailnetTests(unittest.TestCase):
    def test_other_ports_are_preserved(self):
        self.assertTrue(tailnet.needs_setup(None))
        config = {"TCP": {"8443": {"HTTPS": True}}, "Web": {
            "host:8443": {"Handlers": {"/": {"Proxy": "http://127.0.0.1:8000"}}},
        }}
        before = json.dumps(config)
        self.assertTrue(tailnet.needs_setup(config))
        self.assertEqual(json.dumps(config), before)

    def test_existing_bb_route_is_idempotent_but_conflicts_are_refused(self):
        config = {"TCP": {"38886": {"HTTPS": True}}, "Web": {
            "host:38886": {"Handlers": {"/": {"Proxy": tailnet.TARGET}}},
        }}
        self.assertFalse(tailnet.needs_setup(config))
        config["Web"]["host:38886"]["Handlers"]["/"]["Proxy"] = "http://127.0.0.1:9999"
        with self.assertRaises(ValueError):
            tailnet.needs_setup(config)

    def test_public_funnel_is_refused(self):
        with self.assertRaises(ValueError):
            tailnet.needs_setup({"AllowFunnel": {"host:38886": True}})


if __name__ == "__main__":
    unittest.main()
