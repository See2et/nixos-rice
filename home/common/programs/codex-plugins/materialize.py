"""Build a complete local marketplace with revision-specific cache versions."""

import json
import re
import shutil
import stat
import sys
from pathlib import Path


def materialize(source, destination, name, revision, selected):
    shutil.copytree(source, destination, symlinks=True)
    root = destination.resolve()
    for path in [root, *root.rglob("*")]:
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | stat.S_IWUSR)
    catalog_path = root / ".agents/plugins/marketplace.json"
    catalog_path.resolve().relative_to(root)
    catalog = json.loads(catalog_path.read_text())
    if catalog["name"] != name:
        raise ValueError(f"marketplace name must be {name}")
    entries = {entry["name"]: entry for entry in catalog["plugins"]}
    managed = []
    for plugin in selected:
        if not re.fullmatch(r"[A-Za-z0-9_-]+", plugin) or not re.fullmatch(r"[A-Za-z0-9_-]+", name):
            raise ValueError("unsafe plugin or marketplace name")
        entry = entries[plugin]
        src = entry["source"]
        if src.get("source") != "local":
            raise ValueError(f"{plugin}: Nix-managed plugins require local sources")
        relative = src["path"]
        if not relative.startswith("./"):
            raise ValueError(f"{plugin}: source path must start with ./")
        plugin_root = (root / relative).resolve()
        plugin_root.relative_to(root)
        manifests = [plugin_root / "plugin.json", plugin_root / ".codex-plugin/plugin.json"]
        found = False
        for path in manifests:
            if not path.is_file():
                continue
            path.resolve().relative_to(plugin_root)
            metadata = json.loads(path.read_text())
            if metadata["name"] != plugin:
                raise ValueError(f"{plugin}: manifest name mismatch")
            version = metadata.get("version", "0.0.0")
            metadata["version"] = version + ("." if "+" in version else "+") + f"nix.{revision}"
            path.write_text(json.dumps(metadata, indent=2) + "\n")
            found = True
        if not found:
            raise ValueError(f"{plugin}: missing plugin manifest")
        managed.append({"id": f"{plugin}@{name}", "source": relative})
    # Expose precisely the declared plugins while retaining all their resources.
    catalog["plugins"] = [entries[plugin] for plugin in selected]
    catalog_path.write_text(json.dumps(catalog, indent=2) + "\n")
    (root / "nix-managed-plugins.json").write_text(json.dumps(managed) + "\n")


if __name__ == "__main__":
    source, destination, name, revision, selection = sys.argv[1:]
    materialize(Path(source), Path(destination), name, revision, json.loads(Path(selection).read_text()))
