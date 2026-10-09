"""Merge the Nix-owned recap model into Pi's writable extension config."""

import json
import os
from pathlib import Path
import sys
import tempfile


def configure(path, model):
    if path.is_symlink():
        raise ValueError(f"Pi recap config must be writable, not a symlink: {path}")
    settings = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(settings, dict):
        raise ValueError("Pi recap config must be an object")
    settings["model"] = model
    content = json.dumps(settings, ensure_ascii=False, indent=2) + "\n"
    if path.exists() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".pi-recap-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    configure(Path(sys.argv[1]), sys.argv[2])
