#!/usr/bin/env python3
import io
import plistlib
import struct
import subprocess
import tarfile
from pathlib import Path
root=Path(__file__).resolve().parents[2];out=root/'artifacts/ios6'
raw=(out/'cophone-Safari-Menu-iOS6-0.1.1.deb').read_bytes();assert raw[:8]==b'!<arch>\n';offset=8;members={}
while offset<len(raw):
    header=raw[offset:offset+60];assert header[-2:]==b'`\n';size=int(header[48:58]);members[header[:16].decode().strip().rstrip('/')]=raw[offset+60:offset+60+size];offset+=60+size+(size%2)
with tarfile.open(fileobj=io.BytesIO(members['data.tar.gz'])) as archive:
    base='Library/MobileSubstrate/DynamicLibraries/cophone-menu'
    assert set(archive.getnames())=={base+'.dylib',base+'.plist'}
    assert plistlib.loads(archive.extractfile(base+'.plist').read())=={'Filter':{'Bundles':['com.apple.mobilesafari']}}
    binary=archive.extractfile(base+'.dylib').read();assert binary==(out/'cophone-menu.dylib').read_bytes()
    magic,cpu,subtype,kind,count=struct.unpack_from('<5I',binary);assert (magic,cpu,subtype&255,kind)==(0xfeedface,12,9,6)
    position=28;minimum=False
    for _ in range(count):
        command,size=struct.unpack_from('<II',binary,position)
        assert command!=0x80000034
        if command==0x25:minimum=struct.unpack_from('<I',binary,position+8)[0]==0x60000
        position+=size
    assert minimum
with tarfile.open(fileobj=io.BytesIO(members['control.tar.gz'])) as archive:
    assert archive.getnames()==['control']
    control=archive.extractfile('control').read().decode();assert 'mobilesubstrate' in control and '0.4.0-7' in control
subprocess.run(['/usr/bin/codesign','--verify',str(out/'cophone-menu.dylib')],check=True)
print('PASS menu: armv7 dylib/iOS6/signature/Safari-only filter/no restart scripts')
