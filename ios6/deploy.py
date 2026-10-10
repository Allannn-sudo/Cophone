#!/usr/bin/env python3
"""Install release DEBs over USB. Never installs IPA, restarts SpringBoard, or reads AI keys."""
import argparse
import getpass
import io
import socket
import subprocess
import tarfile
import tempfile
import time
from pathlib import Path
from install import ROOT, tool, output, ssh_with_password


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--voice', action='store_true', help='首次安装长按 Home 插件；需随后手动重载一次桌面')
    parser.add_argument('--skip-notification-route', action='store_true', help='仅在不需要完成通知直接跳转时，跳过通知插件')
    parser.add_argument('--udid')
    parser.add_argument('--port', type=int, default=2224)
    args = parser.parse_args()
    names = ['CoPhone-Review-Service-iOS6-0.4.0.deb', 'cophone-Safari-Menu-iOS6-0.1.1.deb', 'cophone-oldbili-adapter-0.2.1.deb']
    if args.voice: names.append('cophone-Voice-iOS6-0.1.3.deb')
    if not args.skip_notification_route: names.append('cophone-Notification-Route-iOS6-0.1.3.deb')
    paths = [ROOT / 'artifacts/ios6' / name for name in names]
    if not all(p.is_file() for p in paths): raise SystemExit('缺少安装包，请检查 artifacts/ios6 或先构建。')
    devices = output([tool('idevice_id'), '-l']).split()
    selected = args.udid or (devices[0] if len(devices) == 1 else None)
    if not selected or selected not in devices: raise SystemExit('请只连接一台 iPhone，或用 --udid 指定。')
    if output([tool('ideviceinfo'), '-u', selected, '-k', 'ProductType']) not in ('iPhone3,1', 'iPhone3,2', 'iPhone3,3') or output([tool('ideviceinfo'), '-u', selected, '-k', 'ProductVersion']) != '6.1.3':
        raise SystemExit('部署必须使用已越狱的 iPhone 4 / iOS 6.1.3。')
    with socket.socket() as check: check.bind(('127.0.0.1', args.port))
    archive, checks = io.BytesIO(), []
    with tarfile.open(fileobj=archive, mode='w', format=tarfile.USTAR_FORMAT) as tar:
        for index, p in enumerate(paths):
            data, name = p.read_bytes(), f'{index}.deb'
            entry = tarfile.TarInfo(name); entry.mode = 0o600; entry.size = len(data)
            tar.addfile(entry, io.BytesIO(data))
            checksum, length, *_ = subprocess.check_output(['/usr/bin/cksum', str(p)], text=True).split()
            checks.append('set -- $(cksum "$dir/' + name + '"); test "$1" = ' + checksum + '; test "$2" = ' + length + '; ')
    print('仅更新 cophone 自有后台组件；不安装 IPA，不刷新桌面，不读取 AI Key。', flush=True)
    password = getpass.getpass('iPhone SSH 密码（隐藏输入，不保存）：')
    proxy = None
    try:
        proxy = subprocess.Popen([tool('iproxy'), '-s', '127.0.0.1', '-u', selected, f'{args.port}:22'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.4)
        if proxy.poll() is not None: raise RuntimeError('USB 转发失败。')
        remote = ('set -e; umask 077; dir=$(mktemp -d /var/tmp/cophone-deploy.XXXXXX); '
            'trap \'rm -rf "$dir"\' EXIT HUP INT TERM; tar -xf - -C "$dir"; ' + ''.join(checks)
            + 'dpkg -i ' + ' '.join('"$dir/' + str(i) + '.deb"' for i in range(len(paths)))
            + '; launchctl list ai.whaletech.cophone.review; echo COPHONE_DEPLOY_CONFIRMED')
        ssh = ['ssh', '-T', '-p', str(args.port), '-o', 'ConnectTimeout=10', '-o', 'ServerAliveInterval=5', '-o', 'ServerAliveCountMax=3', '-o', 'NumberOfPasswordPrompts=1', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'UserKnownHostsFile=' + str(ROOT / 'artifacts/ios6/deploy-known_hosts'), 'root@127.0.0.1', remote]
        with tempfile.TemporaryFile() as source:
            source.write(archive.getvalue()); source.seek(0)
            code, transcript = ssh_with_password(ssh, password, source, timeout=90, emit=True)
        if code or 'COPHONE_DEPLOY_CONFIRMED' not in transcript: raise RuntimeError('安装未确认，请保留错误。')
        print('后台安装确认成功。Safari/oldbili 首次更新需退出重开；日常任务无需电脑。')
        if args.voice or not args.skip_notification_route: print('系统插件首次加载需你保存内容后手动重新加载一次桌面；本脚本没有执行。')
    finally:
        password = None
        if proxy and proxy.poll() is None:
            proxy.terminate()
            try: proxy.wait(timeout=3)
            except subprocess.TimeoutExpired: proxy.kill(); proxy.wait()
if __name__ == '__main__': main()
