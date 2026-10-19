"""Merge the declarative Pi miloa URL without managing local authentication."""

import json
import os
from pathlib import Path
import sys
import tempfile


def configure(path, url):
    if path.is_symlink():
        raise ValueError(f"Pi MCP config must be writable, not a symlink: {path}")
    settings = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(settings, dict):
        raise ValueError("Pi MCP config must be an object")
    servers = settings.setdefault("mcpServers", {})
    if not isinstance(servers, dict):
        raise ValueError("mcpServers must be an object")
    miloa = servers.setdefault("miloa", {})
    if not isinstance(miloa, dict):
        raise ValueError("mcpServers.miloa must be an object")
    miloa["url"] = url
    content = json.dumps(settings, ensure_ascii=False, indent=2) + "\n"
    if path.exists() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".mcp-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            output.write(content)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    configure(Path(sys.argv[1]), sys.argv[2])
