#!/usr/bin/env python3
"""USB update with local password prompt, verified staging and bounded retries."""
import fcntl
import getpass
import json
import os
import plistlib
import re
import select
import shlex
import shutil
import socket
import subprocess
import sys
import termios
import time
import warnings
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/ios6'
APP = OUT / 'CoPhone.app'
PORT = int(os.environ.get('COPHONE_SSH_PORT', '2222'))


def tool(name):
    path = shutil.which(name) or '/opt/homebrew/bin/' + name
    if not Path(path).exists():
        raise SystemExit('缺少工具：' + name + '。请先 brew install libimobiledevice libusbmuxd')
    return path


def output(args):
    return subprocess.check_output(args, text=True).strip()


def status(phase, **details):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'install-status.json').write_text(json.dumps(
        dict(phase=phase, **details), ensure_ascii=False, indent=2))


def ssh_ready():
    try:
        with socket.create_connection(('127.0.0.1', PORT), timeout=1) as connection:
            return connection.recv(256).startswith(b'SSH-')
    except OSError:
        return False


def build_payload():
    """Complete the archive before authentication; no tar producer can break pipe."""
    rows = []
    for path in sorted(APP.rglob('*')):
        if path.is_symlink():
            raise SystemExit('安装包不允许符号链接：' + str(path))
        if path.is_file():
            crc, size, _ = output(['/usr/bin/cksum', str(path)]).split(maxsplit=2)
            rows.append(crc + ' ' + size + ' ' + path.relative_to(OUT).as_posix())
    (OUT / 'install.manifest').write_text('\n'.join(rows) + '\n')
    payload = OUT / 'install.tar'
    subprocess.run(['/usr/bin/tar', '--format=ustar', '--no-xattrs', '--no-acls',
                    '--no-mac-metadata', '-cf', str(payload), '-C', str(OUT),
                    'CoPhone.app', 'install.manifest'],
                   env=dict(os.environ, COPYFILE_DISABLE='1'), check=True)
    return payload


def ssh_with_password(args, password, source, timeout=120, emit=True):
    """SSH owns a private controlling tty; only send a password with echo disabled.

    The secret stays in process memory, never in argv, environment or a file.
    File transfer uses stdin independently of SSH's /dev/tty password prompt.
    """
    master, slave = os.openpty()
    process = None
    transcript = bytearray()
    sent = False

    def controlling_tty():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    try:
        process = subprocess.Popen(args, stdin=source, stdout=slave, stderr=slave,
                                   preexec_fn=controlling_tty,
                                   env=dict(os.environ, LC_ALL='C'))
        os.close(slave)
        slave = None
        deadline = time.monotonic() + timeout
        while True:
            if time.monotonic() > deadline:
                process.terminate()
                return 124, transcript.decode(errors='replace') + '\nSSH 操作超时。'
            readable, _, _ = select.select([master], [], [], 0.2)
            if readable:
                try:
                    chunk = os.read(master, 8192)
                except OSError:
                    break  # macOS returns EIO after the slave tty closes.
                if not chunk:
                    break
                transcript.extend(chunk)
                if emit:
                    sys.stdout.write(chunk.decode(errors='replace'))
                    sys.stdout.flush()
                if not sent and re.search(rb'password:\s*$', transcript[-512:]):
                    if termios.tcgetattr(master)[3] & termios.ECHO:
                        raise RuntimeError('SSH 密码终端仍在回显，已停止，不发送密码。')
                    os.write(master, password.encode() + b'\n')
                    sent = True
            elif process.poll() is not None:
                break
        return process.wait(timeout=5), transcript.decode(errors='replace')
    finally:
        if slave is not None:
            os.close(slave)
        os.close(master)
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


REMOTE = r'''set -eu
test "$(id -u)" = 0
command -v cksum >/dev/null
stage="/Applications/.CoPhone-install-$$"
backup="/var/mobile/Library/CoPhoneLegacy/Backups/CoPhone-$(date +%s)-$$.app"
mkdir "$stage"
cleanup() {
  result=$?
  trap - EXIT
  if test "$result" != 0 && test -d "$backup" && ! test -d /Applications/CoPhone.app; then
    mv "$backup" /Applications/CoPhone.app || true
  fi
  rm -rf "$stage"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
tar -xf - -C "$stage"
test -f "$stage/install.manifest"
verify_tree() {
  base="$1"
  while read -r expected_crc expected_size filename; do
    test -f "$base/$filename" || return 1
    actual=$(cksum "$base/$filename") || return 1
    set -- $actual
    test "$1" = "$expected_crc" && test "$2" = "$expected_size" || return 1
  done < "$stage/install.manifest"
}
verify_tree "$stage"
echo COPHONE_STAGING_VERIFIED
if test -d /Applications/CoPhone.app && verify_tree /Applications; then
  echo COPHONE_ALREADY_CURRENT
else
  chmod 755 "$stage/CoPhone.app" "$stage/CoPhone.app/CoPhone"
  chown -R mobile:mobile "$stage/CoPhone.app"
  mkdir -p /var/mobile/Library/CoPhoneLegacy/Backups
  chown mobile:mobile /var/mobile/Library/CoPhoneLegacy
  if test -d /Applications/CoPhone.app; then
    if command -v killall >/dev/null 2>&1; then killall CoPhone 2>/dev/null || true; fi
    mv /Applications/CoPhone.app "$backup"
  fi
  mv "$stage/CoPhone.app" /Applications/CoPhone.app
fi
verify_tree /Applications
echo COPHONE_FILES_VERIFIED
if test -x /usr/bin/uicache && su mobile -c /usr/bin/uicache; then
  echo COPHONE_INSTALLED_AND_CACHE_REFRESHED
else
  echo COPHONE_INSTALLED_CACHE_NEEDS_REFRESH
fi
'''


def install_attempt(selected, payload, password):
    proxy = None
    try:
        with (OUT / 'iproxy.log').open('w') as log:
            proxy = subprocess.Popen([tool('iproxy'), '-s', '127.0.0.1', '-u', selected,
                                      str(PORT) + ':22'], stdout=log, stderr=log)
            for _ in range(30):
                time.sleep(0.1)
                if proxy.poll() is not None:
                    raise SystemExit('本机端口被占用或 USB 转发失败，详见 artifacts/ios6/iproxy.log。')
                if ssh_ready():
                    break
            else:
                return 255, 'OpenSSH 未响应，请保持手机连接并解锁。'
            ssh = ['/usr/bin/ssh', '-T', '-p', str(PORT), '-o', 'ConnectTimeout=10',
                   '-o', 'ServerAliveInterval=10', '-o', 'ServerAliveCountMax=3',
                   '-o', 'NumberOfPasswordPrompts=1', '-o', 'PubkeyAuthentication=no',
                   '-o', 'PreferredAuthentications=password,keyboard-interactive',
                   '-o', 'HostKeyAlgorithms=+ssh-rsa',
                   '-o', 'StrictHostKeyChecking=accept-new',
                   '-o', 'UserKnownHostsFile=' + str(OUT / 'known_hosts'),
                   'root@127.0.0.1', 'sh -c ' + shlex.quote(REMOTE)]
            with payload.open('rb') as source:
                return ssh_with_password(ssh, password, source)
    finally:
        if proxy is not None and proxy.poll() is None:
            proxy.terminate()
            try:
                proxy.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proxy.kill()
                proxy.wait()


def may_retry(returncode, transcript):
    text = transcript.lower()
    if any(message in text for message in ('permission denied', 'host key verification failed',
                                           'remote host identification has changed')):
        return False
    return returncode in (124, 255)


def main():
    # Retired permanently: even an old artifact must never reinstall the
    # /Applications legacy App or refresh SpringBoard's registration.
    raise SystemExit('旧经典版安装入口已停用，不安装任何 App、不刷新桌面。请用爱思助手 / iFunBox 手动安装 IPA，覆盖现有 cophone。详见 ios6/DEMO.md')


if __name__ == '__main__':
    raise SystemExit('旧系统 App 安装入口已停用；请手动安装 IPA，再运行 python3 ios6/deploy.py --voice。')
