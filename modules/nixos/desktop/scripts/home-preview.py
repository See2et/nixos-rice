#!/usr/bin/env python3
# pyright: standard

import argparse
import fcntl
import json
import os
import re
import signal
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


HTTPS_PORT_MIN = 8443
HTTPS_PORT_MAX = 8499
NAME_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{0,62}$")
REGISTRY_VERSION = 1
DEFAULT_COMMAND_TIMEOUT_SECONDS = 15.0


class PreviewError(Exception):
    pass


def state_directory() -> Path:
    override = os.environ.get("HOME_PREVIEW_STATE_DIR")
    if override:
        return Path(override)
    state_home = os.environ.get("XDG_STATE_HOME")
    if state_home:
        return Path(state_home) / "home-preview"
    return Path.home() / ".local" / "state" / "home-preview"


def ensure_private_directory(path: Path) -> None:
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    metadata = path.lstat()
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
        raise PreviewError(f"state path is not a real directory: {path}")
    if metadata.st_uid != os.geteuid():
        raise PreviewError(f"state directory is not owned by uid {os.geteuid()}: {path}")
    os.chmod(path, 0o700)


def open_lock(path: Path):
    flags = os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags, 0o600)
    metadata = os.fstat(descriptor)
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.geteuid():
        os.close(descriptor)
        raise PreviewError(f"unsafe lock file: {path}")
    os.fchmod(descriptor, 0o600)
    lock_file = os.fdopen(descriptor, "r+")
    fcntl.flock(lock_file, fcntl.LOCK_EX)
    return lock_file


def empty_registry() -> dict:
    return {"version": REGISTRY_VERSION, "previews": {}}


def validate_registry(data: object) -> dict:
    if not isinstance(data, dict) or set(data) != {"version", "previews"}:
        raise PreviewError("registry has an unsupported structure")
    if data["version"] != REGISTRY_VERSION or not isinstance(data["previews"], dict):
        raise PreviewError("registry has an unsupported version")
    seen_ports = set()
    for name, preview in data["previews"].items():
        validate_name(name)
        if not isinstance(preview, dict) or set(preview) != {"upstream_port", "https_port"}:
            raise PreviewError(f"registry entry {name!r} has an unsupported structure")
        validate_port(preview["upstream_port"], "upstream port")
        validate_https_port(preview["https_port"])
        if preview["https_port"] in seen_ports:
            raise PreviewError("registry contains duplicate HTTPS ports")
        seen_ports.add(preview["https_port"])
    return data


def load_registry(path: Path) -> dict:
    if not path.exists():
        return empty_registry()
    metadata = path.lstat()
    if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
        raise PreviewError(f"registry is not a regular file: {path}")
    if metadata.st_uid != os.geteuid():
        raise PreviewError(f"registry is not owned by uid {os.geteuid()}: {path}")
    os.chmod(path, 0o600)
    try:
        with path.open("r", encoding="utf-8") as registry_file:
            return validate_registry(json.load(registry_file))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise PreviewError(f"registry is invalid JSON: {error}") from error


def save_registry(path: Path, registry: dict) -> None:
    validate_registry(registry)
    temporary_name = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent, prefix=".registry.", delete=False
        ) as temporary:
            temporary_name = temporary.name
            os.fchmod(temporary.fileno(), 0o600)
            json.dump(registry, temporary, indent=2, sort_keys=True)
            temporary.write("\n")
            temporary.flush()
            os.fsync(temporary.fileno())
        os.replace(temporary_name, path)
        temporary_name = None
        directory_descriptor = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_descriptor)
        finally:
            os.close(directory_descriptor)
    finally:
        if temporary_name:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass


def validate_name(name: object) -> str:
    if not isinstance(name, str) or not NAME_PATTERN.fullmatch(name):
        raise PreviewError("NAME must match [a-z0-9][a-z0-9-]{0,62}")
    return name


def validate_port(port: object, label: str) -> int:
    if isinstance(port, bool) or not isinstance(port, int):
        raise PreviewError(f"{label} must be an integer from 1 to 65535")
    if not 1 <= port <= 65535:
        raise PreviewError(f"{label} must be an integer from 1 to 65535")
    return port


def validate_https_port(port: object) -> int:
    validated_port = validate_port(port, "HTTPS port")
    if not HTTPS_PORT_MIN <= validated_port <= HTTPS_PORT_MAX:
        raise PreviewError(
            f"HTTPS port must be in the managed allocation range {HTTPS_PORT_MIN}..{HTTPS_PORT_MAX}"
        )
    return validated_port


def command_timeout_seconds() -> float:
    raw_timeout = os.environ.get(
        "HOME_PREVIEW_COMMAND_TIMEOUT_SECONDS", str(DEFAULT_COMMAND_TIMEOUT_SECONDS)
    )
    try:
        timeout = float(raw_timeout)
    except ValueError as error:
        raise PreviewError("command timeout must be a number") from error
    if not 0 < timeout <= 300:
        raise PreviewError("command timeout must be greater than 0 and at most 300 seconds")
    return timeout


def run_tailscale(arguments: list[str]) -> str:
    timeout = command_timeout_seconds()
    try:
        result = subprocess.run(
            ["tailscale", *arguments],
            text=True,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except FileNotFoundError as error:
        raise PreviewError("tailscale command is not available") from error
    except KeyboardInterrupt as error:
        raise PreviewError("operation cancelled") from error
    except subprocess.TimeoutExpired as error:
        raise PreviewError(f"tailscale command timed out after {timeout:g} seconds") from error
    except OSError as error:
        raise PreviewError(f"could not execute tailscale: {error}") from error
    if result.returncode in (-signal.SIGINT, 128 + signal.SIGINT):
        raise PreviewError("operation cancelled")
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise PreviewError(f"tailscale {' '.join(arguments[:2])} failed: {detail}")
    return result.stdout


def tailscale_json(arguments: list[str]) -> dict:
    output = run_tailscale(arguments)
    try:
        value = json.loads(output)
    except json.JSONDecodeError as error:
        raise PreviewError(f"tailscale returned invalid JSON: {error}") from error
    if not isinstance(value, dict):
        raise PreviewError("tailscale returned a non-object JSON value")
    return value


def node_dns_name(require_https: bool = False) -> str:
    status = tailscale_json(["status", "--json"])
    self_status = status.get("Self")
    dns_name = self_status.get("DNSName") if isinstance(self_status, dict) else None
    if not isinstance(dns_name, str) or not dns_name.strip("."):
        raise PreviewError("tailscale status does not contain Self.DNSName")
    dns_name = dns_name.rstrip(".")
    if require_https and dns_name not in (status.get("CertDomains") or []):
        raise PreviewError(
            "HTTPS certificates are not enabled for this node. "
            "Enable HTTPS Certificates at https://login.tailscale.com/admin/dns "
            "and retry. This does not enable Funnel or public access."
        )
    return dns_name


def serve_status() -> dict:
    return tailscale_json(["serve", "status", "--json"])


def proxy_target(upstream_port: int) -> str:
    return f"http://127.0.0.1:{upstream_port}"


def host_port(dns_name: str, https_port: int) -> str:
    return f"{dns_name}:{https_port}"


def port_state(status: dict, dns_name: str, https_port: int, upstream_port: int) -> str:
    port_key = str(https_port)
    expected_host_port = host_port(dns_name, https_port)
    tcp = status.get("TCP") or {}
    web = status.get("Web") or {}
    funnel = status.get("AllowFunnel") or {}
    if not all(isinstance(section, dict) for section in (tcp, web, funnel)):
        raise PreviewError("tailscale Serve status has an unsupported structure")

    tcp_entry = tcp.get(port_key)
    web_entry = web.get(expected_host_port)
    related_web = [key for key in web if key == expected_host_port or key.endswith(f":{https_port}")]
    related_funnel = [key for key, enabled in funnel.items() if enabled and key.endswith(f":{https_port}")]
    if tcp_entry is None and not related_web and not related_funnel:
        return "absent"
    expected = (
        isinstance(tcp_entry, dict)
        and tcp_entry.get("HTTPS") is True
        and set(tcp_entry) == {"HTTPS"}
        and related_web == [expected_host_port]
        and isinstance(web_entry, dict)
        and web_entry == {"Handlers": {"/": {"Proxy": proxy_target(upstream_port)}}}
        and not related_funnel
    )
    return "owned" if expected else "foreign"


def enable_preview(https_port: int, upstream_port: int) -> None:
    run_tailscale(
        [
            "serve",
            "--bg",
            "--yes",
            f"--https={https_port}",
            proxy_target(upstream_port),
        ]
    )


def disable_preview(https_port: int) -> None:
    run_tailscale(["serve", "--yes", f"--https={https_port}", "off"])


def allocate_https_port(registry: dict, status: dict) -> int:
    registry_ports = {preview["https_port"] for preview in registry["previews"].values()}
    tcp = status.get("TCP") or {}
    web = status.get("Web") or {}
    funnel = status.get("AllowFunnel") or {}
    if not all(isinstance(section, dict) for section in (tcp, web, funnel)):
        raise PreviewError("tailscale Serve status has an unsupported structure")
    for port in range(HTTPS_PORT_MIN, HTTPS_PORT_MAX + 1):
        suffix = f":{port}"
        if (
            port not in registry_ports
            and str(port) not in tcp
            and not any(key.endswith(suffix) for key in web)
            and not any(enabled and key.endswith(suffix) for key, enabled in funnel.items())
        ):
            return port
    raise PreviewError(f"no free HTTPS port in {HTTPS_PORT_MIN}..{HTTPS_PORT_MAX}")


def rollback_new_ports(ports: list[int]) -> list[str]:
    errors = []
    for port in reversed(ports):
        try:
            disable_preview(port)
        except PreviewError as error:
            errors.append(f"failed to roll back HTTPS port {port}: {error}")
    return errors


def add_partial_enable_to_rollback(
    ports: list[int], dns_name: str, https_port: int, upstream_port: int
) -> list[str]:
    try:
        state = port_state(serve_status(), dns_name, https_port, upstream_port)
    except PreviewError as error:
        return [f"could not verify partial enable on HTTPS port {https_port}: {error}"]
    if state == "owned":
        ports.append(https_port)
        return []
    if state == "foreign":
        return [
            f"HTTPS port {https_port} changed after enable failed; refusing unsafe cleanup"
        ]
    return []


def add_preview(registry_path: Path, registry: dict, args: argparse.Namespace) -> None:
    name = validate_name(args.name)
    upstream_port = validate_port(args.upstream_port, "upstream port")
    requested_https_port = (
        validate_https_port(args.https_port) if args.https_port is not None else None
    )
    if name in registry["previews"]:
        raise PreviewError(f"preview {name!r} already exists")
    dns_name = node_dns_name(require_https=True)
    status = serve_status()
    https_port = (
        requested_https_port
        if requested_https_port is not None
        else allocate_https_port(registry, status)
    )
    if any(preview["https_port"] == https_port for preview in registry["previews"].values()):
        raise PreviewError(f"HTTPS port {https_port} is already registered")
    if port_state(status, dns_name, https_port, upstream_port) != "absent":
        raise PreviewError(f"HTTPS port {https_port} conflicts with existing Serve configuration")

    enabled = False
    try:
        enable_preview(https_port, upstream_port)
        enabled = True
        if port_state(serve_status(), dns_name, https_port, upstream_port) != "owned":
            raise PreviewError("Serve configuration did not match the requested loopback proxy")
        registry["previews"][name] = {
            "upstream_port": upstream_port,
            "https_port": https_port,
        }
        save_registry(registry_path, registry)
    except (PreviewError, OSError) as error:
        rollback_errors = []
        if enabled:
            rollback_errors = rollback_new_ports([https_port])
        else:
            partial_ports = []
            rollback_errors = add_partial_enable_to_rollback(
                partial_ports, dns_name, https_port, upstream_port
            )
            rollback_errors.extend(rollback_new_ports(partial_ports))
        detail = f"; {'; '.join(rollback_errors)}" if rollback_errors else ""
        raise PreviewError(f"add failed: {error}{detail}") from error
    print(f"{name}: https://{dns_name}:{https_port}/ -> {proxy_target(upstream_port)}")


def list_previews(registry: dict) -> None:
    dns_name = node_dns_name()
    print("NAME\tUPSTREAM\tHTTPS\tURL")
    for name in sorted(registry["previews"]):
        preview = registry["previews"][name]
        print(
            f"{name}\t{preview['upstream_port']}\t{preview['https_port']}\t"
            f"https://{dns_name}:{preview['https_port']}/"
        )


def print_url(registry: dict, name: str) -> None:
    validate_name(name)
    preview = registry["previews"].get(name)
    if preview is None:
        raise PreviewError(f"preview {name!r} does not exist")
    print(f"https://{node_dns_name()}:{preview['https_port']}/")


def remove_preview(registry_path: Path, registry: dict, name: str) -> None:
    validate_name(name)
    preview = registry["previews"].get(name)
    if preview is None:
        raise PreviewError(f"preview {name!r} does not exist")
    dns_name = node_dns_name()
    state = port_state(
        serve_status(), dns_name, preview["https_port"], preview["upstream_port"]
    )
    if state == "foreign":
        raise PreviewError(
            f"HTTPS port {preview['https_port']} no longer matches {name!r}; refusing to remove it"
        )
    if state == "owned":
        disable_preview(preview["https_port"])
        after = port_state(
            serve_status(), dns_name, preview["https_port"], preview["upstream_port"]
        )
        if after != "absent":
            raise PreviewError(f"HTTPS port {preview['https_port']} was not removed")
    old_preview = registry["previews"].pop(name)
    try:
        save_registry(registry_path, registry)
    except OSError as error:
        if state == "owned":
            try:
                enable_preview(old_preview["https_port"], old_preview["upstream_port"])
            except PreviewError as rollback_error:
                raise PreviewError(
                    f"registry update failed and Serve rollback failed: {error}; {rollback_error}"
                ) from error
        raise PreviewError(f"registry update failed: {error}") from error
    print(f"removed {name}")


def apply_previews(registry: dict) -> None:
    dns_name = node_dns_name(require_https=True)
    initial_status = serve_status()
    missing = []
    for name, preview in sorted(registry["previews"].items()):
        state = port_state(
            initial_status, dns_name, preview["https_port"], preview["upstream_port"]
        )
        if state == "foreign":
            raise PreviewError(
                f"HTTPS port {preview['https_port']} for {name!r} conflicts with existing Serve configuration"
            )
        if state == "absent":
            missing.append((name, preview))

    added_ports = []
    attempted_preview = None
    try:
        for name, preview in missing:
            attempted_preview = preview
            enable_preview(preview["https_port"], preview["upstream_port"])
            added_ports.append(preview["https_port"])
            attempted_preview = None
            if (
                port_state(
                    serve_status(), dns_name, preview["https_port"], preview["upstream_port"]
                )
                != "owned"
            ):
                raise PreviewError(f"Serve verification failed for {name!r}")
    except PreviewError as error:
        rollback_errors = []
        if attempted_preview is not None:
            rollback_errors.extend(
                add_partial_enable_to_rollback(
                    added_ports,
                    dns_name,
                    attempted_preview["https_port"],
                    attempted_preview["upstream_port"],
                )
            )
        rollback_errors.extend(rollback_new_ports(added_ports))
        detail = f"; {'; '.join(rollback_errors)}" if rollback_errors else ""
        raise PreviewError(f"apply failed: {error}{detail}") from error
    print(f"applied {len(missing)} preview(s); {len(registry['previews']) - len(missing)} unchanged")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="home-preview",
        description=(
            "Manage private Tailscale Serve HTTPS proxies to local development ports. "
            f"Managed HTTPS ports are {HTTPS_PORT_MIN}..{HTTPS_PORT_MAX}. State is private to "
            "the invoking user; tailscale operator permission or root invocation is required."
        ),
    )
    commands = parser.add_subparsers(dest="command", required=True)
    add = commands.add_parser("add", help="create and persist a loopback preview")
    add.add_argument("name")
    add.add_argument("upstream_port", type=int)
    add.add_argument("https_port", type=int, nargs="?")
    commands.add_parser("list", help="list registered previews")
    url = commands.add_parser("url", help="print one preview URL")
    url.add_argument("name")
    remove = commands.add_parser("remove", help="remove one registered preview")
    remove.add_argument("name")
    commands.add_parser("apply", help="restore missing registered previews")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    directory = state_directory()
    try:
        ensure_private_directory(directory)
        with open_lock(directory / "registry.lock"):
            registry_path = directory / "registry.json"
            registry = load_registry(registry_path)
            if args.command == "add":
                add_preview(registry_path, registry, args)
            elif args.command == "list":
                list_previews(registry)
            elif args.command == "url":
                print_url(registry, args.name)
            elif args.command == "remove":
                remove_preview(registry_path, registry, args.name)
            elif args.command == "apply":
                apply_previews(registry)
        return 0
    except (PreviewError, OSError) as error:
        print(f"home-preview: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
