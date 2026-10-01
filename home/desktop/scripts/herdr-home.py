#!/usr/bin/env python3
"""Local views of Herdr terminals; only explicit project removal stops their processes."""

import argparse
from contextlib import contextmanager
import errno
import glob
import fcntl
from functools import lru_cache
import hashlib
import json
import os
from pathlib import Path
import re
import readline
import signal
import socket
import subprocess
import sys
import tempfile
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


def namespace_id():
    namespace = "|".join(os.environ.get(key, "") for key in (
        "HERDR_SOCKET_PATH", "HERDR_CONFIG_PATH", "HERDR_SESSION"))
    return hashlib.sha256(namespace.encode()).hexdigest()[:12]


def runtime_dir():
    root = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    path = root / "herdr-home" / namespace_id()
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)
    return path


def directory(value):
    path = Path(value).expanduser().resolve(strict=True)
    if not path.is_dir():
        raise ValueError(f"Not a directory: {path}")
    return str(path)


@lru_cache(maxsize=1)
def server_status():
    result = subprocess.run([HERDR, "status", "--json"], capture_output=True,
                            text=True, check=True, timeout=15)
    return json.loads(result.stdout)["server"]


def state_namespace():
    config_root = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
    config = Path(os.environ.get("HERDR_CONFIG_PATH", str(config_root / "herdr/config.toml")))
    identity = [os.path.abspath(server_status()["socket"]), os.path.abspath(config.expanduser())]
    return hashlib.sha256(json.dumps(identity).encode()).hexdigest()[:12]


@contextmanager
def directory_state(write=False):
    root = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    root = root / "herdr-home" / state_namespace()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = root / "directories.json"
    with (root / "directories.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX if write else fcntl.LOCK_SH)
        try:
            state = json.loads(path.read_text())
            if (state.get("version") != 1 or not isinstance(state.get("defaults"), dict)
                    or any(not isinstance(state.get(k), list)
                           or any(not isinstance(p, str) for p in state[k])
                           for k in ("favorites", "recent"))
                    or any(not isinstance(k, str) or not isinstance(v, str)
                           for k, v in state["defaults"].items())):
                raise ValueError("invalid schema")
        except FileNotFoundError:
            state = {"version": 1, "defaults": {}, "favorites": [], "recent": []}
        except (ValueError, AttributeError) as error:
            raise RuntimeError(f"Invalid directory state {path}; preserved for repair: {error}") from error
        yield state
        if write:
            temporary = None
            try:
                with tempfile.NamedTemporaryFile(mode="w", dir=root, delete=False) as out:
                    temporary = Path(out.name)
                    json.dump(state, out, ensure_ascii=False, indent=2)
                    out.flush()
                    os.fsync(out.fileno())
                os.replace(temporary, path)
            finally:
                if temporary:
                    temporary.unlink(missing_ok=True)


def workspace_key(workspace):
    # w1/w2 IDs are recycled after restart. Bind defaults to this socket incarnation.
    stat = Path(server_status()["socket"]).stat()
    return f"{stat.st_dev}:{stat.st_ino}:{stat.st_ctime_ns}:{workspace}"


def remember(state, path):
    state["recent"] = [path] + [p for p in state["recent"] if p != path][:19]


def save_directory(workspace, path):
    key = workspace_key(workspace)
    with directory_state(write=True) as state:
        incarnation = key.rsplit(":", 1)[0] + ":"
        state["defaults"] = {k: v for k, v in state["defaults"].items()
                             if k.startswith(incarnation)}
        state["defaults"][key] = path
        remember(state, path)


def create_project(path, label):
    # Check state before creating anything; malformed state must never be overwritten.
    with directory_state():
        pass
    created = cli("workspace", "create", "--cwd", path, "--label", label)
    save_directory(created["workspace"]["workspace_id"], path)
    return created


def directory_choice():
    paths = {}
    def add(path, source):
        try:
            path = directory(path)
        except (OSError, ValueError):
            return
        paths.setdefault(path, []).append(source)
    add(Path.cwd(), "current")
    with directory_state() as state:
        for kind in ("favorites", "recent"):
            for path in state[kind]:
                add(path, kind)
    try:
        result = subprocess.run(["ghq", "list", "-p"], capture_output=True,
                                text=True, timeout=10)
        if result.returncode:
            print("ghq lookup failed; other directories are still available.", file=sys.stderr)
        else:
            for path in result.stdout.splitlines():
                add(path, "ghq")
    except FileNotFoundError:
        pass
    except subprocess.TimeoutExpired:
        print("ghq lookup timed out; other directories are still available.", file=sys.stderr)
    choices = list(paths)
    selected = pick([(str(i), f"{path} ({', '.join(paths[path])})")
                     for i, path in enumerate(choices)]
                    + [("manual", "Enter a path... (Tab completion)")], "Directory > ")
    if selected is None:
        return None
    if selected != "manual":
        return directory(choices[int(selected)])
    def complete(text, index):
        matches = sorted(p + "/" for p in glob.glob(os.path.expanduser(text) + "*")
                         if os.path.isdir(p))
        return matches[index] if index < len(matches) else None
    previous = readline.get_completer()
    delimiters = readline.get_completer_delims()
    try:
        readline.set_completer(complete)
        readline.set_completer_delims("")
        readline.parse_and_bind("tab: complete")
        value = prompt_input("Directory (blank to cancel): ")
    finally:
        readline.set_completer(previous)
        readline.set_completer_delims(delimiters)
    return directory(value) if value else None


def context_workspace(data):
    # The invoking shell is stronger evidence than whichever window has UI focus.
    pane_id = os.environ.get("HERDR_PANE_ID")
    workspace = os.environ.get("HERDR_WORKSPACE_ID")
    if any(p["pane_id"] == pane_id and p["workspace_id"] == workspace
           for p in data["panes"]):
        return workspace
    terminal = focused_terminal()
    return next((p["workspace_id"] for p in data["panes"]
                 if p["terminal_id"] == terminal), None)


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
        raise RuntimeError("No workspaces yet. Run: herdr-home project [PATH] [--label NAME]")
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


def prompt_input(prompt):
    try:
        return input(prompt).strip()
    except (EOFError, KeyboardInterrupt):
        return None


def remove_project(data, workspace):
    project = next((w for w in data["workspaces"] if w["workspace_id"] == workspace), None)
    if project is None:
        raise RuntimeError("Unknown workspace")
    label = re.sub(r"[\x00-\x1f\x7f]", " ", project["label"])
    print(f"Remove project {label} ({workspace})? All its terminal processes will stop.\n"
          "Project files and directories will NOT be deleted.")
    if prompt_input(f"Type {workspace} to remove, or Enter to cancel: ") != workspace:
        return False
    cli("workspace", "close", workspace)
    return True


def project_menu(data, allow_shell=False):
    """Return (workspace ID, newly created), or (None, False) on cancellation."""
    while True:
        rows = [(w["workspace_id"], w["label"]) for w in data["workspaces"]]
        rows.append(("action:new", "+ Create project"))
        if allow_shell:
            rows.append(("action:shell", "Open plain shell (without Herdr)"))
        if data["workspaces"]:
            rows.append(("action:directory", "Set project start directory..."))
            rows.append(("action:remove", "Remove project... (stop its processes; keep files)"))
        selected = pick(rows, "Project > ")
        if selected == "action:shell":
            plain_shell()
            return None, False
        if selected == "action:new":
            path = directory_choice()
            if path is None:
                return None, False
            created = create_project(path, Path(path).name or path)
            return created["workspace"]["workspace_id"], True
        if selected == "action:directory":
            workspace = workspace_choice(data)
            if workspace:
                path = directory_choice()
                if path:
                    save_directory(workspace, path)
                    print(f"Start directory: {path} (existing terminals unchanged)")
            data = snapshot()
            continue
        if selected == "action:remove":
            workspace = workspace_choice(data)
            if workspace:
                remove_project(data, workspace)
            data = snapshot()
            continue
        return selected, False


def plain_shell():
    shell = os.environ.get("SHELL") or "/bin/sh"
    os.execvp(shell, [shell, "-l"])


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
    create.add_argument("path", type=Path, nargs="?", default=Path.cwd())
    create.add_argument("--label")
    setting = commands.add_parser("set-directory", help="set the start directory for future terminals")
    setting.add_argument("path", type=Path, nargs="?")
    setting.add_argument("--workspace")
    setting.add_argument("--choose", action="store_true", help="choose a directory interactively")
    favorite = commands.add_parser("favorite", help="add a directory to picker favorites")
    favorite.add_argument("path", type=Path, nargs="?", default=Path.cwd())
    new = commands.add_parser("new", help="new tab/window, inheriting the focused managed terminal")
    new.add_argument("--workspace")
    new.add_argument("--cwd", type=Path)
    new.add_argument("--label")
    new.add_argument("--choose", action="store_true", help="always show the project menu")
    commands.add_parser("launch", help="niri launcher: preserve focus before opening any picker window")
    restore = commands.add_parser("restore", help="open an existing terminal, or all terminals in a project")
    restore.add_argument("--workspace")
    restore.add_argument("--all", action="store_true")
    commands.add_parser("pick", help="fuzzy-select and focus a project in Herdr")
    commands.add_parser("shell", help="open a plain shell without starting or attaching to Herdr")
    remove = commands.add_parser("remove", help="stop a project's processes and remove it; keep files")
    remove.add_argument("--workspace")
    commands.add_parser("list", help="print live workspace/tab/pane state as JSON")
    commands.add_parser("handoff", help="detach ONLY managed local views; keep every pane running")
    view = commands.add_parser("attach", help="internal: supervised direct attach")
    view.add_argument("terminal")
    args = parser.parse_args()
    if args.command == "shell":
        plain_shell()
        return 0
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
    if args.command == "favorite":
        path = directory(args.path)
        with directory_state(write=True) as state:
            if path not in state["favorites"]:
                state["favorites"].append(path)
        print(path)
        return 0
    if args.command == "set-directory" and args.path and args.choose:
        parser.error("set-directory accepts PATH or --choose, not both")
    data = ensure_server()
    if args.command == "list":
        print(json.dumps(data, ensure_ascii=False, indent=2))
        return 0
    if args.command == "project":
        path = directory(args.path)
        print(json.dumps(create_project(path, args.label or Path(path).name or path), ensure_ascii=False))
        return 0
    if args.command == "set-directory":
        workspace = args.workspace or context_workspace(data) or workspace_choice(data)
        if workspace is None:
            return 0
        if workspace not in {w["workspace_id"] for w in data["workspaces"]}:
            raise RuntimeError("Unknown workspace")
        path = directory_choice() if args.choose else directory(args.path or Path.cwd())
        if path:
            save_directory(workspace, path)
            print(f"Start directory: {path} (existing terminals unchanged)")
        return 0
    if args.command == "pick":
        workspace, _ = project_menu(data)
        if workspace:
            cli("workspace", "focus", workspace)
        return 0
    if args.command == "remove":
        if not data["workspaces"] and not args.workspace:
            print("No projects to remove.")
            return 0
        workspace = args.workspace or workspace_choice(data)
        if workspace:
            remove_project(data, workspace)
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
        args.choose = False
    workspace = args.workspace or (source["workspace_id"] if source else None)
    created = False
    if args.command == "new" and args.choose:
        workspace = None
        source = None
    if not workspace:
        workspace, created = project_menu(data, allow_shell=args.command == "new")
        data = snapshot()
    if workspace is None:
        return 0
    if workspace not in {w["workspace_id"] for w in data["workspaces"]}:
        raise RuntimeError("Unknown workspace")
    panes = [p for p in data["panes"] if p["workspace_id"] == workspace]
    if created:
        open_window(panes[0]["terminal_id"])
        return 0
    if args.command == "new":
        origin = source if source and source["workspace_id"] == workspace else {}
        key = workspace_key(workspace)
        with directory_state() as state:
            default = state["defaults"].get(key)
        legacy = next(iter(panes), {})
        cwd = (args.cwd or origin.get("foreground_cwd") or origin.get("cwd") or default
               or legacy.get("foreground_cwd") or legacy.get("cwd"))
        if not cwd:
            raise RuntimeError("No project CWD available; pass --cwd")
        cwd = directory(cwd)
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
