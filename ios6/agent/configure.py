#!/usr/bin/env python3
"""Keys are entered only into a private local terminal, never chat/argv/history."""
import getpass
import os
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
path = ROOT / '.env'
values = {}
if path.exists():
    for line in path.read_text().splitlines():
        key, sep, value = line.partition('=')
        if sep:
            values[key] = value
print('配置 cophone 国内 AI。输入不会回显；留空保留原值。不要把密钥发进聊天。')
for key, label in [('DEEPSEEK_API_KEY', 'DeepSeek API Key'), ('DASHSCOPE_API_KEY', '阿里云百炼北京地域 API Key')]:
    value = getpass.getpass(label + '：').strip()
    if value:
        if '\n' in value or '\r' in value:
            raise SystemExit('密钥格式不正确')
        values[key] = value
values.setdefault('DEEPSEEK_MODEL', 'deepseek-flash')
values.setdefault('DASHSCOPE_IMAGE_MODEL', 'qwen-image-plus')
values.setdefault('DASHSCOPE_BASE_URL', 'https://dashscope.aliyuncs.com')
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as stream:
    os.chmod(path, 0o600)
    stream.write('\n'.join(k + '=' + v for k, v in values.items()) + '\n')
print('已保存到本机 .env（权限 600，已忽略）。日常双击“启动 cophone AI.command”。')
