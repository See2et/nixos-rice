"""Add only bb's Serve port; never replace another mapping or enable Funnel."""

import json
import subprocess
import sys

PORT = "38886"
TARGET = "http://127.0.0.1:38886"


def needs_setup(config):
    # tailscaled returns null when Serve has never been configured.
    if config is None:
        config = {}
    endpoints = {
        name: entry for name, entry in config.get("Web", {}).items()
        if name.rsplit(":", 1)[-1] == PORT
    }
    if any(enabled for name, enabled in config.get("AllowFunnel", {}).items()
           if name.rsplit(":", 1)[-1] == PORT):
        raise ValueError("bb's port has Funnel enabled; refusing public exposure")
    tcp = config.get("TCP", {}).get(PORT)
    if tcp is None and not endpoints:
        return True
    if tcp != {"HTTPS": True} or len(endpoints) != 1:
        raise ValueError("Serve port 38886 is already in use")
    entry = next(iter(endpoints.values()))
    if entry != {"Handlers": {"/": {"Proxy": TARGET}}}:
        raise ValueError("Serve port 38886 belongs to another mapping")
    return False


if __name__ == "__main__":
    tailscale = sys.argv[1]
    config = json.loads(subprocess.check_output([tailscale, "serve", "status", "--json"]))
    if needs_setup(config):
        subprocess.run([tailscale, "serve", "--bg", "--https=" + PORT, TARGET], check=True)
