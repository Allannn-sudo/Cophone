#!/usr/bin/env python3
import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
binary=root/'artifacts/ios6/test-oldbili-policy'
subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-fblocks','-framework','Foundation',str(root/'ios6/oldbili/AgentPolicy.m'),str(root/'ios6/oldbili/test_policy.m'),'-o',str(binary)],check=True)
subprocess.run([str(binary)],check=True)
