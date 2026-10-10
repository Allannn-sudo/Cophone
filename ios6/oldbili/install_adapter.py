#!/usr/bin/env python3
"""Install own service/menu packages, never IPA or a SpringBoard restart."""
import getpass
import io
import os
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from install import ROOT,tool,output,ssh_with_password

def main():
    names=['CoPhone-Review-Service-iOS6-0.4.0.deb','cophone-oldbili-adapter-0.2.1.deb']
    paths=[ROOT/'artifacts/ios6'/name for name in names]
    if not all(p.is_file() for p in paths):raise SystemExit('Missing service/menu DEB; build both first.')
    devices=output([tool('idevice_id'),'-l']).splitlines();selected=os.environ.get('COPHONE_IOS_UDID')
    if not selected:
        if len(devices)!=1:raise SystemExit('Connect one iPhone only.')
        selected=devices[0]
    if selected not in devices:raise SystemExit('Selected iPhone is not connected.')
    if output([tool('ideviceinfo'),'-u',selected,'-k','ProductType']) not in ('iPhone3,1','iPhone3,2','iPhone3,3') or not output([tool('ideviceinfo'),'-u',selected,'-k','ProductVersion']).startswith('6.'):
        raise SystemExit('iPhone 4 / iOS6 required.')
    port=int(os.environ.get('COPHONE_REVIEW_SSH_PORT','2223'))
    with socket.socket() as check:check.bind(('127.0.0.1',port))
    archive=io.BytesIO();checks=[]
    with tarfile.open(fileobj=archive,mode='w',format=tarfile.USTAR_FORMAT) as tar:
        for index,p in enumerate(paths):
            data=p.read_bytes();name=['service.deb','oldbili.deb'][index]
            entry=tarfile.TarInfo(name);entry.mode=0o600;entry.size=len(data);tar.addfile(entry,io.BytesIO(data))
            checksum,length,*_=subprocess.check_output(['/usr/bin/cksum',str(p)],text=True).split()
            checks.append('set -- $(cksum "$dir/'+name+'"); test "$1" = '+checksum+'; test "$2" = '+length+'; ')
    archive.seek(0)
    print('Install cophone background service, oldbili adapter. No IPA installation or SpringBoard restart.',flush=True)
    password=getpass.getpass('iPhone SSH password (hidden, not saved): ');proxy=None
    try:
        proxy=subprocess.Popen([tool('iproxy'),'-s','127.0.0.1','-u',selected,f'{port}:22'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(0.4)
        if proxy.poll() is not None:raise RuntimeError('USB forward failed.')
        remote=('set -e; umask 077; dir=$(mktemp -d /var/tmp/cophone-menu.XXXXXX); '
            'trap \'rm -rf "$dir"\' EXIT HUP INT TERM; tar -xf - -C "$dir"; '+''.join(checks)+
            'dpkg -i "$dir/service.deb" "$dir/oldbili.deb"; '
            'rm -f /Library/MobileSubstrate/DynamicLibraries/cophone-access-probe.dylib /Library/MobileSubstrate/DynamicLibraries/cophone-access-probe.plist; '
            'launchctl list ai.whaletech.cophone.review; echo COPHONE_MENU_INSTALLED_REOPEN_SAFARI')
        args=['ssh','-T','-p',str(port),'-o','ConnectTimeout=10','-o','ServerAliveInterval=5','-o','ServerAliveCountMax=3','-o','NumberOfPasswordPrompts=1','-o','HostKeyAlgorithms=+ssh-rsa','-o','StrictHostKeyChecking=accept-new','-o','UserKnownHostsFile='+str(ROOT/'artifacts/ios6/review-known_hosts'),'root@127.0.0.1',remote]
        with tempfile.TemporaryFile() as source:
            source.write(archive.getvalue());source.seek(0)
            code,transcript=ssh_with_password(args,password,source,timeout=90,emit=True)
        if code or 'COPHONE_MENU_INSTALLED_REOPEN_SAFARI' not in transcript:raise RuntimeError('Installation not confirmed; retain the error above.')
        print('Installed. Manually cover-install cophone 0.8.0 IPA, open it once, then quit/reopen oldbili. Daily use needs no computer.',flush=True)
    finally:
        password=None
        if proxy and proxy.poll() is None:
            proxy.terminate()
            try:proxy.wait(timeout=3)
            except subprocess.TimeoutExpired:proxy.kill();proxy.wait()
if __name__=='__main__':main()
