#!/usr/bin/env python3
"""Safety boundaries for shared agent configuration and bb's private route."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


merge = load("agent_config", "home/common/programs/merge-agent-config.py")
tailnet = load("bb_tailnet", "modules/nixos/desktop/scripts/bb-tailnet.py")
bb = load("configure_bb", "home/desktop/scripts/configure-bb.py")


class PluginTests(unittest.TestCase):
    source = "path:/home/test/ghq/github.com/see2et/miloa-management"
    manifest = {"plugins": [
        {"id": "tasks", "source": "builtin:tasks"},
        {"id": "miloa-management", "source": source},
    ], "agy": {"id": "agy", "command": "/nix/store/agy/bin/agy"}}

    def test_local_and_builtin_registration_preserves_other_state_and_is_idempotent(self):
        plugins = {"other": {"id": "other", "source": "path:/other", "enabled": False}}
        other_agent = {"id": "private", "command": "keep", "env": {"TOKEN": "private"}}
        settings = {"customAgents": json.dumps([other_agent]), "otherSetting": "keep"}
        writes = []

        def cli(*args):
            if args == ("plugin", "list"):
                return {"plugins": list(plugins.values())}
            if args == ("plugin", "config", "provider-acp"):
                return {"values": dict(settings)}
            writes.append(args)
            if args[:2] == ("plugin", "install"):
                plugin_id = "tasks" if args[2].endswith("tasks") else "miloa-management"
                plugins[plugin_id] = {"id": plugin_id, "source": args[2], "enabled": True}
            elif args[:2] == ("plugin", "enable"):
                plugins[args[2]]["enabled"] = True
            elif args[:4] == ("plugin", "config", "provider-acp", "set"):
                settings[args[4]] = args[5]
            return {}

        with patch.object(bb, "cli", side_effect=cli):
            bb.configure(self.manifest)
            self.assertEqual(plugins["tasks"]["source"], "builtin:tasks")
            self.assertEqual(plugins["miloa-management"]["source"], self.source)
            self.assertEqual(plugins["other"], {
                "id": "other", "source": "path:/other", "enabled": False,
            })
            self.assertEqual(json.loads(settings["customAgents"]), [other_agent, self.manifest["agy"]])
            self.assertEqual(settings["otherSetting"], "keep")
            writes.clear()
            bb.configure(self.manifest)
            self.assertFalse(any(args[0] == "plugin" for args in writes))
            plugins["miloa-management"]["enabled"] = False
            writes.clear()
            bb.configure(self.manifest)
            self.assertEqual([args for args in writes if args[0] == "plugin"], [
                ("plugin", "enable", "miloa-management"),
            ])

    def test_conflicting_local_source_is_refused_before_any_write(self):
        existing = {"id": "miloa-management", "source": "path:/other-checkout", "enabled": False}

        def read_only(*args):
            if args == ("plugin", "list"):
                return {"plugins": [existing]}
            self.fail("conflicting plugin source caused a write")

        with patch.object(bb, "cli", side_effect=read_only) as cli:
            with self.assertRaisesRegex(ValueError, "miloa-management.*source"):
                bb.configure(self.manifest)
            self.assertEqual(cli.call_args_list, [unittest.mock.call("plugin", "list")])

    def test_unknown_install_failure_is_not_retried(self):
        with patch.object(bb, "cli", side_effect=[{"plugins": []}, RuntimeError("unknown write")]) as cli:
            with self.assertRaisesRegex(RuntimeError, "unknown write"):
                bb.configure(self.manifest)
            self.assertEqual(cli.call_count, 2)


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

    def test_workspace_trust_merges_with_existing_approvals(self):
        with tempfile.TemporaryDirectory() as directory:
            settings = Path(directory) / "settings.json"
            settings.write_text(json.dumps({"trustedWorkspaces": ["/other", "/known"], "theme": "dark"}))
            patch = {"trustedWorkspaces": ["/known", "/declared"]}
            merge.apply(settings, patch, append_lists=["trustedWorkspaces"])
            first = settings.read_bytes()
            self.assertEqual(json.loads(first), {
                "trustedWorkspaces": ["/other", "/known", "/declared"],
                "theme": "dark",
            })
            merge.apply(settings, patch, append_lists=["trustedWorkspaces"])
            self.assertEqual(settings.read_bytes(), first)

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
