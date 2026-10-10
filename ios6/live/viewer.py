#!/usr/bin/env python3
"""Read-only USB viewer of real App frames and phone execution data. No SSH or task control."""
import argparse
import json
import subprocess
import sys
import tempfile
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit, parse_qs
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from monitor import find_tool

BUNDLE = 'ai.whaletech.cophone.classic'
FILES = {'oldbili-state.json', 'agent-frame.json', 'agent-frame.png', 'execution-state.json', 'execution-image.png'}


def valid_frame(meta, task, now):
    return (isinstance(meta, dict) and isinstance(task, dict)
        and meta.get('taskID') == task.get('id') and bool(task.get('id'))
        and meta.get('bundle') == 'net.iosipa.oldbili'
        and meta.get('source') == 'UIView.layer.renderInContext'
        and type(meta.get('detached')) in (bool, int) and meta.get('detached') == 1
        and meta.get('width') == 320 and meta.get('height') == 460
        and isinstance(meta.get('capturedAt'), (int, float))
        and abs(now - meta['capturedAt']) < 5)


def valid_execution(value):
    return (isinstance(value, dict) and value.get('version') == 1
        and value.get('source') == 'phone-execution-data'
        and type(value.get('capturedAt')) in (int, float)
        and isinstance(value.get('tasks'), list) and len(value['tasks']) <= 4
        and all(isinstance(t, dict) and t.get('kind') in ('oldbili', 'summarize', 'illustrate', 'review')
                and isinstance(t.get('id'), str) and t['id'] for t in value['tasks']))


class Reader:
    def __init__(self, udid):
        self.udid = udid
        self.lock = threading.Lock()
        self.stop = threading.Event()
        self.state = dict(connected=False, message='正在连接 iPhone', task={}, frame={})
        self.image = None
        self.prefix = None
        self.generation = None
        self.preview = None
        self.preview_generation = None

    def read(self, name, limit):
        if name not in FILES:
            raise ValueError('不允许读取此文件')
        with tempfile.TemporaryDirectory(prefix='cophone-frame-') as directory:
            dest = Path(directory) / name
            for prefix in ([self.prefix] if self.prefix else ['', '/Documents']):
                remote = prefix + '/' + name
                result = subprocess.run([find_tool('afcclient'), '--udid', self.udid,
                    '--documents', BUNDLE, 'get', remote, str(dest)],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
                if result.returncode == 0 and dest.is_file():
                    self.prefix = prefix
                    if dest.stat().st_size > limit:
                        raise ValueError('导出文件过大')
                    return dest.read_bytes()
            raise OSError('暂未收到本轮导出文件')

    def poll(self):
        while not self.stop.is_set():
            started = time.time()
            try:
                execution = json.loads(self.read('execution-state.json', 512 * 1024))
                if not valid_execution(execution):
                    raise ValueError('执行数据格式错误或来源不匹配')
                try:
                    task = json.loads(self.read('oldbili-state.json', 128 * 1024))
                except (OSError, ValueError, subprocess.SubprocessError):
                    task = {}
                if not isinstance(task, dict):
                    raise ValueError('任务格式错误')
                meta, image = {}, self.image
                try:
                    meta = json.loads(self.read('agent-frame.json', 16 * 1024))
                    generation = (meta.get('taskID'), meta.get('sequence'), meta.get('capturedAt'))
                    if generation != self.generation:
                        raw = self.read('agent-frame.png', 512 * 1024)
                        after = json.loads(self.read('agent-frame.json', 16 * 1024))
                        if after != meta or not raw.startswith(b'\x89PNG\r\n\x1a\n'):
                            raise ValueError('画面正在更新，等待下一帧')
                        image = raw
                        self.generation = generation
                except (OSError, ValueError, subprocess.SubprocessError):
                    meta = {}
                preview_generation = (execution.get('imageTaskID'), execution.get('imageHash'))
                preview = self.preview if preview_generation == self.preview_generation else None
                if all(preview_generation) and preview is None:
                    try:
                        raw = self.read('execution-image.png', 10 * 1024 * 1024)
                        after = json.loads(self.read('execution-state.json', 512 * 1024))
                        if (after.get('imageTaskID'), after.get('imageHash')) != preview_generation or not raw.startswith(b'\x89PNG\r\n\x1a\n'):
                            raise ValueError('图片正在更新')
                        import hashlib
                        if hashlib.sha256(raw).hexdigest() != preview_generation[1]:
                            raise ValueError('预览图片与任务结果不匹配')
                        preview = raw
                    except (OSError, ValueError, subprocess.SubprocessError):
                        pass
                current = bool(image) and valid_frame(meta, task, time.time())
                state = dict(connected=True, checkedAt=time.time(), task=task, frame=meta,
                    execution=execution, dataLive=abs(time.time()-execution['capturedAt']) < 6,
                    previewTaskID=preview_generation[0] if preview else None, previewHash=preview_generation[1] if preview else None,
                    live=current, hasImage=bool(image), generation=str(self.generation),
                    message='正在显示真实后台控制器画面' if current else '尚无本轮实时画面；旧帧不会标为实时')
                with self.lock:
                    self.state, self.image = state, image
                    self.preview, self.preview_generation = preview, preview_generation
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                with self.lock:
                    self.state = dict(self.state, connected=False, live=False, dataLive=False,
                        checkedAt=time.time(), message='USB 未连接或还没有任务：' + str(error))
            self.stop.wait(max(0.2, 1 - (time.time() - started)))


def handler(reader):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.headers.get('Host') not in (f'127.0.0.1:{self.server.server_port}', f'localhost:{self.server.server_port}'):
                self.send_error(403); return
            parsed = urlsplit(self.path)
            path = parsed.path
            requested = parse_qs(parsed.query).get('v', [None])[0]
            with reader.lock:
                if path == '/api/state':
                    body, content = json.dumps(reader.state, ensure_ascii=False).encode(), 'application/json; charset=utf-8'
                elif path == '/preview.png' and reader.preview:
                    if requested != reader.state.get('previewHash'):
                        self.send_error(409); return
                    body, content = reader.preview, 'image/png'
                elif path == '/frame.png' and reader.image:
                    body, content = reader.image, 'image/png'
                elif path == '/':
                    body, content = Path(__file__).with_name('viewer.html').read_bytes(), 'text/html; charset=utf-8'
                else:
                    self.send_error(404); return
            self.send_response(200)
            self.send_header('Content-Type', content)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self'; connect-src 'self'")
            self.end_headers(); self.wfile.write(body)
        def log_message(self, *_): pass
    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--udid')
    parser.add_argument('--port', type=int, default=18770)
    parser.add_argument('--no-open', action='store_true')
    args = parser.parse_args()
    reader, server = None, None
    try:
        ids = subprocess.check_output([find_tool('idevice_id'), '-l'], text=True).split()
        if args.udid and args.udid in ids: udid = args.udid
        elif not args.udid and len(ids) == 1: udid = ids[0]
        else: raise RuntimeError('请只连接一台 iPhone，或用 --udid 指定设备')
        reader = Reader(udid)
        server = ThreadingHTTPServer(('127.0.0.1', args.port), handler(reader))
        thread = threading.Thread(target=reader.poll, daemon=True); thread.start()
        url = f'http://127.0.0.1:{args.port}/'
        print('cophone 实际执行画面：' + url, flush=True)
        print('电脑仅通过 USB 读取真实 App 画面、执行数据和结果预览，不读取 API Key、不运行 AI、不控制手机。按 Control+C 停止。', flush=True)
        if not args.no_open:
            # Use macOS default browser, independent of Codex panels.
            subprocess.run(['/usr/bin/open', url], check=False)
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt: pass
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print('无法启动：' + str(error)); return 1
    finally:
        if reader: reader.stop.set()
        if server: server.server_close()
    return 0

if __name__ == '__main__': raise SystemExit(main())
