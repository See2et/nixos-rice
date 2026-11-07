#!/usr/bin/env python3
"""Load the built wrapper's extensions without inference or user configuration."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def check(binary):
    binary = str(Path(binary).resolve(strict=True))
    with tempfile.TemporaryDirectory(prefix="pi-load-") as temporary:
        base = Path(temporary)
        agent = base / "agent"
        workspace = base / "workspace"
        agent.mkdir()
        workspace.mkdir()
        (agent / "settings.json").write_text('{"retry":{"enabled":false}}\n')
        result = subprocess.run(
            [binary, "--mode", "rpc", "--offline", "--no-context-files", "--no-session"],
            input='{"id":"load-check","type":"get_commands"}\n',
            cwd=workspace,
            env={"HOME": str(base), "PATH": "/nonexistent", "PI_CODING_AGENT_DIR": str(agent), "PI_OFFLINE": "1"},
            capture_output=True, text=True, timeout=60,
        )
        if result.returncode or result.stderr.strip():
            raise RuntimeError(f"Pi extension load failed ({result.returncode}): {result.stderr}\n{result.stdout[-4000:]}")
        records = [json.loads(line) for line in result.stdout.split("\n") if line.strip()]
        if any(record.get("type") == "extension_error" for record in records):
            raise RuntimeError(f"Pi extension error: {result.stdout[-4000:]}")
        if not any(record.get("id") == "load-check" and record.get("success") is True for record in records):
            raise RuntimeError(f"Pi did not complete extension startup: {result.stdout[-4000:]}")
        print("Pi extension startup/load: passed (isolated configuration, no inference)")


if __name__ == "__main__":
    check(sys.argv[1])
