#!/usr/bin/env python3
import io
import os
import plistlib
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build import ROOT,OUT,TOOLS,run


def compile_binary(name,sources,frameworks,entitlements=None):
    objects=[]
    for source in sources:
        obj=OUT/(name+'-'+Path(source).stem+'.o')
        run([TOOLS/'clang','-target','armv7-apple-ios6.0','-isysroot',OUT/'sdk','-fobjc-arc','-fblocks','-Os','-Wno-deprecated-declarations','-c',ROOT/source,'-o',obj]);objects.append(obj)
    args=[TOOLS/'ld-classic','-arch','armv7','-iphoneos_version_min','6.0','-syslibroot',OUT/'sdk','-no_data_const','-segalign','1000','-o',OUT/name]+objects
    for framework in frameworks:args+=['-framework',framework]
    run(args+['-lsqlite3','-lz','-lobjc','-lSystem'])
    signing=['/usr/bin/codesign','--force','--sign','-','--digest-algorithm=sha1','--timestamp=none']
    if entitlements:signing+=['--entitlements',ROOT/entitlements]
    run(signing+[OUT/name])
    run(['/usr/bin/codesign','--verify',OUT/name])
    return OUT/name


def ar_member(name,data):
    header=f'{name+"/":<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(data):<10}`\n'.encode('ascii')
    assert len(header)==60
    return header+data+(b'\n' if len(data)%2 else b'')


def tar_bytes(entries):
    output=io.BytesIO()
    with tarfile.open(fileobj=output,mode='w:gz',format=tarfile.USTAR_FORMAT) as tar:
        for name,data,mode in entries:
            entry=tarfile.TarInfo(name);entry.size=len(data);entry.mode=mode;entry.uid=entry.gid=0;entry.uname='root';entry.gname='wheel'
            tar.addfile(entry,io.BytesIO(data))
    return output.getvalue()


def main():
    daemon=compile_binary('cophone-reviewd',['ios6/review/daemon.m','ios6/review/ReviewSession.m','ios6/review/ContentReader.m','ios6/review/NotesWriter.m','ios6/results/ResultBadge.m','ios6/review/PhoneAI.m','ios6/src/TaskInbox.m','ios6/src/LocalHistory.m','ios6/live/ExecutionState.m','ios6/menu/MenuIPC.m','ios6/oldbili/OldbiliAgent.m','ios6/oldbili/AgentPolicy.m','ios6/oldbili/BackgroundLease.m','ios6/voice/VoiceWorker.m','ios6/voice/VoiceProtocol.m'],['Foundation','UIKit','CoreData','CFNetwork'],'ios6/review/service-entitlements.plist')
    label='ai.whaletech.cophone.review'
    launch=plistlib.dumps(dict(Label=label,ProgramArguments=['/usr/libexec/cophone-reviewd'],UserName='mobile',WorkingDirectory='/var/mobile',RunAtLoad=True,KeepAlive=True,ThrottleInterval=10))
    control=('Package: ai.whaletech.cophone.review\nName: CoPhone Review Service\nVersion: 0.4.0-24\nArchitecture: iphoneos-arm\nDescription: Opt-in usage recap and phone-native AI tasks. No SpringBoard injection.\nMaintainer: cophone\nSection: Utilities\nDepends: firmware (>= 6.0), firmware (<< 7.0)\n').encode()
    postinst=b'#!/bin/sh\nset -e\nmkdir -p /var/mobile/Library/CoPhoneReview\nchown mobile:mobile /var/mobile/Library/CoPhoneReview\nchmod 700 /var/mobile/Library/CoPhoneReview\nlaunchctl unload /Library/LaunchDaemons/ai.whaletech.cophone.review.plist 2>/dev/null || true\nlaunchctl load /Library/LaunchDaemons/ai.whaletech.cophone.review.plist\n'
    prerm=b'#!/bin/sh\nlaunchctl unload /Library/LaunchDaemons/ai.whaletech.cophone.review.plist 2>/dev/null || true\nexit 0\n'
    package=OUT/'CoPhone-Review-Service-iOS6-0.4.0.deb'
    package.write_bytes(b'!<arch>\n'+ar_member('debian-binary',b'2.0\n')+ar_member('control.tar.gz',tar_bytes([('control',control,0o644),('postinst',postinst,0o755),('prerm',prerm,0o755)]))+ar_member('data.tar.gz',tar_bytes([('usr/libexec/cophone-reviewd',daemon.read_bytes(),0o755),('Library/LaunchDaemons/'+label+'.plist',launch,0o644)])))
    print('后台服务 DEB：',package)

if __name__=='__main__':main()
