#!/usr/bin/env python3
"""One-time USB migration of locally configured keys to cophone's private Library."""
import argparse
import getpass
import json
import os
import re
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from install import ROOT, ssh_with_password


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qwen-file', type=Path)
    args = parser.parse_args()
    config = {'transport': 'phone'}
    fields = ('DEEPSEEK_API_KEY', 'DASHSCOPE_API_KEY', 'DEEPSEEK_MODEL', 'DASHSCOPE_IMAGE_MODEL')
    path = ROOT / '.env'
    if not path.exists():
        raise SystemExit('请在手机 AI 设置中配置，或先在本机配置密钥。')
    for line in path.read_text().splitlines():
        key, sep, value = line.partition('=')
        if sep and key in fields and value.strip():
            value = value.strip()
            if not re.fullmatch(r'[!-~]{10,4096}' if key.endswith('_API_KEY') else r'[A-Za-z0-9_.-]{1,128}', value):
                if key.endswith('_API_KEY'):
                    print(('千问' if key == 'DASHSCOPE_API_KEY' else 'DeepSeek') + ' 本机密钥格式未通过检查，跳过此项并保留手机已有值。')
                    continue
                raise SystemExit('本机模型配置格式不正确，未发送。')
            config[key] = value
    if args.qwen_file:
        if args.qwen_file.stat().st_size > 8192:
            raise SystemExit('密钥文件过大，未发送。')
        value = args.qwen_file.read_text().strip()
        if not re.fullmatch(r'[!-~]{10,4096}', value):
            raise SystemExit('密钥文件中不是完整的单个 Key，未发送；请只粘贴 Key 本身。')
        config['DASHSCOPE_API_KEY'] = value
        args.qwen_file.chmod(0o600)
    if not any(config.get(key) for key in fields[:2]):
        raise SystemExit('未找到本机密钥。')
    password = getpass.getpass('一次性迁移：本机输入 iPhone SSH 密码（不回显、不保存）：')
    remote = "su mobile -c '/usr/libexec/cophone-reviewd --configure-ai'"
    args = ['ssh', '-T', '-p', '2222', '-o', 'ConnectTimeout=8', '-o', 'ServerAliveInterval=3', '-o', 'ServerAliveCountMax=2', '-o', 'NumberOfPasswordPrompts=1', '-o', 'HostKeyAlgorithms=+ssh-rsa', '-o', 'StrictHostKeyChecking=yes', '-o', 'UserKnownHostsFile='+str(ROOT/'artifacts/ios6/known_hosts'), 'root@127.0.0.1', remote]
    read_fd, write_fd = os.pipe()
    try:
        os.write(write_fd, json.dumps(config).encode())
    finally:
        os.close(write_fd)
    config = None
    with os.fdopen(read_fd, 'rb') as source:
        code, transcript = ssh_with_password(args, password, source, timeout=40, emit=True)
    password = None
    if code or 'COPHONE_PHONE_AI_CONFIGURED' not in transcript:
        raise SystemExit('手机私有配置未确认，未提交任何 AI 任务。')
    print('已迁移至手机私有 Library（非 Documents）。日常使用无需 SSH、USB 或 Mac。')


if __name__ == '__main__':
    main()
