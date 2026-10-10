"""Annotate local, read-only system disassembly with selector/import references."""
import re,struct,subprocess,sys
from pathlib import Path
p=Path(sys.argv[1]);lo,hi=(int(v,16) for v in sys.argv[2:4]);b=p.read_bytes();off=28;segments=[]
for _ in range(struct.unpack_from('<I',b,16)[0]):
 cmd,size=struct.unpack_from('<II',b,off)
 if cmd==1:
  vm,vs,file,fs=struct.unpack_from('<IIII',b,off+24);segments.append((vm,fs,file))
 off+=size

def at(addr):
 for vm,size,file in segments:
  if vm<=addr<vm+size:return file+addr-vm
 return -1

def word(addr):
 o=at(addr);return struct.unpack_from('<I',b,o)[0] if o>=0 and o+4<=len(b) else 0

def string(addr):
 o=at(addr)
 if o<0:return ''
 v=b[o:b.find(b'\0',o)]
 if len(v)>220:return ''
 try:return v.decode('ascii') if v and all(32<=x<127 for x in v) else ''
 except:return ''
syms={}
for l in subprocess.check_output(['otool','-Iv',str(p)],text=True).splitlines():
 m=re.match(r'0x([0-9a-f]+)\s+\d+\s+(\S+)',l)
 if m:syms[int(m[1],16)]=m[2]
regs={}
for l in subprocess.check_output(['otool','-tvV',str(p)],text=True).splitlines():
 m=re.match(r'([0-9a-f]{8})\s',l)
 if not m:continue
 a=int(m[1],16)
 if not lo<=a<hi:continue
 m=re.search(r'movw\s+(r\d+), #0x([0-9a-f]+)',l)
 if m:regs[m[1]]=int(m[2],16)
 m=re.search(r'movt\s+(r\d+), #0x([0-9a-f]+)',l)
 if m:regs[m[1]]=(regs.get(m[1],0)&65535)|(int(m[2],16)<<16)
 annotation=''
 m=re.search(r'add\s+(r\d+), pc',l)
 if m and m[1] in regs:
  v=a+4+regs[m[1]];refs=[]
  for _ in range(3):
   value=syms.get(v) or string(v) or string(word(v+8))
   refs.append(hex(v)+(' '+value if value else ''));v=word(v)
  annotation=' ; '+' -> '.join(refs)
 print(l+annotation)
