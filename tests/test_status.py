"""Regression checks for status reports, using isolated homes and fake system tools."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DOTFILES = ROOT.parent / 'dotfiles_hyprland'


class StatusTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.machine = self.root / 'machine'
        self.dot = self.root / 'dotfiles_hyprland'
        self.bin = self.root / 'bin'
        self.home = self.root / 'home'
        for path in (self.machine / 'system', self.dot / 'packages',
                     self.dot / 'config', self.bin, self.home / '.config'):
            path.mkdir(parents=True)
        shutil.copy(ROOT / 'update.sh', self.machine)
        for name in ('packages.sh', 'sync.sh'):
            shutil.copy(DOTFILES / name, self.dot)
        (self.dot / 'packages/base.txt').write_text('bubblewrap\n')
        (self.machine / 'system/services.txt').write_text('fixture.service\n')
        (self.machine / 'system/user-services.txt').write_text('')
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:/usr/bin:/bin')
        self.command('pacman', 'case "$1" in -Qq) echo bubblewrap;; -Qqe) echo extra;; *) exit 99;; esac')
        self.command('git', '[[ "$*" == *"status --short --branch" ]]')
        self.service()

    def command(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)

    def service(self, active='active', result='success', kind='simple', enabled='enabled'):
        self.command('systemctl', f"printf '%s\\n' 'UnitFileState={enabled}' 'ActiveState={active}' 'Result={result}' 'Type={kind}' 'SubState=dead'")

    def run_script(self, script, *args):
        return subprocess.run(['bash', str(script), *args], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_dependency_is_installed_and_install_does_nothing(self):
        result = self.run_script(self.dot / 'packages.sh', 'status', 'base')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Matched: 1', result.stdout)
        self.assertNotIn('Missing Packages', result.stdout)
        result = self.run_script(self.dot / 'packages.sh', 'install', 'base')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Nothing to install', result.stdout)

    def test_missing_package_fails_combined_status(self):
        (self.dot / 'packages/base.txt').write_text('absent\n')
        result = self.run_script(self.machine / 'update.sh', 'status')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Missing Packages', result.stdout)
        self.assertIn('Status check found issues', result.stdout)
        self.assertIn('[4/4]', result.stdout)

    def test_query_failure_is_not_success(self):
        self.command('pacman', 'exit 9')
        result = self.run_script(self.machine / 'update.sh', 'status')
        self.assertEqual(result.returncode, 1)

    def test_service_states(self):
        for active, result, kind, enabled, expected in (
            ('inactive', 'success', 'oneshot', 'enabled', 0),
            ('failed', 'exit-code', 'oneshot', 'enabled', 1),
            ('inactive', 'success', 'simple', 'enabled', 1),
            ('active', 'success', '', 'disabled', 1),
            ('inactive', 'success', 'simple', 'indirect', 1),
            ('active', 'success', '', 'enabled', 0),
        ):
            with self.subTest(active=active, kind=kind, enabled=enabled):
                self.service(active, result, kind, enabled)
                outcome = self.run_script(self.machine / 'update.sh', 'services')
                self.assertEqual(outcome.returncode, expected, outcome.stdout)

    def test_read_only_status_and_pull_failure(self):
        result = self.run_script(self.machine / 'update.sh', 'status')
        self.assertEqual(result.returncode, 0, result.stdout)
        result = self.run_script(self.machine / 'update.sh', 'full')
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('[2/4]', result.stdout)

    def test_wrong_and_broken_links_repaired_without_touching_destination(self):
        source = self.dot / 'config/example'
        source.mkdir()
        target = self.home / '.config/example'
        other = self.root / 'other'
        other.mkdir()
        for destination in (other, self.root / 'missing'):
            with self.subTest(destination=destination):
                target.symlink_to(destination)
                result = self.run_script(self.dot / 'sync.sh', 'status')
                self.assertEqual(result.returncode, 1)
                self.assertIn('broken or wrong symlink target', result.stdout)
                result = self.run_script(self.dot / 'sync.sh', 'fix')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(target.resolve(), source)
                self.assertTrue(other.is_dir())
                result = self.run_script(self.dot / 'sync.sh', 'status')
                self.assertEqual(result.returncode, 0)
                target.unlink()

    def test_ignore_globs(self):
        for name in ('private.env', 'example.bak.123', 'ordinary'):
            (self.home / '.config' / name).write_text('')
        result = self.run_script(self.dot / 'sync.sh', 'status')
        self.assertEqual(result.returncode, 0)
        self.assertNotIn('private.env', result.stdout)
        self.assertNotIn('example.bak.123', result.stdout)
        self.assertIn('ordinary', result.stdout)


if __name__ == '__main__':
    unittest.main()
