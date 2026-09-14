#!/usr/bin/env python3
# pyright: standard

import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
HOME_PREVIEW = REPO_ROOT / "modules/nixos/desktop/scripts/home-preview.py"
DNS_NAME = "desktop.example.ts.net"


FAKE_TAILSCALE = r'''#!/usr/bin/env python3
import json
import os
import sys
import time
from pathlib import Path

state_path = Path(os.environ["FAKE_TAILSCALE_STATE"])
log_path = Path(os.environ["FAKE_TAILSCALE_LOG"])
args = sys.argv[1:]
with log_path.open("a", encoding="utf-8") as log:
    log.write(json.dumps(args) + "\n")

if args == ["status", "--json"]:
    print(json.dumps({
        "Self": {"DNSName": "desktop.example.ts.net."},
        "CertDomains": None if os.environ.get("FAKE_TAILSCALE_NO_HTTPS") else ["desktop.example.ts.net"],
    }))
    raise SystemExit(0)
if args == ["serve", "status", "--json"]:
    bad_status_marker = os.environ.get("FAKE_TAILSCALE_BAD_STATUS_MARKER")
    if bad_status_marker and state_path.exists() and json.loads(state_path.read_text()).get("TCP"):
        marker = Path(bad_status_marker)
        if not marker.exists():
            marker.touch()
            print("not-json")
            raise SystemExit(0)
    print(state_path.read_text() if state_path.exists() else "{}")
    raise SystemExit(0)

failure_pattern = os.environ.get("FAKE_TAILSCALE_FAIL_CONTAINS")
if failure_pattern and failure_pattern in " ".join(args):
    print("injected tailscale failure", file=sys.stderr)
    raise SystemExit(int(os.environ.get("FAKE_TAILSCALE_FAIL_CODE", "23")))

state = json.loads(state_path.read_text()) if state_path.exists() else {}
state.setdefault("TCP", {})
state.setdefault("Web", {})
if len(args) == 5 and args[:3] == ["serve", "--bg", "--yes"] and args[3].startswith("--https="):
    port = args[3].split("=", 1)[1]
    target = args[4]
    state["TCP"][port] = {"HTTPS": True}
    state["Web"][f"desktop.example.ts.net:{port}"] = {"Handlers": {"/": {"Proxy": target}}}
    state_path.write_text(json.dumps(state), encoding="utf-8")
    if os.environ.get("FAKE_TAILSCALE_MUTATE_THEN_FAIL_PORT") == port:
        print("injected failure after mutation", file=sys.stderr)
        raise SystemExit(int(os.environ.get("FAKE_TAILSCALE_FAIL_CODE", "23")))
    if os.environ.get("FAKE_TAILSCALE_MUTATE_THEN_SLEEP_PORT") == port:
        time.sleep(5)
elif len(args) == 4 and args[:2] == ["serve", "--yes"] and args[2].startswith("--https=") and args[3] == "off":
    port = args[2].split("=", 1)[1]
    state["TCP"].pop(port, None)
    state["Web"].pop(f"desktop.example.ts.net:{port}", None)
else:
    print(f"unexpected argv: {args!r}", file=sys.stderr)
    raise SystemExit(64)
state_path.write_text(json.dumps(state), encoding="utf-8")
'''


class LoopbackHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("Upgrade", "").lower() == "websocket":
            self.send_response(101)
            self.send_header("Upgrade", "websocket")
            self.send_header("Connection", "Upgrade")
            self.send_header("Sec-WebSocket-Accept", "test-fixture")
            self.end_headers()
            return
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"loopback-ok")

    def log_message(self, format: str, *args: object) -> None:
        pass


class HomePreviewTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="home-preview-test-")
        self.root = Path(self.temporary.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        fake = self.bin_dir / "tailscale"
        fake.write_text(FAKE_TAILSCALE.replace("#!/usr/bin/env python3", f"#!{sys.executable}", 1), encoding="utf-8")
        fake.chmod(0o755)
        self.serve_state = self.root / "serve.json"
        self.log = self.root / "tailscale.log"
        self.state_dir = self.root / "user-state"
        self.environment = os.environ.copy()
        self.environment.update(
            {
                "PATH": f"{self.bin_dir}:{self.environment['PATH']}",
                "HOME_PREVIEW_STATE_DIR": str(self.state_dir),
                "FAKE_TAILSCALE_STATE": str(self.serve_state),
                "FAKE_TAILSCALE_LOG": str(self.log),
            }
        )

    def tearDown(self):
        self.temporary.cleanup()

    def run_cli(self, *arguments, success=True, extra_environment=None):
        environment = self.environment.copy()
        if extra_environment:
            environment.update(extra_environment)
        result = subprocess.run(
            [sys.executable, str(HOME_PREVIEW), *map(str, arguments)],
            text=True,
            capture_output=True,
            env=environment,
        )
        if success and result.returncode != 0:
            self.fail(f"command failed: {result.stderr}")
        if not success and result.returncode == 0:
            self.fail(f"command unexpectedly succeeded: {result.stdout}")
        return result

    def registry(self):
        return json.loads((self.state_dir / "registry.json").read_text())

    def serve(self):
        return json.loads(self.serve_state.read_text()) if self.serve_state.exists() else {}

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_add_list_url_remove_and_private_atomic_state(self):
        added = self.run_cli("add", "site", 3000)
        self.assertIn(f"https://{DNS_NAME}:8443/", added.stdout)
        self.assertEqual(
            self.serve()["Web"][f"{DNS_NAME}:8443"]["Handlers"]["/"]["Proxy"],
            "http://127.0.0.1:3000",
        )
        self.assertEqual(self.state_dir.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.state_dir / "registry.json").stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.run_cli("url", "site").stdout.strip(), f"https://{DNS_NAME}:8443/")
        listed = self.run_cli("list").stdout
        self.assertIn("site\t3000\t8443", listed)
        self.run_cli("remove", "site")
        self.assertEqual(self.registry()["previews"], {})
        self.assertNotIn("8443", self.serve().get("TCP", {}))
        self.assertIn(
            ["serve", "--bg", "--yes", "--https=8443", "http://127.0.0.1:3000"],
            self.calls(),
        )
        self.assertIn(["serve", "--yes", "--https=8443", "off"], self.calls())

    def test_https_setup_is_reported_before_any_serve_mutation(self):
        for command in [("add", "site", 3000), ("apply",)]:
            with self.subTest(command=command):
                result = self.run_cli(*command, success=False,
                                      extra_environment={"FAKE_TAILSCALE_NO_HTTPS": "1"})
                self.assertIn("https://login.tailscale.com/admin/dns", result.stderr)
                self.assertIn("HTTPS", result.stderr)
        self.assertTrue(all(call == ["status", "--json"] for call in self.calls()))
        self.assertFalse((self.state_dir / "registry.json").exists())
        self.assertEqual(self.serve(), {})

    def test_reapply_restores_only_missing_registered_ports(self):
        self.run_cli("add", "site", 3000, 8444)
        self.serve_state.write_text("{}", encoding="utf-8")
        result = self.run_cli("apply")
        self.assertIn("applied 1 preview(s)", result.stdout)
        self.assertEqual(
            self.serve()["Web"][f"{DNS_NAME}:8444"]["Handlers"]["/"]["Proxy"],
            "http://127.0.0.1:3000",
        )

    def test_apply_failure_rolls_back_ports_added_by_that_apply(self):
        self.run_cli("add", "one", 3000, 8443)
        self.run_cli("add", "two", 3001, 8444)
        self.serve_state.write_text("{}", encoding="utf-8")
        result = self.run_cli(
            "apply",
            success=False,
            extra_environment={"FAKE_TAILSCALE_MUTATE_THEN_FAIL_PORT": "8444"},
        )
        self.assertIn("apply failed", result.stderr)
        self.assertEqual(self.serve().get("TCP", {}), {})
        self.assertEqual(set(self.registry()["previews"]), {"one", "two"})

    def test_explicit_and_automatic_collisions_do_not_mutate_foreign_config(self):
        foreign = {
            "TCP": {"8443": {"HTTPS": True}},
            "Web": {
                f"{DNS_NAME}:8443": {"Handlers": {"/": {"Proxy": "http://127.0.0.1:9999"}}}
            },
        }
        self.serve_state.write_text(json.dumps(foreign), encoding="utf-8")
        automatic = self.run_cli("add", "site", 3000)
        self.assertIn(":8444/", automatic.stdout)
        before = self.serve_state.read_text()
        failed = self.run_cli("add", "other", 3001, 8443, success=False)
        self.assertIn("conflicts", failed.stderr)
        self.assertEqual(self.serve_state.read_text(), before)

    def test_funnel_port_is_never_claimed(self):
        existing = {"AllowFunnel": {f"{DNS_NAME}:8443": True}}
        self.serve_state.write_text(json.dumps(existing), encoding="utf-8")
        result = self.run_cli("add", "site", 3000, 8443, success=False)
        self.assertIn("conflicts", result.stderr)
        self.assertEqual(json.loads(self.serve_state.read_text()), existing)

    def test_add_failure_keeps_registry_empty(self):
        result = self.run_cli(
            "add",
            "site",
            3000,
            success=False,
            extra_environment={"FAKE_TAILSCALE_FAIL_CONTAINS": "--bg"},
        )
        self.assertIn("injected tailscale failure", result.stderr)
        self.assertFalse((self.state_dir / "registry.json").exists())

    def test_cancelled_add_keeps_registry_and_serve_empty(self):
        result = self.run_cli(
            "add",
            "site",
            3000,
            success=False,
            extra_environment={
                "FAKE_TAILSCALE_MUTATE_THEN_FAIL_PORT": "8443",
                "FAKE_TAILSCALE_FAIL_CODE": "130",
            },
        )
        self.assertIn("operation cancelled", result.stderr)
        self.assertFalse((self.state_dir / "registry.json").exists())
        self.assertEqual(self.serve().get("TCP", {}), {})
        self.assertEqual(self.serve().get("Web", {}), {})

    def test_timed_out_add_cleans_up_partial_enable(self):
        result = self.run_cli(
            "add",
            "site",
            3000,
            success=False,
            extra_environment={
                "FAKE_TAILSCALE_MUTATE_THEN_SLEEP_PORT": "8443",
                "HOME_PREVIEW_COMMAND_TIMEOUT_SECONDS": "0.1",
            },
        )
        self.assertIn("timed out after 0.1 seconds", result.stderr)
        self.assertFalse((self.state_dir / "registry.json").exists())
        self.assertEqual(self.serve().get("TCP", {}), {})
        self.assertIn(["serve", "--yes", "--https=8443", "off"], self.calls())

    def test_add_rolls_back_when_post_apply_status_is_invalid(self):
        result = self.run_cli(
            "add",
            "site",
            3000,
            success=False,
            extra_environment={
                "FAKE_TAILSCALE_BAD_STATUS_MARKER": str(self.root / "bad-status-used")
            },
        )
        self.assertIn("invalid JSON", result.stderr)
        self.assertFalse((self.state_dir / "registry.json").exists())
        self.assertEqual(self.serve().get("TCP", {}), {})
        self.assertIn(["serve", "--yes", "--https=8443", "off"], self.calls())

    def test_remove_preserves_unrelated_serve_port(self):
        foreign = {
            "TCP": {"8499": {"HTTPS": True}},
            "Web": {
                f"{DNS_NAME}:8499": {"Handlers": {"/": {"Proxy": "http://127.0.0.1:9999"}}}
            },
        }
        self.serve_state.write_text(json.dumps(foreign), encoding="utf-8")
        self.run_cli("add", "site", 3000, 8443)
        self.run_cli("remove", "site")
        self.assertEqual(self.serve()["TCP"]["8499"], {"HTTPS": True})
        self.assertEqual(
            self.serve()["Web"][f"{DNS_NAME}:8499"], foreign["Web"][f"{DNS_NAME}:8499"]
        )
        flattened_calls = [argument for call in self.calls() for argument in call]
        self.assertNotIn("reset", flattened_calls)
        self.assertNotIn("funnel", flattened_calls)

    def test_remove_refuses_changed_foreign_target(self):
        self.run_cli("add", "site", 3000)
        changed = self.serve()
        changed["Web"][f"{DNS_NAME}:8443"]["Handlers"]["/"]["Proxy"] = "http://127.0.0.1:9999"
        self.serve_state.write_text(json.dumps(changed), encoding="utf-8")
        before = self.serve_state.read_text()
        result = self.run_cli("remove", "site", success=False)
        self.assertIn("refusing to remove", result.stderr)
        self.assertEqual(self.serve_state.read_text(), before)
        self.assertIn("site", self.registry()["previews"])

    def test_validation_rejects_unsafe_inputs_before_tailscale(self):
        for arguments in [
            ("add", "../site", 3000),
            ("add", "site", 0),
            ("add", "site", 65536),
            ("add", "site", 3000, 8442),
            ("add", "site", 3000, 8500),
        ]:
            with self.subTest(arguments=arguments):
                self.run_cli(*arguments, success=False)
        self.assertFalse(self.log.exists())

    def test_loopback_fixture_handles_http_and_websocket_upgrade(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), LoopbackHandler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            port = server.server_address[1]
            self.run_cli("add", "hmr", port)
            target = self.serve()["Web"][f"{DNS_NAME}:8443"]["Handlers"]["/"]["Proxy"]
            self.assertEqual(target, f"http://127.0.0.1:{port}")
            with socket.create_connection(("127.0.0.1", port)) as connection:
                connection.sendall(
                    b"GET /hmr HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n"
                    b"Connection: Upgrade\r\nSec-WebSocket-Key: fixture\r\n\r\n"
                )
                self.assertIn(b"101 Switching Protocols", connection.recv(4096))
        finally:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
