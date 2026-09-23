#!/usr/bin/python3 -I
"""Run every makepkg operation inside a disposable, unprivileged sandbox."""
import json
import os
from pathlib import Path
import pwd
import select
import signal
import subprocess
import sys
import tempfile

USER_HOME = Path(pwd.getpwuid(os.getuid()).pw_dir)
BUILD_ROOT = USER_HOME / '.cache/machine-aur/builds'
KEYRING = USER_HOME / '.local/state/machine-update/aur-keys'
ENV = {'PATH': '/usr/bin', 'LANG': 'C.UTF-8', 'HOME': str(USER_HOME)}


def read_ready(fd):
    if not select.select([fd], [], [], 20)[0] or not os.read(fd, 1):
        raise RuntimeError('Sandbox network setup failed or timed out')


def stop(process):
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def run(arguments):
    if os.getuid() == 0:
        raise RuntimeError('Run AUR builds as the normal user, never root')
    work = Path.cwd().resolve()
    if work.parent != BUILD_ROOT or work.is_symlink():
        raise RuntimeError(f'Build directory must be directly inside {BUILD_ROOT}')
    if (work / '.git').is_symlink():
        raise RuntimeError('AUR checkout .git must not be a symlink')

    # No private keys, agent sockets, user makepkg config, or inherited secrets.
    keys = subprocess.run(
        ['/usr/bin/gpg', '--homedir', str(KEYRING), '--batch', '--export'],
        env=ENV, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, check=True).stdout
    sandbox = network = None
    descriptors = []
    with tempfile.TemporaryDirectory(prefix='aur-sandbox-') as temporary:
        temp = Path(temporary)
        files = {
            'resolv.conf': b'nameserver 10.0.2.3\n',
            'passwd': b'root:x:0:0:root:/root:/bin/false\nbuilder:x:1000:1000:builder:/home/builder:/bin/bash\nalpm:x:999:999:package downloads:/var/empty:/bin/false\n',
            'group': b'root:x:0:\nbuilder:x:1000:\n',
            'public-keys': keys,
        }
        for name, content in files.items():
            (temp / name).write_bytes(content)
        info_r, info_w = os.pipe()
        gate_r, gate_w = os.pipe()
        ready_r, ready_w = os.pipe()
        exit_r, exit_w = os.pipe()
        descriptors.extend((info_r, info_w, gate_r, gate_w, ready_r, ready_w, exit_r, exit_w))
        command = [
            '/usr/bin/bwrap', '--unshare-all', '--unshare-user', '--die-with-parent', '--new-session',
            '--uid', '1000', '--gid', '1000', '--cap-drop', 'ALL', '--disable-userns',
            '--hostname', 'aur-build', '--clearenv',
            '--ro-bind', '/usr', '/usr', '--tmpfs', '/usr/local',
            '--symlink', 'usr/bin', '/bin', '--symlink', 'usr/bin', '/sbin',
            '--symlink', 'usr/lib', '/lib', '--symlink', 'usr/lib', '/lib64',
            '--proc', '/proc', '--dev', '/dev', '--tmpfs', '/tmp',
            '--dir', '/run', '--dir', '/home/builder',
            '--ro-bind', '/var/lib/pacman', '/var/lib/pacman',
            '--bind', str(work), str(work), '--chdir', str(work),
            '--info-fd', str(info_w), '--block-fd', str(gate_r),
        ]
        # Only public system configuration needed by compilers, TLS, and pacman.
        for name in ('makepkg.conf', 'makepkg.conf.d', 'pacman.conf',
                     'pacman.d/mirrorlist', 'pacman.d/endeavouros-mirrorlist',
                     'ld.so.cache', 'nsswitch.conf', 'hosts', 'localtime',
                     'ssl/certs', 'ssl/cert.pem', 'ssl/openssl.cnf',
                     'ca-certificates/extracted'):
            path = Path('/etc') / name
            if path.exists():
                command.extend(('--ro-bind', str(path), str(path)))
        for name in files:
            target = '/public-keys' if name == 'public-keys' else f'/etc/{name}'
            command.extend(('--ro-bind', str(temp / name), target))
        # The host helper later runs git here: recipes must not plant git hooks.
        if (work / '.git').exists():
            command.extend(('--ro-bind', str(work / '.git'), str(work / '.git')))
        for key, value in {
            'PATH': '/usr/bin', 'HOME': '/home/builder', 'USER': 'builder',
            'LOGNAME': 'builder', 'LANG': 'C.UTF-8', 'TERM': 'dumb',
            'GNUPGHOME': '/home/builder/.gnupg', 'GIT_TERMINAL_PROMPT': '0',
            'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': '/dev/null',
            'GIT_SSH_COMMAND': 'ssh -oBatchMode=yes', 'PAGER': 'cat',
        }.items():
            command.extend(('--setenv', key, value))
        command.extend(('--', '/bin/bash', '-c', '''
set -e
mkdir -m 700 "$GNUPGHOME"
if [ -s /public-keys ]; then
    gpg --batch --import /public-keys >/dev/null 2>&1
fi
exec /usr/bin/makepkg "$@"
''', 'isolated-makepkg', *arguments))
        try:
            sandbox = subprocess.Popen(command, env=ENV, stdin=subprocess.DEVNULL,
                                       pass_fds=(info_w, gate_r))
            os.close(info_w)
            descriptors.remove(info_w)
            # bwrap emits one JSON object before waiting on --block-fd.
            if not select.select([info_r], [], [], 20)[0]:
                raise RuntimeError('Sandbox setup timed out')
            info = b''
            child_pid = None
            while True:
                chunk = os.read(info_r, 4096)
                if not chunk:
                    break
                info += chunk
                try:
                    child_pid = json.loads(info)['child-pid']
                    break
                except json.JSONDecodeError:
                    continue
            if child_pid is None:
                raise RuntimeError('Sandbox setup failed')
            network = subprocess.Popen([
                '/usr/bin/slirp4netns', '--configure', '--disable-host-loopback',
                '--enable-seccomp',
                '--ready-fd', str(ready_w), '--exit-fd', str(exit_r),
                str(child_pid), 'tap0',
            ], env=ENV, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                pass_fds=(ready_w, exit_r))
            os.close(ready_w)
            descriptors.remove(ready_w)
            read_ready(ready_r)
            os.write(gate_w, b'1')
            return sandbox.wait()
        finally:
            stop(sandbox)
            stop(network)
            for descriptor in descriptors:
                os.close(descriptor)


def interrupted(_signal, _frame):
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, interrupted)
    try:
        sys.exit(run(sys.argv[1:]))
    except KeyboardInterrupt:
        sys.exit(130)
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as error:
        print(f'Isolated build failed: {error}', file=sys.stderr)
        sys.exit(1)
