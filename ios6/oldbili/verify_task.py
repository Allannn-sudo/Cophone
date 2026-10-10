#!/usr/bin/env python3
"""Read only cophone task metadata from its shared Documents, never AI config."""
import argparse,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'agent'))
from worker import PhoneFiles
p=argparse.ArgumentParser();p.add_argument('--udid',required=True);args=p.parse_args()
f=PhoneFiles(args.udid)
r=f.get('oldbili-request.json') or {};s=f.get('oldbili-state.json') or {}
value={k:s[k] for k in ['id','status','step','trace','error','verified','receipt','recommended','selection','notificationSubmitted'] if k in s}
value['matchesCurrentRequest']=bool(r.get('id') and s.get('id')==r.get('id'))
print(json.dumps(value,ensure_ascii=False,indent=2))
if value.get('verified') and value['matchesCurrentRequest']:
 path=Path(__file__).resolve().parents[2]/'artifacts/ios6/oldbili-task-verification.json';path.write_text(json.dumps(value,ensure_ascii=False,indent=2))
