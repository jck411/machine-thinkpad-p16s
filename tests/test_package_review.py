"""Exercise package-review safeguards without invoking real package managers."""

import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
DOTFILES = ROOT.parent / "dotfiles_hyprland"


class PackageReviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=f"{self.bin}:/usr/bin:/bin",
                        XDG_STATE_HOME=str(self.home / "state"),
                        XDG_CONFIG_HOME=str(self.home / "config"),
                        CALLS=str(self.home / "calls"))
        for name in ("sudo", "yay", "pacman", "pacdiff", "systemctl", "checkrebuild"):
            self.command(name, 'printf "%s\\n" "$0 $*" >> "$CALLS"\nexit 0')

    def command(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def run_script(self, script, *args, terminal=False):
        master, slave = pty.openpty() if terminal else (None, None)
        try:
            return subprocess.run(["bash", str(script), *args], env=self.env,
                                  stdin=slave if terminal else subprocess.DEVNULL,
                                  capture_output=True, text=True, timeout=10)
        finally:
            if terminal:
                os.close(master)
                os.close(slave)

    def test_unattended_updater_cannot_invoke_package_managers(self):
        result = self.run_script(ROOT / "scripts/system-update.sh")
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.home / "calls").exists())

    def test_updater_rejects_bypass_arguments(self):
        result = self.run_script(ROOT / "scripts/system-update.sh",
                                 "--noconfirm", terminal=True)
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.home / "calls").exists())

    def test_cancelled_upgrade_does_not_reset_reminder(self):
        self.command("yay", "exit 1")
        result = self.run_script(ROOT / "scripts/system-update.sh", terminal=True)
        state = self.home / "state/machine-update"
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((state / "last-success").exists())
        self.assertIn("state=failed", (state / "status").read_text())

    def test_zero_exit_with_pending_updates_is_not_success(self):
        self.command("yay", 'if [[ "$1" == -Qu ]]; then echo "pending 1 -> 2"; fi')
        result = self.run_script(ROOT / "scripts/system-update.sh", terminal=True)
        state = self.home / "state/machine-update"
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((state / "last-success").exists())
        self.assertIn("state=failed", (state / "status").read_text())

    def test_successful_run_requires_confirmation_and_all_diffs(self):
        result = self.run_script(ROOT / "scripts/system-update.sh", terminal=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.home / "calls").read_text()
        self.assertIn("--confirm", calls)
        self.assertIn("--diffmenu --answerdiff All", calls)
        self.assertNotIn("--noconfirm", calls)
        self.assertTrue((self.home / "state/machine-update/last-success").exists())

    def test_empty_query_exit_one_is_success(self):
        self.command("yay", 'if [[ "$1" == -Qu ]]; then exit 1; fi')
        result = self.run_script(ROOT / "scripts/system-update.sh", terminal=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / "state/machine-update/last-success").exists())

    def test_query_error_is_not_success(self):
        self.command("yay", 'if [[ "$1" == -Qu ]]; then echo "network error" >&2; exit 1; fi')
        result = self.run_script(ROOT / "scripts/system-update.sh", terminal=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / "state/machine-update/last-success").exists())

    def test_overdue_shell_check_only_reminds(self):
        updater = self.home / "config/scripts/update-system.sh"
        updater.parent.mkdir(parents=True)
        updater.write_text('#!/bin/bash\necho invoked >> "$CALLS"\n')
        updater.chmod(0o755)
        result = self.run_script(DOTFILES / "config/scripts/check-updates.sh", terminal=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("review", result.stdout)
        self.assertFalse((self.home / "calls").exists())

    def test_unattended_install_blocks_before_any_package_mutation(self):
        shutil.copy(DOTFILES / "packages.sh", self.home / "packages.sh")
        (self.home / "packages").mkdir()
        (self.home / "packages/base.txt").write_text("untrusted-aur-fixture\n")
        self.command("pacman", '[[ "$1" == -Qqe ]]')
        self.env["NONINTERACTIVE"] = "1"
        result = self.run_script(self.home / "packages.sh", "install", "base")
        self.assertEqual(result.returncode, 2)
        self.assertIn("no packages were installed", result.stderr)
        self.assertFalse((self.home / "calls").exists())


if __name__ == "__main__":
    unittest.main()
