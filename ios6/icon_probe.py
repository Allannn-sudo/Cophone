#!/usr/bin/env python3
"""Read only CoPhone's icon as currently returned by SpringBoard over USB."""
import argparse
import ctypes as C
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--udid', required=True)
    parser.add_argument('--bundle', choices=['ai.whaletech.cophone.classic', 'ai.whaletech.cophone.legacy'],
                        default='ai.whaletech.cophone.classic')
    parser.add_argument('--output', type=Path,
                        default=ROOT / 'artifacts/ios6/springboard-icon.png')
    args = parser.parse_args()
    lib = C.CDLL('/opt/homebrew/opt/libimobiledevice/lib/libimobiledevice-1.0.dylib')
    device, client, data, size = C.c_void_p(), C.c_void_p(), C.c_void_p(), C.c_uint64()
    lib.idevice_new.argtypes = [C.POINTER(C.c_void_p), C.c_char_p]
    lib.idevice_free.argtypes = [C.c_void_p]
    lib.sbservices_client_start_service.argtypes = [C.c_void_p, C.POINTER(C.c_void_p), C.c_char_p]
    lib.sbservices_client_free.argtypes = [C.c_void_p]
    lib.sbservices_get_icon_pngdata.argtypes = [C.c_void_p, C.c_char_p,
                                               C.POINTER(C.c_void_p), C.POINTER(C.c_uint64)]
    libc = C.CDLL(None)
    libc.free.argtypes = [C.c_void_p]
    libc.free.restype = None

    def check(code, action):
        if code:
            raise SystemExit(action + '失败，错误码 ' + str(code))

    try:
        check(lib.idevice_new(C.byref(device), args.udid.encode()), 'USB 连接')
        check(lib.sbservices_client_start_service(device, C.byref(client), b'CoPhoneIconProbe'),
              'SpringBoard 图标服务')
        check(lib.sbservices_get_icon_pngdata(client, args.bundle.encode(),
                                              C.byref(data), C.byref(size)), '读取 CoPhone 图标')
        if not data.value or not 8 <= size.value <= 10 * 1024 * 1024:
            raise SystemExit('图标数据长度异常')
        png = C.string_at(data, size.value)
        if not png.startswith(b'\x89PNG\r\n\x1a\n'):
            raise SystemExit('图标不是 PNG')
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_bytes(png)
        print('已只读获取 CoPhone 的 SpringBoard 图标：', args.output)
    finally:
        if data.value:
            libc.free(data)
        if client.value:
            lib.sbservices_client_free(client)
        if device.value:
            lib.idevice_free(device)


if __name__ == '__main__':
    main()
