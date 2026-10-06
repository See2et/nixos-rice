"""Merge declarative notification settings without replacing Pi-owned settings."""

import json
import os
from pathlib import Path
import sys
import tempfile


def configure(path):
    if path.is_symlink():
        raise ValueError(f"Pi settings must be writable, not a symlink: {path}")
    settings = json.loads(path.read_text()) if path.exists() else {}
    notify = settings.setdefault("piNotify", {})
    tools = notify.get("notifyTools", [])
    if not isinstance(tools, list) or not all(isinstance(tool, str) for tool in tools):
        raise ValueError("piNotify.notifyTools must be a list of strings")
    notify.update(enabled=True, finished=True, onlyNotifyWhenUnfocused=False)
    notify["notifyTools"] = list(dict.fromkeys([*tools, "interview"]))
    content = json.dumps(settings, ensure_ascii=False, indent=2) + "\n"
    if path.exists() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".settings-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    configure(Path(sys.argv[1]))
