"""Configure the declared plugins and provider settings via bb CLI."""

import json
import os
from pathlib import Path
import subprocess
import sys
import time


def cli(*args):
    label = "bb " + " ".join(args[:2])
    try:
        result = subprocess.run(
            [os.environ["BB_BIN"], *args, "--json"],
            text=True, capture_output=True, timeout=60,
        )
    except subprocess.TimeoutExpired:
        raise RuntimeError(label + " timed out") from None
    if result.returncode:
        # Do not log command arguments: preserved custom agents can contain env secrets.
        raise RuntimeError(f"{label} failed (exit {result.returncode})")
    value = json.loads(result.stdout)
    if isinstance(value, dict) and value.get("ok") is False:
        raise RuntimeError(value.get("error", "bb command failed"))
    return value


def configure(manifest):
    deadline = time.monotonic() + 90
    while True:
        try:
            plugins = {p["id"]: p for p in cli("plugin", "list")["plugins"]}
            break
        except (subprocess.SubprocessError, ValueError, RuntimeError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(1)

    for plugin in manifest["plugins"]:
        existing = plugins.get(plugin["id"])
        if existing is not None and existing.get("source") != plugin["source"]:
            raise ValueError(
                f"plugin {plugin['id']} source conflicts: "
                f"expected {plugin['source']!r}, found {existing.get('source')!r}"
            )

    for plugin in manifest["plugins"]:
        existing = plugins.get(plugin["id"])
        if existing is None:
            cli("plugin", "install", plugin["source"], "--yes")
        elif not existing["enabled"]:
            cli("plugin", "enable", plugin["id"])

    claude = cli("plugin", "config", "provider-claude-code")["values"]
    if claude.get("fullAccessApprovalsEnabled") is not True:
        cli("plugin", "config", "provider-claude-code", "set", "fullAccessApprovalsEnabled", "true")

    settings = cli("plugin", "config", "provider-acp")["values"]
    agents = json.loads(settings.get("customAgents") or "[]")
    if not isinstance(agents, list):
        raise ValueError("provider-acp.customAgents must be an array")
    desired = manifest["agy"]
    updated = [a for a in agents if a.get("id") != desired["id"]] + [desired]
    if agents != updated:
        cli("plugin", "config", "provider-acp", "set", "customAgents", json.dumps(updated))
    cli("settings", "general", "defaultProviderId", "codex")
    cli("settings", "general", "providerOrder", json.dumps(["codex", "claude-code", "acp-agy"]))


if __name__ == "__main__":
    configure(json.loads(Path(sys.argv[1]).read_text()))
