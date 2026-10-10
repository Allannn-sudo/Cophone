import subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
binary=root/'artifacts/ios6/test-private-state'
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
sources=['ios6/src/TaskInbox.m','ios6/src/LocalHistory.m','ios6/live/ExecutionState.m','ios6/tests/test_private_state.m']
subprocess.run(['xcrun','clang','-isysroot',sdk,'-fobjc-arc','-fblocks','-framework','Foundation',*[str(root/s) for s in sources],'-o',str(binary)],check=True)
subprocess.run([str(binary)],check=True)
