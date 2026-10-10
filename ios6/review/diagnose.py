#!/usr/bin/env python3
"""Temporary device probe: obtain the password locally before starting SSH."""
import argparse
import getpass
import subprocess
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from install import ssh_with_password, ROOT
p=argparse.ArgumentParser();p.add_argument('--upload',type=Path);p.add_argument('--output',type=Path);p.add_argument('command');args=p.parse_args()
password=getpass.getpass('本机诊断密码（输入不回显，不保存）：')
ssh=['ssh','-T','-p','2222','-o','ConnectTimeout=8','-o','ServerAliveInterval=3','-o','ServerAliveCountMax=2','-o','NumberOfPasswordPrompts=1','-o','HostKeyAlgorithms=+ssh-rsa','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(ROOT/'artifacts/ios6/known_hosts'),'root@127.0.0.1',args.command]
with args.upload.open('rb') if args.upload else open('/dev/null','rb') as source:
 code,transcript=ssh_with_password(ssh,password,source,timeout=45,emit=args.output is None)
password=None
if args.output:
 args.output.write_text(transcript)
 args.output.chmod(0o600)
 print('诊断输出已保存：',args.output)
raise SystemExit(code)
