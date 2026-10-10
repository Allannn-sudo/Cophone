import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
binary=root/'artifacts/ios6/test-notification-route'
subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-framework','Foundation',str(root/'ios6/notifications/test_policy.m'),'-o',str(binary)],check=True)
subprocess.run([str(binary)],check=True)
