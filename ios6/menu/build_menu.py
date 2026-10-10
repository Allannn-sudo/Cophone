#!/usr/bin/env python3
import plistlib
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'review'))
from build import ROOT,OUT,TOOLS,run
from build_service import ar_member,tar_bytes

def main():
    objects=[]
    for source in ['ios6/menu/SelectionMenu.m','ios6/menu/MenuIPC.m']:
        obj=OUT/('menu-'+Path(source).stem+'.o')
        run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',OUT/'sdk','-fobjc-arc','-fblocks','-Os','-Wno-deprecated-declarations','-c',ROOT/source,'-o',obj]);objects.append(obj)
    binary=OUT/'cophone-menu.dylib'
    run([TOOLS/'ld-classic','-dylib','-arch','armv7','-iphoneos_version_min','6.0','-syslibroot',OUT/'sdk','-no_data_const','-segalign','1000','-install_name','/Library/MobileSubstrate/DynamicLibraries/cophone-menu.dylib','-o',binary]+objects+['-framework','Foundation','-framework','UIKit','-framework','AssetsLibrary','-framework','CoreGraphics','-lobjc','-lSystem'])
    run(['/usr/bin/codesign','--force','--sign','-','--digest-algorithm=sha1','--timestamp=none',binary]);run(['/usr/bin/codesign','--verify',binary])
    control=b'Package: ai.whaletech.cophone.menu\nName: cophone Safari Menu\nVersion: 0.1.1\nArchitecture: iphoneos-arm\nDescription: Explicit selected-text AI tasks in Safari. No SpringBoard injection or restart.\nMaintainer: cophone\nSection: Tweaks\nDepends: mobilesubstrate, ai.whaletech.cophone.review (>= 0.4.0-7), firmware (>= 6.0), firmware (<< 7.0)\n'
    entries=[('Library/MobileSubstrate/DynamicLibraries/cophone-menu.dylib',binary.read_bytes(),0o755),('Library/MobileSubstrate/DynamicLibraries/cophone-menu.plist',plistlib.dumps({'Filter':{'Bundles':['com.apple.mobilesafari']}}),0o644)]
    package=OUT/'cophone-Safari-Menu-iOS6-0.1.1.deb'
    package.write_bytes(b'!<arch>\n'+ar_member('debian-binary',b'2.0\n')+ar_member('control.tar.gz',tar_bytes([('control',control,0o644)]))+ar_member('data.tar.gz',tar_bytes(entries)))
    print(package)
if __name__=='__main__':main()
