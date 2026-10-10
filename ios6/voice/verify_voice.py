#!/usr/bin/env python3
import io,plistlib,struct,subprocess,tarfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'artifacts/ios6'
data=(out/'cophone-Voice-iOS6-0.1.3.deb').read_bytes()
assert data[:8]==b'!<arch>\n'
members={};at=8
while at<len(data):
    h=data[at:at+60];assert h[-2:]==b'`\n';n=int(h[48:58]);members[h[:16].decode().strip().rstrip('/')]=data[at+60:at+60+n];at+=60+n+(n%2)
with tarfile.open(fileobj=io.BytesIO(members['control.tar.gz'])) as t:
    assert t.getnames()==['control'], 'No install/restart scripts permitted'
    control=t.extractfile('control').read()
    assert b'Version: 0.1.3\n' in control
    assert b'ai.whaletech.cophone.review (>= 0.4.0-14)' in control
with tarfile.open(fileobj=io.BytesIO(members['data.tar.gz'])) as t:
    base='Library/MobileSubstrate/DynamicLibraries/cophone-voice'
    assert set(t.getnames())=={base+'.dylib',base+'.plist'}
    assert plistlib.loads(t.extractfile(base+'.plist').read())=={'Filter':{'Bundles':['com.apple.springboard']}}
    binary=t.extractfile(base+'.dylib').read()
    assert struct.unpack_from('<II',binary)==(0xfeedface,12)
    assert binary==(out/'cophone-voice.dylib').read_bytes()
    assert b'handleHomeButtonHeld' in binary and b'preheatForMenuButtonWithFireDate:' in binary
subprocess.run(['/usr/bin/codesign','--verify',str(out/'cophone-voice.dylib')],check=True)
subprocess.run(['/bin/sh','-n',str(root/'安装 iPhone 语音入口.command')],check=True)
print('PASS voice: armv7 / SHA-1 signature / SpringBoard-only filter / no package scripts or automatic respring')
