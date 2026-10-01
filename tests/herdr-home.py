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


def run(args, env, ok=True, input_text=None):
    result = subprocess.run(args, env=env, text=True, capture_output=True, timeout=20,
                            input=input_text)
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
        fzf = shim_dir / "fzf"
        fzf.write_text(f'''#!{sys.executable}
import os,sys,subprocess
rows=sys.stdin.read()
if any(arg.startswith("--prompt=Directory") for arg in sys.argv):
    from pathlib import Path
    Path(os.environ["QA_ROWS"]).write_text(rows)
    query=os.environ.get("QA_DIRECTORY", "(current")
    chosen=next((row for row in rows.splitlines() if query in row), None)
    if chosen: print(chosen)
    sys.exit(0 if chosen else 130)
result=subprocess.run([{shutil.which("fzf")!r}, *sys.argv[1:]], input=rows, text=True)
sys.exit(result.returncode)
''')
        fzf.chmod(0o700)
        env["QA_ROWS"] = str(root / "directory-rows")
        env["PATH"] = str(shim_dir) + os.pathsep + env["PATH"]
        helper = [sys.executable, str(HELPER)]
        def api(*args):
            result = json.loads(run([HERDR, *args], env))["result"]
            return result["snapshot"] if args == ("api", "snapshot") else result
        child_pid = None
        try:
            run(helper + ["--help"], env)
            run(helper + ["unknown"], env, ok=False)
            shell = shim_dir / "plain-shell"
            shell.write_text('#!/bin/sh\nprintf "PLAIN_SHELL\\n"\n')
            shell.chmod(0o700)
            plain_env = dict(env, SHELL=str(shell))
            assert "PLAIN_SHELL" in run(helper + ["shell"], plain_env)
            assert not (root / "api.sock").exists(), "plain shell started Herdr"
            # Favorite registration is available without launching a server; explicit
            # default endpoint/config paths share state with an ordinary shell.
            namespace_env = dict(env, XDG_STATE_HOME=str(root / "namespace-state"))
            namespace_env.pop("HERDR_SOCKET_PATH")
            namespace_env.pop("HERDR_CONFIG_PATH")
            run(helper + ["favorite", folder], namespace_env)
            assert not (root / "config/herdr/herdr.sock").exists()
            alias_env = dict(namespace_env, HERDR_SOCKET_PATH=str(root / "config/herdr/herdr.sock"),
                             HERDR_CONFIG_PATH=str(root / "config/herdr/config.toml"))
            run(helper + ["favorite", str(root / "tmp")], alias_env)
            files = list((root / "namespace-state/herdr-home").glob("*/directories.json"))
            assert len(files) == 1
            assert set(json.loads(files[0].read_text())["favorites"]) == {folder, str(root / "tmp")}
            # Home Manager changes config symlink targets on rebuild, not identity.
            config_link = root / "linked-config.toml"
            config_link.symlink_to(root / "config.toml")
            linked_env = dict(env, HERDR_CONFIG_PATH=str(config_link),
                              XDG_STATE_HOME=str(root / "linked-state"))
            run(helper + ["favorite", folder], linked_env)
            alternate_config = root / "alternate-config.toml"
            alternate_config.write_text((root / "config.toml").read_text())
            config_link.unlink()
            config_link.symlink_to(alternate_config)
            run(helper + ["favorite", str(root / "tmp")], linked_env)
            files = list((root / "linked-state/herdr-home").glob("*/directories.json"))
            assert len(files) == 1
            assert len(json.loads(files[0].read_text())["favorites"]) == 2
            # Even an empty server offers creation and opt-out.
            plain_env["FZF_DEFAULT_OPTS"] = "--filter=Open\\ plain\\ shell"
            assert "PLAIN_SHELL" in run(helper + ["new", "--choose"], plain_env)
            assert not api("api", "snapshot")["workspaces"]
            create_env = dict(env, FZF_DEFAULT_OPTS="--filter=Create\\ project")
            run(helper + ["new", "--choose"], create_env, input_text=None)
            assert not api("api", "snapshot")["workspaces"], "EOF at name prompt created a project"
            run(helper + ["new", "--choose"], create_env,
                input_text="menu-project\n")
            menu_state = api("api", "snapshot")
            menu_workspace = menu_state["workspaces"][0]["workspace_id"]
            assert menu_state["workspaces"][0]["label"] == "menu-project"
            assert len(menu_state["tabs"]) == 1, "creation opened an extra tab"
            created = json.loads(run(helper + ["project", folder, "--label", "project-alpha"], env))
            workspace = created["workspace"]["workspace_id"]
            pane = created["root_pane"]
            terminal = pane["terminal_id"]
            run(helper + ["remove", "--workspace", menu_workspace], env, input_text="\n")
            assert len(api("api", "snapshot")["workspaces"]) == 2
            run(helper + ["remove", "--workspace", menu_workspace], env, input_text="wrong\n")
            assert len(api("api", "snapshot")["workspaces"]) == 2
            run(helper + ["remove", "--workspace", menu_workspace], env,
                input_text=menu_workspace + "\n")
            remaining = api("api", "snapshot")
            assert [w["workspace_id"] for w in remaining["workspaces"]] == [workspace]
            assert remaining["panes"][0]["terminal_id"] == terminal
            assert (root / "config.toml").exists(), "removal deleted project files"
            run(helper + ["new", "--workspace", workspace, "--cwd", folder], env)
            state = api("api", "snapshot")
            assert len(state["tabs"]) == 2, state
            assert all(p["cwd"] == folder for p in state["panes"])
            run(helper + ["new", "--workspace", "missing"], env, ok=False)
            run(helper + ["pick"], env)
            assert api("api", "snapshot")["focused_workspace_id"] == workspace
            assert len(api("api", "snapshot")["tabs"]) == 2
            assert "PLAIN_SHELL" in run(helper + ["new", "--choose"], plain_env)
            assert len(api("api", "snapshot")["tabs"]) == 2

            # Optional path, post-hoc defaults and discovery use only isolated state.
            nameless = json.loads(run(helper + ["project", "--label", "name-only"], env))
            assert nameless["root_pane"]["cwd"] == str(Path.cwd())
            api("workspace", "close", nameless["workspace"]["workspace_id"])
            changed = root / "outside ghq"
            changed.mkdir()
            explicit = root / "explicit"
            explicit.mkdir()
            before_panes = api("api", "snapshot")["panes"]
            run(helper + ["set-directory", str(changed), "--workspace", workspace], env)
            assert api("api", "snapshot")["panes"] == before_panes
            run(helper + ["new", "--workspace", workspace], env)
            assert api("api", "snapshot")["panes"][-1]["cwd"] == str(changed)
            run(helper + ["new", "--workspace", workspace, "--cwd", str(explicit)], env)
            assert api("api", "snapshot")["panes"][-1]["cwd"] == str(explicit)
            # UI focus belongs to alpha's original pane, so its cwd beats saved default.
            niri = shim_dir / "niri"
            niri.write_text(f'#!{sys.executable}\nimport json\nprint(json.dumps({{"app_id": "herdr-home.{terminal}"}}))\n')
            niri.chmod(0o700)
            focus_env = dict(env, NIRI_SOCKET="qa")
            run(helper + ["new", "--workspace", workspace], focus_env)
            assert api("api", "snapshot")["panes"][-1]["cwd"] == folder
            # Shell context beats unrelated focus for setting a project's directory.
            other = json.loads(run(helper + ["project", folder, "--label", "other"], env))
            context_env = dict(focus_env, HERDR_WORKSPACE_ID=other["workspace"]["workspace_id"],
                               HERDR_PANE_ID=other["root_pane"]["pane_id"])
            run(helper + ["set-directory", str(explicit)], context_env)
            run(helper + ["new", "--workspace", other["workspace"]["workspace_id"]], env)
            assert api("api", "snapshot")["panes"][-1]["cwd"] == str(explicit)
            api("workspace", "close", other["workspace"]["workspace_id"])
            run(helper + ["favorite", str(changed)], env)
            ghq_repo = root / "ghq" / "repo"
            ghq_repo.mkdir(parents=True)
            ghq = shim_dir / "ghq"
            ghq.write_text(f'#!{sys.executable}\nprint({str(ghq_repo)!r})\n')
            ghq.chmod(0o700)
            choice_env = dict(env, QA_DIRECTORY=str(ghq_repo))
            run(helper + ["set-directory", "--workspace", workspace, "--choose"], choice_env)
            rows = (root / "directory-rows").read_text()
            assert str(changed) in rows and "favorites" in rows and "ghq" in rows
            run(helper + ["new", "--workspace", workspace], env)
            assert api("api", "snapshot")["panes"][-1]["cwd"] == str(ghq_repo)
            # Missing ghq falls back to the same chooser; manual paths accept spaces.
            ghq.unlink()
            missing_ghq_env = dict(env, PATH=str(shim_dir), HERDR_BIN=shutil.which(HERDR),
                                   QA_DIRECTORY="Enter a path")
            run(helper + ["set-directory", "--workspace", workspace, "--choose"],
                missing_ghq_env, input_text=str(changed) + "\n")
            state_file = next((root / "state/herdr-home").glob("*/directories.json"))
            # Concurrent registrations must merge rather than lose an update.
            concurrent = [subprocess.Popen(helper + ["favorite", str(path)], env=env,
                                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                          for path in (root / "tmp", root / "zsh")]
            for process in concurrent:
                out, err = process.communicate(timeout=20)
                assert process.returncode == 0, (out, err)
            assert {str(root / "tmp"), str(root / "zsh")} <= set(json.loads(state_file.read_text())["favorites"])
            saved = state_file.read_text()
            cancel_env = dict(create_env, QA_DIRECTORY="NO-MATCH")
            count = len(api("api", "snapshot")["workspaces"])
            run(helper + ["new", "--choose"], cancel_env, input_text="cancelled\n")
            assert len(api("api", "snapshot")["workspaces"]) == count
            run(helper + ["set-directory", str(root / "missing"), "--workspace", workspace], env, ok=False)
            assert state_file.read_text() == saved
            state_file.write_text("corrupt")
            run(helper + ["favorite", folder], env, ok=False)
            run(helper + ["project", folder, "--label", "corrupt"], env, ok=False)
            assert state_file.read_text() == "corrupt"
            assert len(api("api", "snapshot")["workspaces"]) == count
            state_file.write_text(saved)
            tab_count = len(api("api", "snapshot")["tabs"])

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
            assert len(api("api", "snapshot")["tabs"]) == tab_count
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
            # Restart must never reuse a w1/w2 default for a different project.
            run([HERDR, "server", "stop"], env)
            fresh = json.loads(run(helper + ["project", folder, "--label", "fresh"], env))
            state_after_restart = json.loads(state_file.read_text())
            assert len(state_after_restart["defaults"]) == 1
            assert str(changed) in state_after_restart["favorites"]
            run(helper + ["new", "--workspace", fresh["workspace"]["workspace_id"]], env)
            assert api("api", "snapshot")["panes"][-1]["cwd"] == folder
            print("herdr-home: directory defaults, context, discovery, cancellation and state isolation passed")
            print("herdr-home: real server create/new/fuzzy-pick/direct-attach/handoff/restore passed")
            print("herdr-home: ANSI output observed; sleep survived handoff and outer PTY close")
        finally:
            if child_pid is not None:
                os.kill(child_pid, signal.SIGTERM)
                os.waitpid(child_pid, 0)
            subprocess.run([HERDR, "server", "stop"], env=env, capture_output=True, timeout=10)


if __name__ == "__main__":
    main()
