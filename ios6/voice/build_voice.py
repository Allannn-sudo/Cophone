#!/usr/bin/env python3
import sys,plistlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'review'))
from build import ROOT,OUT,TOOLS,run
from build_service import ar_member,tar_bytes
objects=[]
for source in ['ios6/voice/HomeVoice.m','ios6/voice/VoiceProtocol.m','ios6/menu/MenuIPC.m','ios6/src/TaskInbox.m']:
 obj=OUT/('voice-'+Path(source).stem+'.o');run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',OUT/'sdk','-fobjc-arc','-fblocks','-Os','-Wno-deprecated-declarations','-c',ROOT/source,'-o',obj]);objects.append(obj)
binary=OUT/'cophone-voice.dylib'
run([TOOLS/'ld-classic','-dylib','-arch','armv7','-iphoneos_version_min','6.0','-syslibroot',OUT/'sdk','-no_data_const','-segalign','1000','-o',binary]+objects+['-framework','UIKit','-framework','Foundation','-framework','AVFoundation','-framework','CoreTelephony','-lobjc','-lSystem'])
run(['/usr/bin/codesign','--force','--sign','-','--digest-algorithm=sha1','--timestamp=none',binary]);run(['/usr/bin/codesign','--verify',binary])
control=b'Package: ai.whaletech.cophone.voice\nName: cophone Voice\nVersion: 0.1.3\nArchitecture: iphoneos-arm\nDescription: Opt-in Home-held voice tasks with asynchronous availability checks.\nMaintainer: cophone\nSection: Tweaks\nDepends: mobilesubstrate, ai.whaletech.cophone.review (>= 0.4.0-14), firmware (>= 6.0), firmware (<< 7.0)\n'
entries=[('Library/MobileSubstrate/DynamicLibraries/cophone-voice.dylib',binary.read_bytes(),0o755),('Library/MobileSubstrate/DynamicLibraries/cophone-voice.plist',plistlib.dumps({'Filter':{'Bundles':['com.apple.springboard']}}),0o644)]
p=OUT/'cophone-Voice-iOS6-0.1.3.deb';p.write_bytes(b'!<arch>\n'+ar_member('debian-binary',b'2.0\n')+ar_member('control.tar.gz',tar_bytes([('control',control,0o644)]))+ar_member('data.tar.gz',tar_bytes(entries)));print(p)
