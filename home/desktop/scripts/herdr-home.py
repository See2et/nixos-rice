#!/usr/bin/env python3
"""Local window views of server-owned Herdr terminals; never kills pane processes."""

import argparse
import errno
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import sys
import termios
import time


HERDR = os.environ.get("HERDR_BIN", "herdr")
SELF = os.environ.get("HERDR_HOME_BIN", "herdr-home")


def cli(*args):
    result = subprocess.run([HERDR, *args], capture_output=True, text=True, timeout=15)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    data = json.loads(result.stdout)
    if data.get("ok") is False or data.get("error"):
        raise RuntimeError(str(data))
    return data["result"]


def runtime_dir():
    # Keep controllers for distinct Herdr namespaces separate, including test sessions.
    namespace = "|".join(os.environ.get(key, "") for key in (
        "HERDR_SOCKET_PATH", "HERDR_CONFIG_PATH", "HERDR_SESSION"))
    root = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    path = root / "herdr-home" / hashlib.sha256(namespace.encode()).hexdigest()[:12]
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)
    return path


def snapshot():
    return cli("api", "snapshot")["snapshot"]


def ensure_server():
    with (runtime_dir() / "startup.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            return snapshot()
        except RuntimeError:
            pass
        log_path = runtime_dir() / "startup.log"
        with log_path.open("a") as log:
            log_path.chmod(0o600)
            child = subprocess.Popen([HERDR, "server"], stdin=subprocess.DEVNULL,
                                     stdout=log, stderr=log, start_new_session=True)
        for _ in range(50):
            try:
                return snapshot()
            except RuntimeError:
                if child.poll() is not None:
                    break
                time.sleep(0.1)
        raise RuntimeError(f"Herdr server did not become ready; inspect {log_path}. No server was stopped.")


def pick(rows, prompt):
    if not rows:
        raise RuntimeError("No workspaces yet. Run: herdr-home project PATH [--label NAME]")
    # Labels are presentation only; select by an opaque ID, never interpolate into a shell.
    lines = [key + "\t" + re.sub(r"[\x00-\x1f\x7f]", " ", label) for key, label in rows]
    result = subprocess.run(["fzf", "--delimiter=\t", "--with-nth=2..", "--no-multi",
                             "--layout=reverse", "--prompt=" + prompt],
                            input="\n".join(lines), text=True, stdout=subprocess.PIPE)
    if result.returncode in (1, 130):
        return None
    if result.returncode:
        raise RuntimeError("Workspace picker failed")
    selected = result.stdout.rstrip("\n").split("\t", 1)[0]
    if selected not in {key for key, _ in rows}:
        raise RuntimeError("Picker returned an unknown ID")
    return selected


def workspace_choice(data):
    return pick([(w["workspace_id"], w["label"]) for w in data["workspaces"]], "Project > ")


def focused_terminal():
    if not os.environ.get("NIRI_SOCKET"):
        return None
    result = subprocess.run(["niri", "msg", "--json", "focused-window"],
                            capture_output=True, text=True)
    if result.returncode:
        return None
    window = json.loads(result.stdout)
    app_id = (window or {}).get("app_id") or ""
    return app_id.removeprefix("herdr-home.") if app_id.startswith("herdr-home.") else None


def endpoint(terminal):
    return runtime_dir() / (hashlib.sha256(terminal.encode()).hexdigest()[:24] + ".sock")


def request(path, command):
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(5)
        client.connect(str(path))
        client.sendall(command.encode())
        return client.recv(1024).decode()


def spawn_window(arguments):
    log_path = runtime_dir() / "windows.log"
    with log_path.open("a") as log:
        log_path.chmod(0o600)
        subprocess.Popen(["alacritty", *arguments], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=log, stderr=log)


def open_window(terminal):
    # Validate against live server state before starting an attach or focusing a view.
    if terminal not in {p["terminal_id"] for p in snapshot()["panes"]}:
        raise RuntimeError("Terminal no longer exists")
    try:
        request(endpoint(terminal), "ping")
    except (OSError, TimeoutError):
        pass
    else:
        windows = subprocess.run(["niri", "msg", "--json", "windows"],
                                 capture_output=True, text=True, check=True)
        for window in json.loads(windows.stdout):
            if window.get("app_id") == "herdr-home." + terminal:
                subprocess.run(["niri", "msg", "action", "focus-window", "--id",
                                str(window["id"])], check=True)
                return
        try:
            request(endpoint(terminal), "detach")
        except (ConnectionRefusedError, FileNotFoundError):
            pass
        for _ in range(50):
            if not endpoint(terminal).exists():
                break
            time.sleep(0.02)
        else:
            raise RuntimeError("Previous managed view has not finished detaching")
    spawn_window(["--class", "herdr-home." + terminal, "-e", SELF, "attach", terminal])


def attach(terminal):
    path = endpoint(terminal)
    # Lock is held for the controller lifetime; prevents racing duplicate views.
    with path.with_suffix(".lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("A managed view is already attached") from None
        path.unlink(missing_ok=True)
        with socket.socket(socket.AF_UNIX) as listener:
            listener.bind(str(path))
            path.chmod(0o600)
            listener.listen()
            listener.settimeout(0.2)
            saved_tty = termios.tcgetattr(sys.stdin.fileno()) if sys.stdin.isatty() else None
            child = subprocess.Popen([HERDR, "terminal", "attach", terminal])

            def detach_client(_signum, _frame):
                if child.poll() is None:
                    child.terminate()

            previous = {s: signal.signal(s, detach_client)
                        for s in (signal.SIGHUP, signal.SIGTERM)}
            try:
                while child.poll() is None:
                    try:
                        client, _ = listener.accept()
                    except socket.timeout:
                        continue
                    with client:
                        client.settimeout(2)
                        command = client.recv(64)
                        if command == b"detach":
                            detach_client(None, None)
                            child.wait(timeout=5)
                            client.sendall(b"detached")
                        elif command == b"ping":
                            client.sendall(b"attached")
                return child.returncode
            finally:
                detach_client(None, None)
                if child.poll() is None:
                    child.wait(timeout=5)
                for sig, handler in previous.items():
                    signal.signal(sig, handler)
                path.unlink(missing_ok=True)
                if saved_tty is not None:
                    try:
                        termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, saved_tty)
                    except termios.error as error:
                        if error.args[0] != errno.EIO:
                            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("project", help="create a project workspace (does not open a window)")
    create.add_argument("path", type=Path)
    create.add_argument("--label")
    new = commands.add_parser("new", help="new tab/window, inheriting the focused managed terminal")
    new.add_argument("--workspace")
    new.add_argument("--cwd", type=Path)
    new.add_argument("--label")
    commands.add_parser("launch", help="niri launcher: preserve focus before opening any picker window")
    restore = commands.add_parser("restore", help="open an existing terminal, or all terminals in a project")
    restore.add_argument("--workspace")
    restore.add_argument("--all", action="store_true")
    commands.add_parser("pick", help="fuzzy-select and focus a project in Herdr")
    commands.add_parser("list", help="print live workspace/tab/pane state as JSON")
    commands.add_parser("handoff", help="detach ONLY managed local views; keep every pane running")
    view = commands.add_parser("attach", help="internal: supervised direct attach")
    view.add_argument("terminal")
    args = parser.parse_args()
    if args.command == "attach":
        return attach(args.terminal)
    if args.command == "handoff":
        count = 0
        for path in runtime_dir().glob("*.sock"):
            try:
                if request(path, "detach") == "detached":
                    count += 1
            except (ConnectionRefusedError, FileNotFoundError):
                path.unlink(missing_ok=True)
        print(f"Detached {count} local view(s). All Herdr pane processes are untouched.")
        return 0
    data = ensure_server()
    if args.command == "list":
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return 0
    if args.command == "project":
        path = args.path.expanduser().resolve(strict=True)
        if not path.is_dir():
            raise RuntimeError("Project path must be a directory")
        print(json.dumps(cli("workspace", "create", "--cwd", str(path), "--label",
                             args.label or path.name), ensure_ascii=False))
        return 0
    if args.command == "pick":
        workspace = workspace_choice(data)
        if workspace:
            cli("workspace", "focus", workspace)
        return 0
    focused = focused_terminal()
    source = next((p for p in data["panes"] if p["terminal_id"] == focused), None)
    if args.command == "launch":
        if source is None:
            spawn_window(["--class", "herdr-home-picker", "-e", SELF, "new"])
            return 0
        args.command = "new"
        args.workspace = source["workspace_id"]
        args.cwd = None
        args.label = None
    workspace = args.workspace or (source["workspace_id"] if source else None)
    workspace = workspace or workspace_choice(data)
    if workspace is None:
        return 0
    if workspace not in {w["workspace_id"] for w in data["workspaces"]}:
        raise RuntimeError("Unknown workspace")
    panes = [p for p in data["panes"] if p["workspace_id"] == workspace]
    if args.command == "new":
        origin = source if source and source["workspace_id"] == workspace else next(iter(panes), {})
        cwd = args.cwd or origin.get("foreground_cwd") or origin.get("cwd")
        if not cwd:
            raise RuntimeError("No project CWD available; pass --cwd")
        cwd = Path(cwd).expanduser().resolve(strict=True)
        if not cwd.is_dir():
            raise RuntimeError("CWD must be a directory")
        command = ["tab", "create", "--workspace", workspace, "--cwd", str(cwd), "--no-focus"]
        if args.label:
            command += ["--label", args.label]
        pane = cli(*command)["root_pane"]
        open_window(pane["terminal_id"])
    else:
        tabs = {t["tab_id"]: t["label"] for t in data["tabs"]}
        if args.all:
            for pane in panes:
                open_window(pane["terminal_id"])
        else:
            terminal = pick([(p["terminal_id"], f'{tabs[p["tab_id"]]} / {p.get("label") or p["pane_id"]} / {p.get("foreground_cwd") or p.get("cwd", "")}')
                             for p in panes], "Terminal > ")
            if terminal:
                open_window(terminal)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, OSError, subprocess.SubprocessError, ValueError) as error:
        print(f"herdr-home: {error}", file=sys.stderr)
        sys.exit(1)
