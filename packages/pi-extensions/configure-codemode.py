"""Enable Pi CodeMode while preserving the user's other tool/settings choices."""

import json
import os
from pathlib import Path
import sys
import tempfile


def configure(path):
    if path.is_symlink():
        raise ValueError(f"Pi settings must be writable, not a symlink: {path}")
    settings = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(settings, dict):
        raise ValueError("Pi settings must be an object")
    tools = settings.get("defaultTools")
    if tools is None and "defaultTools" not in settings:
        tools = ["+codemode"]
    else:
        if not isinstance(tools, list) or not all(isinstance(tool, str) for tool in tools):
            raise ValueError("defaultTools must be a list of strings")
        # Empty/explicit lists replace defaults; modifier-only lists inherit them.
        inherit = bool(tools) and all(tool.startswith(("+", "-")) for tool in tools)
        tools = [tool for tool in tools if tool not in ("codemode", "+codemode", "-codemode")]
        tools.append("+codemode" if inherit else "codemode")
    settings["defaultTools"] = tools
    codemode = settings.setdefault("codemode", {})
    if not isinstance(codemode, dict):
        raise ValueError("codemode must be an object")
    codemode.setdefault("mode", "on")
    if "extensions" in settings:
        extensions = settings["extensions"]
        if not isinstance(extensions, list) or not all(isinstance(extension, str) for extension in extensions):
            raise ValueError("extensions must be a list of strings")
        settings["extensions"] = [extension for extension in extensions if extension != "-builtin:codemode"]
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
