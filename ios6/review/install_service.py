#!/usr/bin/env python3
"""User-launched, one-time install of only the CoPhone launchd service."""
import getpass
import os
import socket
import subprocess
import sys
import time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from install import ROOT, tool, output, ssh_with_password


def main():
    package=ROOT/'artifacts/ios6/CoPhone-Review-Service-iOS6-0.4.0.deb'
    if not package.is_file():
        raise SystemExit('缺少后台服务 DEB，请先构建或使用完整项目交付文件。')
    devices=output([tool('idevice_id'),'-l']).splitlines()
    selected=os.environ.get('COPHONE_IOS_UDID')
    if not selected:
        if len(devices)!=1:raise SystemExit('请只连接一台 iPhone。')
        selected=devices[0]
    if selected not in devices:raise SystemExit('指定手机未通过 USB 连接。')
    model=output([tool('ideviceinfo'),'-u',selected,'-k','ProductType'])
    version=output([tool('ideviceinfo'),'-u',selected,'-k','ProductVersion'])
    if model not in ('iPhone3,1','iPhone3,2','iPhone3,3') or not version.startswith('6.'):
        raise SystemExit('此服务仅用于 iPhone 4 / iOS 6。')
    port=int(os.environ.get('COPHONE_REVIEW_SSH_PORT','2223'))
    with socket.socket() as check:
        check.bind(('127.0.0.1',port))
    checksum,length,*_=subprocess.check_output(['/usr/bin/cksum',str(package)],text=True).split()
    print('只安装 CoPhone 后台服务。不会安装 IPA、刷新图标或重启 SpringBoard。\n日常使用无需电脑或 SSH。',flush=True)
    password=getpass.getpass('本机输入 iPhone SSH root 密码（不回显、不保存）：')
    proxy=None
    try:
        proxy=subprocess.Popen([tool('iproxy'),'-s','127.0.0.1','-u',selected,f'{port}:22'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        time.sleep(0.4)
        if proxy.poll() is not None:raise RuntimeError('USB 转发启动失败。')
        remote=("set -e; umask 077; dir=$(mktemp -d /var/tmp/CoPhoneReview.XXXXXX); "
                "trap 'rm -rf \"$dir\"' EXIT HUP INT TERM; cat > \"$dir/service.deb\"; "
                "set -- $(cksum \"$dir/service.deb\"); "
                f'test "$1" = {checksum}; test "$2" = {length}; '
                'dpkg -i "$dir/service.deb"; '
                'launchctl list ai.whaletech.cophone.review; '
                'echo COPHONE_REVIEW_SERVICE_INSTALLED')
        args=['ssh','-T','-p',str(port),'-o','ConnectTimeout=10','-o','ServerAliveInterval=5','-o','ServerAliveCountMax=3','-o','NumberOfPasswordPrompts=1','-o','HostKeyAlgorithms=+ssh-rsa','-o','StrictHostKeyChecking=accept-new','-o','UserKnownHostsFile='+str(ROOT/'artifacts/ios6/review-known_hosts'),'root@127.0.0.1',remote]
        with package.open('rb') as source:
            code,transcript=ssh_with_password(args,password,source,timeout=90,emit=True)
        if code or 'COPHONE_REVIEW_SERVICE_INSTALLED' not in transcript:
            raise RuntimeError('服务安装未确认成功。请保留错误信息，不要反复猜密码。')
        print('\n后台服务已安装/更新。已安装 0.4.0 App 的手机无需重装 IPA；打开 cophone 开始新一轮即可。',flush=True)
    finally:
        password=None
        if proxy and proxy.poll() is None:
            proxy.terminate()
            try:proxy.wait(timeout=3)
            except subprocess.TimeoutExpired:proxy.kill();proxy.wait()

if __name__=='__main__':
    try:main()
    except (OSError,RuntimeError,subprocess.SubprocessError) as error:raise SystemExit(str(error))
