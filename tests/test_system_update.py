"""Exercise updater orchestration without touching the host package database."""
import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class UpdateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.state = self.root / 'state' / 'machine-update'
        self.state.mkdir(parents=True)
        self.marker = self.state / 'last-success'
        self.marker.write_text('123\n')
        source = Path(__file__).resolve().parents[1] / 'scripts/system-update.sh'
        self.updater = self.bin / 'system-update.sh'
        shutil.copy2(source, self.updater)
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}',
                        XDG_STATE_HOME=str(self.state.parent))
        self.command('update-sudo.sh', 'exit "${AUTH_EXIT:-0}"')
        self.command('aur.sh', '''
[ ! -t 0 ] || exit 80
# No controlling terminal, even if called from a terminal launcher.
if (exec 8<>/dev/tty) 2>/dev/null; then exit 81; fi
[ "$GIT_TERMINAL_PROMPT" = 0 ] || exit 82
printf '%s\\n' "$@" > "$XDG_STATE_HOME/args"
exit "${UPGRADE_EXIT:-0}"
''')
        self.command('yay', '''
[ "${PENDING:-0}" = 0 ] || echo 'pending-package 1 -> 2'
exit "${QUERY_EXIT:-1}"
''')
        for name in ('pacdiff', 'checkrebuild', 'systemctl'):
            self.command(name, 'exit 0')
        self.command('pacman', 'exit 1')

    def command(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\nset -e\n' + body + '\n')
        path.chmod(0o755)

    def run_update(self, **environment):
        return subprocess.run([str(self.updater)], input='', text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              env=dict(self.env, **environment), timeout=10)

    def assert_failed(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('state=failed', (self.state / 'status').read_text())
        self.assertEqual(self.marker.read_text(), '123\n')

    def test_unattended_success(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('state=success', (self.state / 'status').read_text())
        self.assertNotEqual(self.marker.read_text(), '123\n')
        args = (self.state.parent / 'args').read_text().splitlines()
        for flag in ('--noconfirm', '--useask', '--pgpfetch', '--noremovemake',
                     '--diffmenu=false', '--editmenu=false'):
            self.assertIn(flag, args)
        self.assertEqual(args[args.index('--answerupgrade') + 1], 'None')

    def test_auth_failure_does_not_start_upgrade(self):
        self.assert_failed(self.run_update(AUTH_EXIT='1'))
        self.assertFalse((self.state.parent / 'args').exists())

    def test_query_diagnostic_is_failure(self):
        self.command('yay', 'if [ "$1" = -Qu ]; then echo "network error" >&2; exit 1; fi')
        self.assert_failed(self.run_update())

    def test_arguments_rejected(self):
        result = subprocess.run([str(self.updater), '--unexpected'],
                                capture_output=True, text=True, env=self.env,
                                timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.state / 'status').exists())

    def test_upgrade_failure(self):
        self.assert_failed(self.run_update(UPGRADE_EXIT='42'))

    def test_remaining_updates(self):
        self.assert_failed(self.run_update(PENDING='1', QUERY_EXIT='0'))

    def test_query_failure(self):
        self.assert_failed(self.run_update(QUERY_EXIT='2'))

    def test_concurrent_update_refused(self):
        with (self.state / 'update.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('already running', result.stdout)
        self.assertFalse((self.state / 'status').exists())
        self.assertEqual(self.marker.read_text(), '123\n')


if __name__ == '__main__':
    unittest.main()
