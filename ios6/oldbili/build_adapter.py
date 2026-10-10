#!/usr/bin/env python3
import sys,plistlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'review'))
from build import ROOT,OUT,TOOLS,run
from build_service import ar_member,tar_bytes
obj=OUT/'oldbili-adapter.o';binary=OUT/'cophone-oldbili-adapter.dylib'
run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',OUT/'sdk','-fobjc-arc','-fblocks','-Os','-c',ROOT/'ios6/oldbili/OldbiliAdapter.m','-o',obj])
run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',OUT/'sdk','-fobjc-arc','-fblocks','-Os','-c',ROOT/'ios6/menu/MenuIPC.m','-o',OUT/'oldbili-adapter-ipc.o'])
run([TOOLS/'ld-classic','-dylib','-arch','armv7','-iphoneos_version_min','6.0','-syslibroot',OUT/'sdk','-no_data_const','-segalign','1000','-o',binary,obj,OUT/'oldbili-adapter-ipc.o','-framework','Foundation','-framework','UIKit','-framework','QuartzCore','-framework','CoreGraphics','-lobjc','-lSystem'])
run(['/usr/bin/codesign','--force','--sign','-','--digest-algorithm=sha1','--timestamp=none',binary]);run(['/usr/bin/codesign','--verify',binary])
control=b'Package: ai.whaletech.cophone.oldbili-adapter\nName: cophone oldbili Adapter\nVersion: 0.2.1\nArchitecture: iphoneos-arm\nDescription: Bounded background semantic search using the actual oldbili controller.\nMaintainer: cophone\nSection: Development\nDepends: mobilesubstrate, firmware (>= 6.0), firmware (<< 7.0)\n'
entries=[('Library/MobileSubstrate/DynamicLibraries/cophone-oldbili-adapter.dylib',binary.read_bytes(),0o755),('Library/MobileSubstrate/DynamicLibraries/cophone-oldbili-adapter.plist',plistlib.dumps({'Filter':{'Bundles':['net.iosipa.oldbili']}}),0o644)]
package=OUT/'cophone-oldbili-adapter-0.2.1.deb'
package.write_bytes(b'!<arch>\n'+ar_member('debian-binary',b'2.0\n')+ar_member('control.tar.gz',tar_bytes([('control',control,0o644)]))+ar_member('data.tar.gz',tar_bytes(entries)))
print(package)
