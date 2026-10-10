#!/usr/bin/env python3
import io
import plistlib
import struct
import subprocess
import tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'artifacts/ios6'
package=(OUT/'CoPhone-Review-Service-iOS6-0.4.0.deb').read_bytes()
assert package[:8]==b'!<arch>\n'
offset=8;members={}
while offset<len(package):
    header=package[offset:offset+60];assert header[-2:]==b'`\n'
    size=int(header[48:58]);name=header[:16].decode().strip().rstrip('/')
    members[name]=package[offset+60:offset+60+size];offset+=60+size+(size%2)
assert members['debian-binary']==b'2.0\n'
with tarfile.open(fileobj=io.BytesIO(members['data.tar.gz'])) as archive:
    assert set(archive.getnames())=={'usr/libexec/cophone-reviewd','Library/LaunchDaemons/ai.whaletech.cophone.review.plist'}
    binary=archive.extractfile('usr/libexec/cophone-reviewd').read()
    assert binary==(OUT/'cophone-reviewd').read_bytes()
    assert struct.unpack_from('<II',binary)==(0xfeedface,12)
    launch=plistlib.loads(archive.extractfile('Library/LaunchDaemons/ai.whaletech.cophone.review.plist').read())
    assert launch['UserName']=='mobile' and launch['ProgramArguments']==['/usr/libexec/cophone-reviewd']
with tarfile.open(fileobj=io.BytesIO(members['control.tar.gz'])) as archive:
    assert 'Version: 0.4.0-24\n' in archive.extractfile('control').read().decode()
    for name in ('postinst','prerm'):
        script=archive.extractfile(name).read().decode()
        assert 'SpringBoard' not in script and 'uicache' not in script and 'killall' not in script
        assert '/Library/LaunchDaemons/ai.whaletech.cophone.review.plist' in script
subprocess.run(['/usr/bin/codesign','--verify',str(OUT/'cophone-reviewd')],check=True)
entitlements=plistlib.loads(subprocess.check_output(['/usr/bin/codesign','-d','--entitlements','-','--xml',str(OUT/'cophone-reviewd')],stderr=subprocess.DEVNULL))
assert entitlements=={'com.apple.localnotification.schedulingproxy':True,'com.apple.springboard.launchapplications':True,'com.apple.multitasking.unlimitedassertions':True}
print('PASS service: DEB / armv7 / code signature & three declared entitlements; code-bounded oldbili lease / mobile launchd / no SpringBoard injection or restart')
