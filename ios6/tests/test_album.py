#!/usr/bin/env python3
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parents[2]
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
binary = root / 'artifacts/ios6/test-photo-album'
subprocess.run(['xcrun', 'clang', '-isysroot', sdk, '-fobjc-arc', '-fblocks', '-DCOPHONE_ALBUM_TESTING=1', '-I' + str(root / 'ios6/src'), '-I' + str(root / 'ios6/tests'), '-framework', 'Foundation', str(root / 'ios6/src/PhotoAlbum.m'), str(root / 'ios6/tests/test_album.m'), '-o', str(binary)], check=True)
subprocess.run([str(binary)], check=True)
