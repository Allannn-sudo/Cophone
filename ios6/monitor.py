#!/usr/bin/env python3
"""USB read-only observer. It never starts tasks, injects input, or uses SSH."""
import argparse
import json
import os
import io
import tempfile
import shutil
import subprocess
import threading
import time
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class PhoneSnapshot:
    def __init__(self, url, opener=None, clock=time.time):
        self.url = url
        self.opener = opener or urllib.request.build_opener(urllib.request.ProxyHandler({})).open
        self.last_heartbeat = None
        self.heartbeat_changed_at = None
        self.clock = clock
        self.state = None
        self.received_at = None
        self.lock = threading.Lock()

    def read(self):
        with self.lock:
            try:
                with self.opener(self.url, timeout=1) as response:
                    raw = response.read(1024 * 1024 + 1)
                if len(raw) > 1024 * 1024:
                    raise ValueError('手机响应过大')
                state = json.loads(raw)
                if not isinstance(state, dict) or state.get('version') != '0.4.0' or state.get('service') != 'CoPhoneReviewService':
                    raise ValueError('请安装 cophone 0.4.0 及配套后台服务')
                if state.get('status') not in ('idle', 'awaiting_leave', 'recording', 'finishing', 'completed', 'failed', 'paused', 'cancelled'):
                    raise ValueError('手机状态格式无效')
                if any(not isinstance(state.get(key, []), list) for key in ('visits', 'pages', 'logs')):
                    raise ValueError('手机日志格式无效')
                if state['status'] == 'completed' and state.get('receipt', {}).get('verified') is not True:
                    raise ValueError('完成状态缺少备忘录回读确认')
                heartbeat = state.get('heartbeat')
                if not isinstance(heartbeat, (int, float)):
                    raise ValueError('后台服务心跳缺失')
                if heartbeat != self.last_heartbeat:
                    self.last_heartbeat, self.heartbeat_changed_at = heartbeat, self.clock()
                if self.clock() - self.heartbeat_changed_at > 8:
                    raise ValueError('USB 可读，但后台服务心跳未更新；当前显示最后快照')
                self.state, self.received_at = state, self.clock()
                connected, message = True, '已通过 USB 读取后台服务状态'
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                connected = False
                message = '未能读取 CoPhone 文件共享：请检查 USB 及 IPA / 后台服务安装。'
                if isinstance(error, ValueError):
                    message = str(error)
            return dict(connected=connected, state=self.state,
                        receivedAt=self.received_at, checkedAt=self.clock(), message=message)


def handler_for(snapshot):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            # Loopback only, plus Host validation against DNS rebinding.
            if self.headers.get('Host') not in (f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'):
                self.send_error(403)
                return
            if self.path == '/api/state':
                data = json.dumps(snapshot.read(), ensure_ascii=False).encode()
                content = 'application/json; charset=utf-8'
            elif self.path in ('/', '/index.html'):
                data = (ROOT / 'ios6/observer.html').read_bytes()
                content = 'text/html; charset=utf-8'
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', content)
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *_):
            pass
    return Handler


def find_tool(name):
    path = shutil.which(name)
    if not path:
        candidate = Path('/opt/homebrew/bin') / name
        if candidate.exists():
            path = str(candidate)
    if not path:
        raise RuntimeError(f'缺少 {name}，请先运行 brew install libimobiledevice libusbmuxd')
    return path


def usb_opener(udid):
    def read(_url, timeout):
        # Only the consenting CoPhone app's exported Documents file is requested.
        with tempfile.TemporaryDirectory(prefix='cophone-read-') as directory:
            target = Path(directory) / 'state.json'
            # iOS 6 HouseArrest may expose the app container even for VendDocuments.
            # Both candidates refer to the same consenting app's own state file.
            for remote in ('/review-state.json', '/Documents/review-state.json'):
                target.unlink(missing_ok=True)
                result = subprocess.run([find_tool('afcclient'), '--udid', udid,
                    '--documents', 'ai.whaletech.cophone.classic', 'get', remote, str(target)],
                    stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=3)
                if result.returncode == 0 and target.is_file():
                    break
            if result.returncode or not target.is_file():
                raise OSError('CoPhone 文件共享不可用')
            if target.stat().st_size > 1024 * 1024:
                raise ValueError('手机状态文件过大')
            return io.BytesIO(target.read_bytes())
    return read


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--udid', default=os.environ.get('COPHONE_IOS_UDID'))
    parser.add_argument('--port', type=int, default=18767)
    parser.add_argument('--no-open', action='store_true')
    args = parser.parse_args()
    server = None
    try:
        ids = subprocess.check_output([find_tool('idevice_id'), '-l'], text=True).split()
        if args.udid:
            if args.udid not in ids:
                raise RuntimeError('指定 iPhone 未通过 USB 连接')
            udid = args.udid
        elif len(ids) == 1:
            udid = ids[0]
        else:
            raise RuntimeError('请只连接一台 iPhone，或通过 COPHONE_IOS_UDID 指定设备')
        snapshot = PhoneSnapshot('afc://CoPhone/review-state.json', usb_opener(udid))
        server = ThreadingHTTPServer(('127.0.0.1', args.port), handler_for(snapshot))
        server.daemon_threads = True
        url = f'http://127.0.0.1:{args.port}/'
        print(f'CoPhone 使用回顾 · 只读观察窗口\n{url}\n', flush=True)
        print('手机点开始，等待确认后按 Home，正常使用 Safari / oldbili；\n回桌面停留 6 秒，自动写入系统备忘录并通知。\n电脑只读取 CoPhone 文件共享，无 SSH 密码、无手机网络端口。\n关闭时按 Control+C。', flush=True)
        if not args.no_open:
            webbrowser.open(url)
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        print('\n观察已停止。')
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f'无法启动：{error}')
        return 1
    finally:
        if server:
            server.server_close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
