#!/usr/bin/env python3
"""Check properties required by the legacy dyld; does not claim device execution."""
import plistlib
import struct
import subprocess
import zlib
from pathlib import Path

APP = Path(__file__).resolve().parents[1] / 'artifacts/ios6/CoPhone.app'


def icon_alpha(png):
    """Decode opacity of a small non-interlaced 8-bit RGB/RGBA PNG; read-only."""
    width, height, depth, color, _, _, interlace = struct.unpack_from('>IIBBBBB', png, 16)
    assert depth == 8 and color in (2, 6) and interlace == 0, '图标必须是 RGB/RGBA PNG'
    channels = 4 if color == 6 else 3
    offset, compressed = 8, bytearray()
    while offset < len(png):
        size = struct.unpack_from('>I', png, offset)[0]
        if png[offset + 4:offset + 8] == b'IDAT':
            compressed.extend(png[offset + 8:offset + 8 + size])
        offset += size + 12
    data = zlib.decompress(compressed)
    stride = width * channels
    assert len(data) == height * (stride + 1)
    previous, alpha = bytearray(stride), []
    for y in range(height):
        base = y * (stride + 1)
        kind, row = data[base], bytearray(data[base + 1:base + 1 + stride])
        assert kind <= 4
        for x in range(stride):
            left = row[x - channels] if x >= channels else 0
            up, corner = previous[x], previous[x - channels] if x >= channels else 0
            prediction = left + up - corner
            distances = (abs(prediction - left), abs(prediction - up), abs(prediction - corner))
            paeth = (left, up, corner)[distances.index(min(distances))]
            row[x] = (row[x] + (0, left, up, (left + up) // 2, paeth)[kind]) & 255
        alpha.append(row[3::4] if channels == 4 else bytearray([255] * width))
        previous = row
    return alpha


def main():
    binary = APP / 'CoPhone'
    data = binary.read_bytes()
    magic, cpu, subtype, kind, count, _, _ = struct.unpack_from('<7I', data)
    assert magic == 0xfeedface and cpu == 12 and subtype & 255 == 9, '需要 armv7 Mach-O'
    assert kind == 2, '需要可执行文件'
    offset, commands, libraries = 28, {}, []
    for _ in range(count):
        command, size = struct.unpack_from('<II', data, offset)
        assert size >= 8 and offset + size <= len(data), '无效 load command'
        commands[command] = data[offset:offset + size]
        if command == 12:
            name = struct.unpack_from('<I', data, offset + 8)[0]
            libraries.append(data[offset + name:offset + size].split(b'\0')[0].decode())
        offset += size
    assert 0x25 in commands, '缺少 LC_VERSION_MIN_IPHONEOS'
    assert struct.unpack_from('<I', commands[0x25], 8)[0] == 0x60000, '部署目标不是 iOS 6.0'
    assert 0x80000028 in commands, '缺少 iOS 6 支持的 LC_MAIN'
    assert 0x80000034 not in commands, '旧 dyld 不支持 chained fixups'
    assert 0x1d in commands, '缺少代码签名'
    assert 0x21 in commands and struct.unpack_from('<I', commands[0x21], 16)[0] == 0, '可执行文件不应加密'
    allowed = {'/System/Library/Frameworks/' + framework + '.framework/' + framework
               for framework in ('UIKit', 'Foundation', 'EventKit', 'EventKitUI', 'CoreFoundation', 'AssetsLibrary', 'CoreGraphics', 'QuartzCore', 'AVFoundation', 'CoreTelephony')}
    allowed.update(('/usr/lib/libSystem.B.dylib', '/usr/lib/libobjc.A.dylib'))
    assert set(libraries) <= allowed, '出现意外运行时依赖：' + repr(set(libraries) - allowed)
    with (APP / 'Info.plist').open('rb') as handle:
        info = plistlib.load(handle)
    assert info['MinimumOSVersion'] == '6.0'
    assert info['CFBundleExecutable'] == 'CoPhone'
    assert info['CFBundleIdentifier'] == 'ai.whaletech.cophone.classic'
    assert info['CFBundleDisplayName'] == 'cophone'
    assert info['CFBundleName'] == 'cophone'
    assert info['UIFileSharingEnabled'] is True
    assert set(info['UISupportedInterfaceOrientations']) == {'UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'}
    expected_icons = {'Icon.png': 57, 'Icon@2x.png': 114,
                      'Icon-Small.png': 29, 'Icon-Small@2x.png': 58}
    assert set(info['CFBundleIconFiles']) == set(expected_icons)
    for name, size in expected_icons.items():
        png = (APP / name).read_bytes()
        assert png[:8] == b'\x89PNG\r\n\x1a\n'
        assert struct.unpack_from('>II', png, 16) == (size, size), '图标尺寸错误：' + name
        alpha = icon_alpha(png)
        assert all(value == 255 for row in alpha for value in row), 'IPA 图标必须全不透明，由系统施加圆角，不能复用经典版透明遮罩：' + name
    assert not info.get('UIBackgroundModes'), '不使用伪装后台模式'
    subprocess.run(['/usr/bin/codesign', '--verify', str(APP)], check=True)
    print('通过：armv7 / iOS 6.0 / 旧 dyld 结构 / 系统依赖 / cophone 名称 / 四种不透明 IPA 图标 / ad-hoc 签名。真机运行仍须验证。')


if __name__ == '__main__':
    main()
