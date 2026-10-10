#!/usr/bin/env python3
"""Read only our probe's public runtime interface metadata over USB SSH."""
import getpass,json,sys,subprocess,argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from install import ROOT,ssh_with_password
parser=argparse.ArgumentParser();parser.add_argument('--adapter',action='store_true');args=parser.parse_args()
mode='--adapter' if args.adapter else '--runtime'
out=ROOT/'artifacts/ios6';binary=out/'cophone-oldbili-inspect'
crc,size,*_=subprocess.check_output(['cksum',str(binary)],text=True).split()
command=f'''set -e; d=$(mktemp -d /var/tmp/cophone-oldbili-read.XXXXXX); trap 'rm -rf "$d"' EXIT; cat > "$d/inspect"; set -- $(cksum "$d/inspect"); test "$1" = {crc}; test "$2" = {size}; chmod 755 "$d" "$d/inspect"; su mobile -c "$d/inspect {mode}"'''
ssh=['ssh','-T','-p','2222','-o','ConnectTimeout=8','-o','ServerAliveInterval=3','-o','ServerAliveCountMax=2','-o','NumberOfPasswordPrompts=1','-o','HostKeyAlgorithms=+ssh-rsa','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(out/'known_hosts'),'root@127.0.0.1',command]
password=getpass.getpass('本机诊断密码（输入不回显，不保存）：')
with binary.open('rb') as source:code,transcript=ssh_with_password(ssh,password,source,timeout=40,emit=False)
password=None
if code:raise SystemExit('接口检查连接未成功：'+str(code))
values=[]
for line in transcript.splitlines():
 if line.startswith('{'):
  v=json.loads(line)
  if not args.adapter:assert set(v)=={'bundle','version','active','roots','classes'}
  assert v['bundle'] in ['net.iosipa.oldbili','com.aramco.cycomm']
  values.append(v)
path=out/('oldbili-adapter-observation.json' if args.adapter else 'oldbili-runtime-interfaces.json');path.write_text(json.dumps(values,ensure_ascii=False,indent=2));path.chmod(0o600)
for v in values:
 if args.adapter:print(json.dumps(v,ensure_ascii=False));continue
 print(json.dumps({k:v[k] for k in ['bundle','version','active','roots']},ensure_ascii=False))
 for c in v['classes']:
  if c['class'] in ['SearchViewController','WbiSign','AppDelegate','BiliAPIClient','BiliSearchResultsViewController']:
   print(json.dumps(c,ensure_ascii=False))
print('Metadata saved:',path,'apps:',len(values))
