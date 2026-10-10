#!/usr/bin/env python3
"""Build an optional target-specific icon refresh tool for a jailbroken iOS 6."""
from build import OUT, ROOT, TOOLS, run

sdk = OUT / 'sdk'
if not sdk.is_dir():
    raise SystemExit('请先 python3 ios6/build.py')
obj, binary = OUT / 'icon-refresh.o', OUT / 'cophone-icon-refresh'
run([TOOLS / 'clang', '-target', 'armv7-apple-ios6.0', '-isysroot', sdk,
     '-fobjc-arc', '-Os', '-c', ROOT / 'ios6/src/icon_refresh.m', '-o', obj])
run([TOOLS / 'ld-classic', '-arch', 'armv7', '-iphoneos_version_min', '6.0',
     '-syslibroot', sdk, '-no_data_const', '-segalign', '1000', '-o', binary,
     obj, '-framework', 'Foundation', '-framework', 'UIKit',
     '-framework', 'MobileCoreServices', '-lobjc', '-lSystem'])
run(['/usr/bin/codesign', '--force', '--sign', '-', '--digest-algorithm=sha1',
     '--timestamp=none', binary])
run(['/usr/bin/codesign', '--verify', binary])
print(binary)
