#!/usr/bin/env python3
import argparse
import os
import plistlib
import re
import shutil
import subprocess
import zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SDK=Path(os.environ.get('IOS_LEGACY_SDK',str(ROOT/'vendor/ios-sdks/iPhoneOS9.3.sdk')))
TOOLS=Path('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin')
OUT=ROOT/'artifacts/ios6'
APP=OUT/'CoPhone.app'

def run(args):subprocess.run([str(a) for a in args],check=True)

def linking_sdk(source):
    # Theos combines device/simulator archs in v1 TAPI stubs. Modern ld-classic
    # misclassifies those stubs, so select the real armv7 slices in a local copy.
    # Headers and upstream SDK remain unchanged. No runtime dylib is generated.
    target=OUT/'sdk'
    if source.resolve()==target.resolve():raise SystemExit('IOS_LEGACY_SDK 不能指向生成的 sdk 目录')
    if target.exists():shutil.rmtree(target)
    shutil.copytree(source,target,symlinks=True)
    for path in target.rglob('*.tbd'):
        if path.is_symlink():continue
        text=path.read_text()
        def armv7(match):
            archs=[item.strip() for item in match.group(2).split(',')]
            return match.group(1)+'[ armv7 ]' if 'armv7' in archs else match.group(0)
        text=re.sub(r'(archs:\s*)\[([^\]]*)\]',armv7,text)
        # This SDK declares an absent liblaunch re-export. None of this app's
        # imports use it; retain strict undefined-symbol checking for all imports.
        if path.relative_to(target).as_posix() in ('usr/lib/libSystem.tbd','usr/lib/libSystem.B.tbd'):
            text=text.replace('/usr/lib/system/liblaunch.dylib,','')
        path.write_text(text)
    return target

def main():
    parser=argparse.ArgumentParser();parser.add_argument("--edition",choices=["personal","shipping"],default="shipping");args=parser.parse_args()
    if not (SDK/'usr/lib/libSystem.tbd').exists():raise SystemExit('缺少 armv7 SDK：设置 IOS_LEGACY_SDK，详见 ios6/README.md')
    APP.mkdir(parents=True,exist_ok=True)
    sdk=linking_sdk(SDK)
    obj=OUT/'main.o'
    agent=OUT/'agent-tasks.o'
    album=OUT/'photo-album.o'
    inbox=OUT/'task-inbox.o'
    run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',sdk,'-fobjc-arc','-fblocks','-Os','-c',ROOT/'ios6/src/TaskInbox.m','-o',inbox])
    run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',sdk,'-fobjc-arc','-fblocks','-Os','-Wno-deprecated-declarations','-c',ROOT/'ios6/src/PhotoAlbum.m','-o',album])
    run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',sdk,'-fobjc-arc','-fblocks','-Os','-Wno-deprecated-declarations','-c',ROOT/'ios6/src/AgentTasks.m','-o',agent])
    run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',sdk,'-fobjc-arc','-fblocks','-Os','-Wno-deprecated-declarations','-c',ROOT/'ios6/src/main.m','-o',obj])
    local=OUT/'local-history.o'
    run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',sdk,'-fobjc-arc','-fblocks','-Os','-c',ROOT/'ios6/src/LocalHistory.m','-o',local])
    voiceObjects=[]
    for voiceSource in ['ios6/voice/HomeVoice.m','ios6/voice/VoiceProtocol.m','ios6/menu/MenuIPC.m']:
        voiceObject=OUT/('app-voice-'+Path(voiceSource).stem+'.o');run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',sdk,'-fobjc-arc','-fblocks','-Os','-Wno-deprecated-declarations','-c',ROOT/voiceSource,'-o',voiceObject]);voiceObjects.append(voiceObject)
    run([TOOLS/'ld-classic','-arch','armv7','-iphoneos_version_min','6.0','-syslibroot',sdk,'-no_data_const','-segalign','1000','-o',APP/'CoPhone',obj,agent,album,inbox,local]+voiceObjects+['-framework','AVFoundation','-framework','CoreTelephony','-framework','QuartzCore','-framework','AssetsLibrary','-framework','CoreGraphics','-framework','UIKit','-framework','Foundation','-lobjc','-lSystem'])
    icon_sizes={'Icon.png':57,'Icon@2x.png':114,'Icon-Small.png':29,'Icon-Small@2x.png':58}
    icons=list(icon_sizes)
    # User-installed IPA icons are masked by SpringBoard. The transparent,
    # pre-rounded assets were for the retired /Applications system App only;
    # reusing them exposes the system's dark backing around mismatched corners.
    for icon,size in icon_sizes.items():
        run(['/usr/bin/sips','-z',size,size,ROOT/'ios6/assets/icon-master.png','--out',APP/icon])
    info=dict(CFBundleIdentifier='ai.whaletech.cophone.classic',CFBundleExecutable='CoPhone',CFBundleName='cophone',CFBundleDisplayName='cophone',CFBundlePackageType='APPL',CFBundleVersion='22' if args.edition=='personal' else '23',CFBundleShortVersionString='0.10.0',CophoneRequireManualAPI=args.edition=='shipping',NSMicrophoneUsageDescription='仅在你主动说话时录音，用于识别并确认任务。',NSPhotoLibraryUsageDescription='保存你主动生成的配图到 cophone 相簿，并回读确认结果。',MinimumOSVersion='6.0',CFBundleInfoDictionaryVersion='6.0',CFBundleSupportedPlatforms=['iPhoneOS'],UIDeviceFamily=[1],UIRequiredDeviceCapabilities=['armv7'],LSRequiresIPhoneOS=True,UIFileSharingEnabled=True,UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],CFBundleIconFile='Icon.png',CFBundleIconFiles=icons,UIPrerenderedIcon=True,CFBundleIcons={'CFBundlePrimaryIcon':{'CFBundleIconFiles':['Icon','Icon-Small'],'UIPrerenderedIcon':True}})
    (APP/'Info.plist').write_bytes(plistlib.dumps(info))
    # SHA-1 is required for pre-iOS-11 devices; ad-hoc signing needs jailbreak.
    run(['/usr/bin/codesign','--force','--sign','-','--digest-algorithm=sha1','--timestamp=none',APP])
    run(['/usr/bin/codesign','--verify',APP])
    run(['/usr/bin/file',APP/'CoPhone'])
    ipa=OUT/'cophone-iOS6.ipa'
    with zipfile.ZipFile(ipa,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for path in APP.rglob('*'):
            if path.is_file():z.write(path,Path('Payload/CoPhone.app')/path.relative_to(APP))
    versioned=OUT/('cophone-iOS6-0.10.0.ipa' if args.edition=='personal' else 'cophone-iOS6-0.10.0-shipping.ipa')
    shutil.copy2(ipa,versioned)
    print('构建完成：',versioned)
if __name__=='__main__':main()
