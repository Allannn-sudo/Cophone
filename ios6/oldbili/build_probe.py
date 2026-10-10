#!/usr/bin/env python3
import sys,plistlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'review'))
from build import ROOT,OUT,TOOLS,run
from build_service import ar_member,tar_bytes
obj=OUT/'oldbili-runtime-probe.o';binary=OUT/'cophone-oldbili-probe.dylib'
run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',OUT/'sdk','-fobjc-arc','-fblocks','-Os','-c',ROOT/'ios6/oldbili/RuntimeProbe.m','-o',obj])
run([TOOLS/'ld-classic','-dylib','-arch','armv7','-iphoneos_version_min','6.0','-syslibroot',OUT/'sdk','-no_data_const','-segalign','1000','-o',binary,obj,'-framework','Foundation','-framework','UIKit','-lobjc','-lSystem'])
run(['/usr/bin/codesign','--force','--sign','-','--digest-algorithm=sha1','--timestamp=none',binary]);run(['/usr/bin/codesign','--verify',binary])
control=b'Package: ai.whaletech.cophone.oldbili-probe\nName: cophone oldbili Interface Probe\nVersion: 0.1.0\nArchitecture: iphoneos-arm\nDescription: Temporary read-only interface metadata probe. No user data or UI actions.\nMaintainer: cophone\nSection: Development\nDepends: mobilesubstrate, firmware (>= 6.0), firmware (<< 7.0)\n'
entries=[('Library/MobileSubstrate/DynamicLibraries/cophone-oldbili-probe.dylib',binary.read_bytes(),0o755),('Library/MobileSubstrate/DynamicLibraries/cophone-oldbili-probe.plist',plistlib.dumps({'Filter':{'Bundles':['net.iosipa.oldbili','com.aramco.cycomm']}}),0o644)]
package=OUT/'cophone-oldbili-probe-0.1.0.deb'
package.write_bytes(b'!<arch>\n'+ar_member('debian-binary',b'2.0\n')+ar_member('control.tar.gz',tar_bytes([('control',control,0o644)]))+ar_member('data.tar.gz',tar_bytes(entries)))
print(package)
