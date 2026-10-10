import sys,plistlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'review'))
from build import ROOT,OUT,TOOLS,run
from build_service import ar_member,tar_bytes
obj=OUT/'notification-route.o';binary=OUT/'cophone-notification-route.dylib'
run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',OUT/'sdk','-fobjc-arc','-fblocks','-Os','-c',ROOT/'ios6/notifications/NotificationRoute.m','-o',obj])
run([TOOLS/'ld-classic','-dylib','-arch','armv7','-iphoneos_version_min','6.0','-syslibroot',OUT/'sdk','-no_data_const','-segalign','1000','-o',binary,obj,'-framework','Foundation','-lobjc','-lSystem'])
run(['/usr/bin/codesign','--force','--sign','-','--digest-algorithm=sha1','--timestamp=none',binary]);run(['/usr/bin/codesign','--verify',binary])
control=b'Package: ai.whaletech.cophone.notification-route\nName: cophone Notification Route\nVersion: 0.1.3\nArchitecture: iphoneos-arm\nDescription: Route own completion actions directly to the generated note or photo.\nMaintainer: cophone\nSection: Tweaks\nDepends: mobilesubstrate, ai.whaletech.cophone.review (>= 0.4.0-20), firmware (>= 6.0), firmware (<< 7.0)\n'
base='Library/MobileSubstrate/DynamicLibraries/cophone-notification-route'
entries=[(base+'.dylib',binary.read_bytes(),0o755),(base+'.plist',plistlib.dumps({'Filter':{'Bundles':['com.apple.springboard']}}),0o644)]
p=OUT/'cophone-Notification-Route-iOS6-0.1.3.deb';p.write_bytes(b'!<arch>\n'+ar_member('debian-binary',b'2.0\n')+ar_member('control.tar.gz',tar_bytes([('control',control,0o644)]))+ar_member('data.tar.gz',tar_bytes(entries)));print(p)
