"""Real namespace tests: no root, no package installation, no private data reads."""
import importlib.util
import json
import os
from pathlib import Path
import pwd
import shutil
import socket
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / 'scripts/isolated-makepkg.py'
HOME = Path(pwd.getpwuid(os.getuid()).pw_dir)
BUILDS = HOME / '.cache/machine-aur/builds'
KEYS = HOME / '.local/state/machine-update/aur-keys'


class IsolationTest(unittest.TestCase):
    def setUp(self):
        BUILDS.mkdir(parents=True, exist_ok=True)
        KEYS.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.work = Path(tempfile.mkdtemp(prefix='test-isolation-', dir=BUILDS))
        self.addCleanup(shutil.rmtree, self.work)
        self.host = tempfile.TemporaryDirectory()
        self.addCleanup(self.host.cleanup)
        self.canary = Path(self.host.name) / 'credential-canary'
        self.canary.write_text('not-a-real-secret')
        self.recipe = self.work / 'PKGBUILD'
        self.base = '''
pkgname=isolation-fixture
pkgver=1
pkgrel=1
pkgdesc='isolation test'
arch=(any)
license=(MIT)
package() {
    mkdir -p "$pkgdir/usr/share/isolation-fixture"
    printf 'fixture\\n' > "$pkgdir/usr/share/isolation-fixture/data"
}
'''

    def run_recipe(self, assertions='', *args):
        self.recipe.write_text(assertions + '\n' + self.base)
        with self.canary.open() as inherited:
            return subprocess.run([str(WRAPPER), *(args or ('--printsrcinfo',))],
                              cwd=self.work, capture_output=True, text=True,
                              env=dict(os.environ, SUDO_PASSWORD='canary-password',
                                       AWS_SECRET_ACCESS_KEY='canary-token'),
                              timeout=40, pass_fds=(inherited.fileno(),))

    def test_metadata_cannot_access_host(self):
        (self.work / 'escape').symlink_to(self.canary)
        assertions = f'''/usr/bin/python3 - <<'CHECK'
import os
from pathlib import Path
assert 'SUDO_PASSWORD' not in os.environ
assert 'AWS_SECRET_ACCESS_KEY' not in os.environ
assert 'SSH_AUTH_SOCK' not in os.environ
assert 'DBUS_SESSION_BUS_ADDRESS' not in os.environ
for path in {json.dumps([str(self.canary), str(HOME / 'REPOS'), '/etc/shadow', '/run/user/' + str(os.getuid())])}:
    assert not Path(path).exists(), path
assert not Path('escape').exists()
assert Path.home() == Path('/home/builder')
for fd in Path('/proc/self/fd').iterdir():
    try:
        assert 'credential-canary' not in os.readlink(fd)
    except FileNotFoundError:
        pass
status = Path('/proc/self/status').read_text()
assert 'NoNewPrivs:\\t1' in status
assert 'CapEff:\\t0000000000000000' in status
Path('sandbox-output').write_text('allowed')
CHECK
[ $? -eq 0 ] || exit 99
'''
        result = self.run_recipe(assertions)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.canary.read_text(), 'not-a-real-secret')
        self.assertEqual((self.work / 'sandbox-output').read_text(), 'allowed')
        self.assertNotIn('canary-password', result.stdout + result.stderr)

    def test_cannot_modify_git_hooks_or_system(self):
        subprocess.run(['git', 'init', '-q', str(self.work)], check=True)
        result = self.run_recipe('''
if echo bad > .git/config 2>/dev/null; then exit 90; fi
if touch /usr/bin/isolation-compromised 2>/dev/null; then exit 91; fi
if sudo -n true 2>/dev/null; then exit 92; fi
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('bad', (self.work / '.git/config').read_text())

    def test_cannot_reach_host_loopback(self):
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            port = listener.getsockname()[1]
            result = self.run_recipe(f'''python3 - <<'CHECK'
import socket
for address in ('127.0.0.1', '10.0.2.2'):
    try:
        connection = socket.create_connection((address, {port}), timeout=1)
    except OSError:
        continue
    connection.close()
    raise SystemExit('host loopback reachable')
CHECK
[ $? -eq 0 ] || exit 99
''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_builds_valid_archive_without_installing(self):
        result = self.run_recipe('', '--noconfirm', '--force')
        self.assertEqual(result.returncode, 0, result.stderr)
        archive = self.work / 'isolation-fixture-1-1-any.pkg.tar.zst'
        contents = subprocess.check_output(['bsdtar', '-tf', str(archive)], text=True)
        self.assertIn('usr/share/isolation-fixture/data', contents)
        self.assertFalse(Path('/usr/share/isolation-fixture').exists())

    def test_symlinked_git_rejected(self):
        (self.work / '.git').symlink_to(self.host.name)
        result = self.run_recipe()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must not be a symlink', result.stderr)

    def test_only_public_signing_keys_enter_sandbox(self):
        signing = Path(self.host.name) / 'signing'
        signing.mkdir(mode=0o700)
        gpg = ['/usr/bin/gpg', '--homedir', str(signing), '--batch',
               '--pinentry-mode', 'loopback', '--passphrase', '']
        subprocess.run([*gpg, '--quick-gen-key', 'Sandbox test <test@example.invalid>',
                        'ed25519', 'sign', '1d'], check=True, capture_output=True)
        self.addCleanup(subprocess.run, ['/usr/bin/gpgconf', '--homedir', str(signing),
                                        '--kill', 'all'], capture_output=True)
        message = self.work / 'message'
        message.write_text('public fixture')
        subprocess.run([*gpg, '--detach-sign', str(message)], check=True,
                       capture_output=True)
        self.recipe.write_text("""
gpg --batch --verify message.sig message || exit 95
[ -z "$(gpg --batch --with-colons --list-secret-keys 2>/dev/null)" ] || exit 96
""" + self.base)
        spec = importlib.util.spec_from_file_location('isolated_makepkg', WRAPPER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with mock.patch.object(module.Path, 'cwd', return_value=self.work), \
             mock.patch.object(module, 'KEYRING', signing):
            self.assertEqual(module.run(['--printsrcinfo']), 0)

    def test_sandbox_failure_never_executes_recipe(self):
        spec = importlib.util.spec_from_file_location('isolated_makepkg', WRAPPER)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.recipe.write_text("touch sandbox-bypassed\n" + self.base)
        original_popen = subprocess.Popen
        def unavailable(command, **kwargs):
            self.assertEqual(command[0], '/usr/bin/bwrap')
            return original_popen(['/usr/bin/false'], **kwargs)
        # Export public keys normally, then simulate an unavailable namespace.
        keys = subprocess.run(['/usr/bin/gpg', '--homedir', str(KEYS), '--batch',
                               '--export'], capture_output=True, check=True)
        with mock.patch.object(module.Path, 'cwd', return_value=self.work), \
             mock.patch.object(module.subprocess, 'run', return_value=keys), \
             mock.patch.object(module.subprocess, 'Popen', side_effect=unavailable):
            with self.assertRaisesRegex(RuntimeError, 'Sandbox setup failed'):
                module.run(['--printsrcinfo'])
        self.assertFalse((self.work / 'sandbox-bypassed').exists())

    def test_runner_rejects_boundary_overrides(self):
        for option in ('--makepkg=/bin/false', '--builddir=/tmp', '--makepkgconf',
                       '--sudo', '--sudoflags', '--sudoloop', '--nomakepkgconf',
                       '--save', '--'):
            with self.subTest(option=option):
                result = subprocess.run([str(ROOT / 'scripts/aur.sh'), '-Pg', option],
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 2)
                self.assertIn('cannot be overridden', result.stderr)

    def test_outside_workspace_rejected(self):
        result = subprocess.run([str(WRAPPER), '--printsrcinfo'], cwd=self.host.name,
                                capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Build directory must be', result.stderr)


if __name__ == '__main__':
    unittest.main()
