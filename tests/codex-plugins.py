"""Exercise automatic plugin lifecycle with the real pinned Codex CLI, offline."""

import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
ACTIVATE = REPO / "home/common/programs/codex-plugins/activate.py"
spec = importlib.util.spec_from_file_location(
    "materialize", REPO / "home/common/programs/codex-plugins/materialize.py"
)
materializer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(materializer)


def fixture(root, name):
    (root / ".agents/plugins").mkdir(parents=True)
    plugin = root / "plugins/probe"
    (plugin / ".codex-plugin").mkdir(parents=True)
    (plugin / "skills/hello").mkdir(parents=True)
    (plugin / "references").mkdir()
    (plugin / "skills/hello/SKILL.md").write_text(
        "---\nname: hello\ndescription: isolated integration fixture\n---\nfirst\n"
    )
    (plugin / "references/example.md").write_text("retained reference\n")
    (plugin / ".codex-plugin/plugin.json").write_text(json.dumps({
        "name": "probe", "version": "1.0.0", "skills": "./skills/",
        "interface": {"displayName": "Probe", "shortDescription": "Local test plugin",
                      "longDescription": "Local integration test plugin", "developerName": "Local",
                      "category": "Productivity", "capabilities": ["Read"], "defaultPrompt": ["test"]}
    }))
    (root / ".agents/plugins/marketplace.json").write_text(json.dumps({
        "name": name, "plugins": [{"name": "probe", "source": {
            "source": "local", "path": "./plugins/probe"
        }, "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"},
            "category": "Productivity"}]
    }))


with tempfile.TemporaryDirectory(prefix="codex-nix-plugins-") as temporary:
    root = Path(temporary)
    home = root / "home"
    home.mkdir()
    codehome = home / ".codex"
    codehome.mkdir()
    calls = root / "calls.jsonl"
    wrapper = root / "codex"
    wrapper.write_text(f"#!{sys.executable}\n" + """
import json, os, sys
with open(os.environ['CALLS_FILE'], 'a') as output:
    output.write(json.dumps(sys.argv[1:]) + '\\n')
if os.environ.get('FAIL_PLUGIN_ADD') == '1' and sys.argv[1:3] == ['plugin', 'add']:
    print('injected install failure', file=sys.stderr)
    sys.exit(1)
if (sys.argv[1:4] == ['plugin', 'marketplace', 'add']
        and sys.argv[4] == os.environ.get('FAIL_MARKET_ADD_SOURCE')):
    print('injected marketplace failure', file=sys.stderr)
    sys.exit(1)
os.execv(os.environ['CODEX_BIN'], [os.environ['CODEX_BIN'], *sys.argv[1:]])
""")
    wrapper.chmod(0o755)
    env = os.environ | {"HOME": str(home), "CODEX_HOME": str(codehome), "CALLS_FILE": str(calls)}
    config = codehome / "config.toml"
    config.write_text('model = "preserve-model"\n[plugins."manual@unrelated"]\nenabled = false\n')
    auth = codehome / "auth.json"
    auth.write_text('{"sentinel":"preserve-auth"}\n')
    manual_cache = codehome / "plugins/cache/unrelated/manual/1.0.0"
    manual_cache.mkdir(parents=True)
    (manual_cache / "keep.txt").write_text("preserve-cache")
    source = root / "checkout"
    fixture(source, "managed")

    def cli(*args):
        result = subprocess.run([str(wrapper), "plugin", *args, "--json"], env=env,
                                capture_output=True, text=True, timeout=60)
        assert result.returncode == 0, result.stderr
        return json.loads(result.stdout)

    def apply(markets, fail=False, fail_source=None):
        manifest = root / "desired.json"
        manifest.write_text(json.dumps(markets))
        result = subprocess.run([sys.executable, str(ACTIVATE), "--manifest", str(manifest),
                                 "--codex-home", str(codehome), "--codex", str(wrapper)],
                                env=env | {"FAIL_PLUGIN_ADD": "1" if fail else "0",
                                           "FAIL_MARKET_ADD_SOURCE": str(fail_source or "")},
                                capture_output=True, text=True, timeout=120)
        assert (result.returncode != 0) if (fail or fail_source) else (result.returncode == 0), result.stderr
        return result

    def state():
        return json.loads((codehome / "nix-managed-plugins.json").read_text())

    def preserved():
        settings = tomllib.loads(config.read_text())
        assert settings["model"] == "preserve-model"
        assert settings["plugins"]["manual@unrelated"]["enabled"] is False
        assert auth.read_text() == '{"sentinel":"preserve-auth"}\n'
        assert (manual_cache / "keep.txt").read_text() == "preserve-cache"

    # Migrate an existing editable marketplace without changing its checkout.
    cli("marketplace", "add", str(source))
    original = Path(cli("add", "probe@managed")["installedPath"])
    first = root / "first"
    materializer.materialize(source, first, "managed", "a" * 40, ["probe"])
    apply([{"name": "managed", "root": str(first)}])
    first_cache = Path(state()["plugins"]["probe@managed"]["path"])
    assert first_cache != original
    assert json.loads((source / "plugins/probe/.codex-plugin/plugin.json").read_text())["version"] == "1.0.0"
    assert (first_cache / "references/example.md").read_text() == "retained reference\n"
    before = calls.read_text()
    apply([{"name": "managed", "root": str(first)}])
    assert calls.read_text() == before, "unchanged activation must not recopy live caches"
    preserved()

    # Updating the same release is identified by revision; failures retry on activation.
    (source / "plugins/probe/skills/hello/SKILL.md").write_text(
        "---\nname: hello\ndescription: isolated integration fixture\n---\nsecond\n"
    )
    second = root / "second"
    materializer.materialize(source, second, "managed", "b" * 40, ["probe"])
    apply([{"name": "managed", "root": str(second)}], fail_source=second)
    assert tomllib.loads(config.read_text())["marketplaces"]["managed"]["source"] == str(first)
    assert Path(state()["plugins"]["probe@managed"]["path"]) == first_cache
    apply([{"name": "managed", "root": str(second)}], fail=True)
    assert Path(state()["plugins"]["probe@managed"]["path"]) == first_cache
    assert (first_cache / "skills/hello/SKILL.md").read_text().endswith("first\n")
    apply([{"name": "managed", "root": str(second)}])
    second_cache = Path(state()["plugins"]["probe@managed"]["path"])
    assert second_cache != first_cache
    assert (second_cache / "skills/hello/SKILL.md").read_text().endswith("second\n")
    preserved()
    # Rollback follows the older source; missing caches are repaired on reapply.
    apply([{"name": "managed", "root": str(first)}])
    assert Path(state()["plugins"]["probe@managed"]["path"]) == first_cache
    shutil.rmtree(first_cache)
    apply([{"name": "managed", "root": str(first)}])
    assert (first_cache / "skills/hello/SKILL.md").exists()
    # A deleted declaration removes only IDs previously claimed by this manager.
    apply([])
    assert "probe@managed" not in tomllib.loads(config.read_text()).get("plugins", {})
    preserved()

    # Finally install the actual Nix-built Astraeus source, resources included.
    astraeus = os.environ.get("ASTRAEUS_MARKETPLACE")
    if astraeus:
        apply([{"name": "astraeus", "root": astraeus}])
        installed = Path(state()["plugins"]["astraeus@astraeus"]["path"])
        for relative in ["skills/orchestrate/SKILL.md", "references/policy.md",
                         "schemas/review.json", "scripts/astraeus.py"]:
            assert (installed / relative).is_file(), relative
        preserved()
print("Codex plugin lifecycle: migration, idempotency, update/retry, rollback, repair, removal, preservation passed")
