"""Exercise the notification script with isolated state and no real notifications."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "home/desktop/scripts/storage-notification.sh"
GIB = 1024**3


class StorageNotificationTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        stubs = {
            "df": '#!/bin/sh\n[ "${DF_FAIL:-0}" = 0 ] || exit 1\nprintf "Avail\\n%s\\n" "$AVAILABLE"\n',
            "notify-send": '#!/bin/sh\n[ "${NOTIFY_FAIL:-0}" = 0 ] || exit 1\nprintf "%s\\n" "$*" >> "$NOTIFICATIONS"\n',
        }
        for name, content in stubs.items():
            path = self.bin / name
            path.write_text(content)
            path.chmod(0o755)
        self.log = self.root / "notifications"
        self.env = {
            **os.environ,
            "PATH": f"{self.bin}:{os.environ['PATH']}",
            "HOME": str(self.root),
            "XDG_STATE_HOME": str(self.root / "state"),
            "NOTIFICATIONS": str(self.log),
        }

    def run_check(self, available, **extra):
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env={**self.env, "AVAILABLE": str(available), **extra},
            capture_output=True, text=True,
        )

    def check(self, available):
        result = self.run_check(available)
        self.assertEqual(result.returncode, 0, result.stderr)

    def notifications(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_thresholds(self):
        self.check(50 * GIB)
        self.assertEqual(self.notifications(), [])
        self.check(50 * GIB - 1)
        self.assertIn("--urgency=normal", self.notifications()[-1])
        self.check(20 * GIB)
        self.assertEqual(len(self.notifications()), 1)
        self.check(20 * GIB - 1)
        self.assertIn("--urgency=critical", self.notifications()[-1])
        self.assertEqual(len(self.notifications()), 2)

    def test_suppression_escalation_and_recovery(self):
        for available in [30 * GIB, 25 * GIB, 10 * GIB, 5 * GIB, 30 * GIB, 10 * GIB]:
            self.check(available)
        self.assertEqual(len(self.notifications()), 2)
        self.check(50 * GIB)
        self.check(30 * GIB)
        self.check(10 * GIB)
        self.assertEqual(len(self.notifications()), 4)

    def test_notification_failure_retries_without_losing_prior_state(self):
        self.check(30 * GIB)
        self.assertNotEqual(self.run_check(10 * GIB, NOTIFY_FAIL="1").returncode, 0)
        self.check(30 * GIB)
        self.assertEqual(len(self.notifications()), 1)
        self.check(10 * GIB)
        self.assertEqual(len(self.notifications()), 2)

    def test_measurement_failure_does_not_reset_suppression(self):
        self.check(10 * GIB)
        for extra in [{"DF_FAIL": "1"}, {}]:
            self.assertNotEqual(self.run_check("invalid", **extra).returncode, 0)
        self.check(10 * GIB)
        self.assertEqual(len(self.notifications()), 1)

    def test_initial_critical_and_zero_space(self):
        self.check(0)
        self.check(0)
        self.assertEqual(len(self.notifications()), 1)
        self.assertIn("--urgency=critical", self.notifications()[0])


if __name__ == "__main__":
    unittest.main()
