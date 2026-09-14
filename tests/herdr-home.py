#!/usr/bin/env python3
"""Exercise the real Herdr server in an isolated namespace, never the user's session."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import pty
import select
import shutil
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import termios
import time


ROOT = Path(__file__).resolve().parent.parent
HELPER = ROOT / "home/desktop/scripts/herdr-home.py"
HERDR = os.environ.get("HERDR_BIN", "herdr")


def run(args, env, ok=True):
    result = subprocess.run(args, env=env, text=True, capture_output=True, timeout=20)
    if ok:
        assert result.returncode == 0, (args, result.stdout, result.stderr)
    else:
        assert result.returncode != 0, args
    return result.stdout


def main():
    with tempfile.TemporaryDirectory(prefix="herdr-qa-") as folder:
        root = Path(folder)
        (root / "tmp").mkdir()
        (root / "zsh").mkdir()
        env = {k: v for k, v in os.environ.items() if not k.startswith("HERDR_")}
        env.update(HERDR_BIN=HERDR, HERDR_CONFIG_PATH=str(root / "config.toml"),
                   HERDR_SOCKET_PATH=str(root / "api.sock"), XDG_RUNTIME_DIR=folder,
                   XDG_CONFIG_HOME=str(root / "config"), XDG_STATE_HOME=str(root / "state"),
                   XDG_DATA_HOME=str(root / "data"), XDG_CACHE_HOME=str(root / "cache"),
                   TMPDIR=str(root / "tmp"), ZDOTDIR=str(root / "zsh"),
                   HOME=folder, TERM="xterm-256color", SHELL=shutil.which("bash") or "/bin/sh",
                   NIRI_SOCKET="", FZF_DEFAULT_OPTS="--filter=prja")
        (root / "config.toml").write_text(
            'onboarding = false\n[update]\nversion_check = false\nmanifest_check = false\n'
            '[ui.sound]\nenabled = false\n[terminal]\ndefault_shell = '
            + json.dumps(env["SHELL"]) + '\n')
        shim_dir = root / "bin"
        shim_dir.mkdir()
        alacritty = shim_dir / "alacritty"
        alacritty.write_text(f'#!{sys.executable}\nimport json,sys\nfrom pathlib import Path\n'
                             f'Path({str(root / "window.json")!r}).write_text(json.dumps(sys.argv[1:]))\n')
        alacritty.chmod(0o700)
        env["PATH"] = str(shim_dir) + os.pathsep + env["PATH"]
        helper = [sys.executable, str(HELPER)]
        def api(*args):
            result = json.loads(run([HERDR, *args], env))["result"]
            return result["snapshot"] if args == ("api", "snapshot") else result
        child_pid = None
        try:
            run(helper + ["--help"], env)
            run(helper + ["unknown"], env, ok=False)
            created = json.loads(run(helper + ["project", folder, "--label", "project-alpha"], env))
            workspace = created["workspace"]["workspace_id"]
            pane = created["root_pane"]
            terminal = pane["terminal_id"]
            assert api("api", "snapshot")["workspaces"][0]["label"] == "project-alpha"
            run(helper + ["new", "--workspace", workspace, "--cwd", folder], env)
            state = api("api", "snapshot")
            assert len(state["tabs"]) == 2, state
            assert all(p["cwd"] == folder for p in state["panes"])
            run(helper + ["new", "--workspace", "missing"], env, ok=False)
            run(helper + ["pick"], env)
            assert api("api", "snapshot")["focused_workspace_id"] == workspace
            assert len(api("api", "snapshot")["tabs"]) == 2

            master, slave = pty.openpty()
            fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
            child_pid = os.fork()
            if child_pid == 0:
                os.close(master)
                os.setsid()
                fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
                for fd in (0, 1, 2):
                    os.dup2(slave, fd)
                os.execvpe(sys.executable, helper + ["attach", terminal], env)
            os.close(slave)
            key = "|".join((env["HERDR_SOCKET_PATH"], env["HERDR_CONFIG_PATH"], ""))
            control_dir = root / "herdr-home" / hashlib.sha256(key.encode()).hexdigest()[:12]
            control = control_dir / (hashlib.sha256(terminal.encode()).hexdigest()[:24] + ".sock")
            output = bytearray()
            for _ in range(100):
                if select.select([master], [], [], 0.05)[0]:
                    output.extend(os.read(master, 65536))
                if control.exists() and b"\x1b" in output:
                    break
            assert control.exists(), output.decode(errors="replace")
            run([HERDR, "pane", "run", pane["pane_id"], "printf HERDR_QA_RUNNING; sleep 90"], env)
            run([HERDR, "pane", "wait-output", pane["pane_id"], "--match", "HERDR_QA_RUNNING", "--timeout", "5000"], env)
            before = api("pane", "get", pane["pane_id"])
            handoff = run(helper + ["handoff"], env)
            assert "Detached 1" in handoff, handoff
            for _ in range(50):
                waited, _ = os.waitpid(child_pid, os.WNOHANG)
                if waited:
                    child_pid = None
                    break
                time.sleep(0.1)
            assert child_pid is None, "controller did not exit"
            assert not control.exists()
            after = api("pane", "get", pane["pane_id"])
            assert before["pane"]["terminal_id"] == after["pane"]["terminal_id"]
            processes = api("pane", "process-info", "--pane", pane["pane_id"])
            assert "sleep" in json.dumps(processes), processes
            run(helper + ["handoff"], env)
            run(helper + ["restore", "--workspace", workspace, "--all"], env)
            assert len(api("api", "snapshot")["tabs"]) == 2
            os.close(master)
            master, slave = pty.openpty()
            child_pid = os.fork()
            if child_pid == 0:
                os.close(master)
                os.setsid()
                fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
                for fd in (0, 1, 2):
                    os.dup2(slave, fd)
                os.execvpe(sys.executable, helper + ["attach", terminal], env)
            os.close(slave)
            for _ in range(100):
                if select.select([master], [], [], 0.05)[0]:
                    if os.read(master, 65536) and control.exists():
                        break
            assert control.exists()
            os.close(master)
            for _ in range(50):
                waited, _ = os.waitpid(child_pid, os.WNOHANG)
                if waited:
                    child_pid = None
                    break
                time.sleep(0.1)
            assert child_pid is None, "controller survived outer PTY close"
            assert not control.exists(), "closed PTY left a stale controller socket"
            assert "sleep" in json.dumps(api("pane", "process-info", "--pane", pane["pane_id"]))
            print("herdr-home: real server create/new/fuzzy-pick/direct-attach/handoff/restore passed")
            print("herdr-home: ANSI output observed; sleep survived handoff and outer PTY close")
        finally:
            if child_pid is not None:
                os.kill(child_pid, signal.SIGTERM)
                os.waitpid(child_pid, 0)
            subprocess.run([HERDR, "server", "stop"], env=env, capture_output=True, timeout=10)


if __name__ == "__main__":
    main()
