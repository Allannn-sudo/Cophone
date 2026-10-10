#!/usr/bin/env python3
import subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
binary=ROOT/'artifacts/ios6/test-review-session'
subprocess.run(['/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang','-isysroot',sdk,'-fobjc-arc','-fblocks','-framework','Foundation',str(ROOT/'ios6/review/ReviewSession.m'),str(ROOT/'ios6/review/ContentReader.m'),str(ROOT/'ios6/review/test_session.m'),'-lsqlite3','-lz','-o',str(binary)],check=True)
subprocess.run([str(binary)],check=True)

phone=ROOT/'artifacts/ios6/test-phone-ai'
subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-fblocks','-Wno-deprecated-declarations','-framework','Foundation',str(ROOT/'ios6/review/PhoneAI.m'),str(ROOT/'ios6/review/test_phone_ai.m'),'-o',str(phone)],check=True)
subprocess.run([str(phone)],check=True)
