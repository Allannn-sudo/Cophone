#!/usr/bin/env python3
import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
binary=root/'artifacts/ios6/test-task-inbox'
subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-fblocks','-I'+str(root/'ios6/src'),'-framework','Foundation',str(root/'ios6/src/TaskInbox.m'),str(root/'ios6/tests/test_inbox.m'),'-o',str(binary)],check=True)
subprocess.run([str(binary)],check=True)
