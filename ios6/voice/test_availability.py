#!/usr/bin/env python3
"""Regression for the SpringBoard self-RPC freeze and stale worker snapshots."""
import re
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[2]
source = (root / 'ios6/voice/HomeVoice.m').read_text()
available = re.search(r'- \(BOOL\)available\s*\{([^{}]*)\}', source).group(1)
assert 'CophoneVoiceSnapshotReady(' in available
assert all(word not in available for word in ['unlocked()', 'currentCalls', 'CophoneMenuRequest', 'dispatch_sync', 'dlsym'])
lock_query = source[source.index('static BOOL unlocked(void)'):source.index('@interface CophoneHomeVoice')]
assert lock_query.index('if(NSThread.isMainThread)return NO;') < lock_query.index('get(port(),')
assert source.count('screenUnlocked=unlocked();') == 1
sampling = source[source.index('if(!self.checking)'):source.index('BOOL active=[self available]')]
assert sampling.index('dispatch_async(dispatch_get_global_queue') < sampling.index('screenUnlocked=unlocked();') < sampling.index('dispatch_async(dispatch_get_main_queue')
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
binary = root / 'artifacts/ios6/test-voice-availability'
subprocess.run(['xcrun', 'clang', '-isysroot', sdk, '-fobjc-arc', '-framework', 'Foundation',
                str(root / 'ios6/voice/test_availability.m'), '-o', str(binary)], check=True)
subprocess.run([str(binary)], check=True)
print('PASS main-thread availability reads snapshot only; SBS sampling is async with a main-thread refusal guard')
