"""Merge declared JSON keys without replacing unrelated agent settings or auth."""

import argparse
import json
import os
from pathlib import Path
import tempfile


def merge(current, patch, append_lists=()):
    for key, value in patch.items():
        if key in append_lists:
            existing = current.get(key, [])
            if not all(isinstance(items, list) and all(isinstance(item, str) for item in items)
                       for items in (existing, value)):
                raise ValueError(f"Expected a list of strings at {key}; refusing to replace it")
            current[key] = list(dict.fromkeys([*existing, *value]))
        elif isinstance(value, dict):
            existing = current.get(key, {})
            if not isinstance(existing, dict):
                raise ValueError(f"Expected an object at {key}; refusing to replace it")
            current[key] = merge(existing, value)
        else:
            current[key] = value
    return current


def apply(path, patch, append_lists=()):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f"Refusing to replace symlink: {path}")
    original = path.read_bytes() if path.exists() else None
    current = json.loads(original) if original is not None else {}
    if not isinstance(current, dict):
        raise ValueError(f"Expected an object in {path}")
    updated = merge(current, patch, append_lists)
    if original is not None and updated == json.loads(original):
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if original is not None:
        # Preserve the pre-management file once; it can contain native auth state.
        backup = path.with_name(path.name + ".pre-nix-bb")
        if not backup.exists():
            with backup.open("xb") as stream:
                os.chmod(backup, 0o600)
                stream.write(original)
    fd, temporary = tempfile.mkstemp(prefix=".agent-config-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(updated, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("patch", type=Path)
    parser.add_argument("--append-list", action="append", default=[], metavar="KEY")
    args = parser.parse_args()
    apply(args.path, json.loads(args.patch.read_text()), args.append_list)
