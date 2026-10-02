"""Reconcile only declared Codex plugins through the native plugin commands."""

import argparse
import fcntl
import hashlib
import json
import os
import subprocess
import tempfile
import tomllib
from pathlib import Path


def payload_hash(root):
    if not root.is_dir():
        return None
    digest = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        relative = str(path.relative_to(root)).encode()
        if path.is_symlink():
            value = b"link:" + os.readlink(path).encode()
        elif path.is_file():
            value = b"file:" + (path.stat().st_mode & 0o111).to_bytes(2, "big") + path.read_bytes()
        else:
            value = b"directory:"
        digest.update(len(relative).to_bytes(8, "big") + relative)
        digest.update(hashlib.sha256(value).digest())
    return digest.hexdigest()


def reconcile(manifest, home, codex):
    home.mkdir(parents=True, exist_ok=True)
    state_path = home / "nix-managed-plugins.json"
    config_path = home / "config.toml"
    env = os.environ | {"CODEX_HOME": str(home)}

    def configuration():
        return tomllib.loads(config_path.read_text()) if config_path.exists() else {}

    def command(*args):
        result = subprocess.run([codex, "plugin", *args, "--json"], env=env,
                                capture_output=True, text=True, timeout=60)
        if result.returncode:
            raise RuntimeError(f"codex plugin {' '.join(args)} failed: {result.stderr.strip()}")
        return json.loads(result.stdout)

    def save():
        with tempfile.NamedTemporaryFile(mode="w", dir=home, delete=False) as output:
            json.dump(state, output)
            temporary = output.name
        os.replace(temporary, state_path)

    # Avoid interleaved reconcilers if Home Manager is applied concurrently.
    with (home / "nix-managed-plugins.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = json.loads(state_path.read_text()) if state_path.exists() else {
            "schema_version": 1, "plugins": {}, "marketplaces": {}
        }
        if state.get("schema_version") != 1:
            raise ValueError("unsupported Codex Nix plugin state schema")
        desired = set()
        desired_markets = set()
        for market in manifest:
            name, root = market["name"], Path(market["root"])
            selected = json.loads((root / "nix-managed-plugins.json").read_text())
            desired_markets.add(name)
            existing = configuration().get("marketplaces", {}).get(name)
            if existing != {"source_type": "local", "source": str(root)}:
                if existing:
                    command("marketplace", "remove", name)
                try:
                    command("marketplace", "add", str(root))
                except Exception:
                    # Restoring the old catalog leaves installed caches intact.
                    if existing:
                        restore = ["marketplace", "add", existing["source"]]
                        if existing.get("ref"):
                            restore += ["--ref", existing["ref"]]
                        command(*restore)
                    raise
            state["marketplaces"][name] = str(root)
            save()
            for plugin in selected:
                identifier = plugin["id"]
                desired.add(identifier)
                expected = payload_hash(root / plugin["source"])
                previous = state["plugins"].get(identifier, {})
                enabled = configuration().get("plugins", {}).get(identifier, {}).get("enabled", False)
                if (previous.get("payload") == expected and enabled
                        and payload_hash(Path(previous.get("path", ""))) == expected):
                    continue
                result = command("add", identifier)
                installed = Path(result["installedPath"])
                if payload_hash(installed) != expected:
                    raise RuntimeError(f"installed payload mismatch: {identifier}")
                state["plugins"][identifier] = {"payload": expected, "path": str(installed)}
                save()
                print(f"Codex plugin installed: {identifier}")
        # Only previously managed IDs are eligible for removal; manual plugins stay.
        for identifier in sorted(set(state["plugins"]) - desired):
            command("remove", identifier)
            del state["plugins"][identifier]
            save()
            print(f"Codex plugin removed: {identifier}")
        for name in sorted(set(state["marketplaces"]) - desired_markets):
            current = configuration()
            has_plugins = any(key.endswith(f"@{name}") for key in current.get("plugins", {}))
            source = current.get("marketplaces", {}).get(name, {}).get("source")
            if not has_plugins and source == state["marketplaces"][name]:
                command("marketplace", "remove", name)
            del state["marketplaces"][name]
            save()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--codex-home", type=Path, required=True)
    parser.add_argument("--codex", default="codex")
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error("Codex plugin activation must run as the Home Manager user, not root")
    reconcile(json.loads(args.manifest.read_text()), args.codex_home, args.codex)
