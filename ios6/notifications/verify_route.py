import io,plistlib,struct,subprocess,tarfile
from pathlib import Path
root=Path(__file__).resolve().parents[2];out=root/'artifacts/ios6'
data=(out/'cophone-Notification-Route-iOS6-0.1.3.deb').read_bytes()
assert data[:8]==b'!<arch>\n'
members={};at=8
while at<len(data):
 h=data[at:at+60];assert h[-2:]==b'`\n';n=int(h[48:58]);members[h[:16].decode().strip().rstrip('/')]=data[at+60:at+60+n];at+=60+n+(n%2)
with tarfile.open(fileobj=io.BytesIO(members['control.tar.gz'])) as t:
 assert t.getnames()==['control'],'No install or restart scripts'
 assert b'Version: 0.1.3\n' in t.extractfile('control').read()
with tarfile.open(fileobj=io.BytesIO(members['data.tar.gz'])) as t:
 base='Library/MobileSubstrate/DynamicLibraries/cophone-notification-route'
 assert set(t.getnames())=={base+'.dylib',base+'.plist'}
 assert plistlib.loads(t.extractfile(base+'.plist').read())=={'Filter':{'Bundles':['com.apple.springboard']}}
 binary=t.extractfile(base+'.dylib').read()
 assert struct.unpack_from('<II',binary)==(0xfeedface,12)
 assert binary==(out/'cophone-notification-route.dylib').read_bytes()
 assert b'launchFromPushOrLocalBulletin:origin:' in binary
 assert b'launchFromBulletinWithURL:bundleID:allowUnlock:animate:launchOrigin:' in binary
 assert b'ai.whaletech.cophone.notification-click' in binary
 assert b'SBGetScreenLockStatus' not in binary and b'SBSLaunchApplication' not in binary
subprocess.run(['/usr/bin/codesign','--verify',str(out/'cophone-notification-route.dylib')],check=True)
print('PASS route package: armv7 / signature / SpringBoard only / no restart scripts / no launch or lock RPC')
