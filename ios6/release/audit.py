#!/usr/bin/env python3
"""Audit GitHub shipping files and unpacked IPA/DEB payloads without printing secrets."""
import argparse
import hashlib
import io
import json
import plistlib
import re
import tarfile
import zipfile
from pathlib import Path

KEY = re.compile(rb'(?<![A-Za-z0-9])sk-[A-Za-z0-9_-]{20,}')
FORBIDDEN = {'.env', 'ai-config.json', 'known_hosts', 'review-known_hosts', 'execution-state.json', 'execution-image.png', 'agent-frame.png'}

def blobs(name, data):
    yield name, data
    if name.endswith('.ipa') or name.endswith('.zip'):
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for member in archive.infolist():
                if not member.is_dir():
                    yield name + ':' + member.filename, archive.read(member)
    if name.endswith('.deb'):
        assert data.startswith(b'!<arch>\n')
        offset = 8
        while offset < len(data):
            header = data[offset:offset+60]
            size = int(header[48:58]); member = header[:16].decode().strip().rstrip('/')
            payload = data[offset+60:offset+60+size]; offset += 60 + size + size % 2
            if member.endswith('.tar.gz'):
                with tarfile.open(fileobj=io.BytesIO(payload), mode='r:gz') as archive:
                    for entry in archive:
                        if entry.isfile():
                            yield name + ':' + entry.name, archive.extractfile(entry).read()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument('--known-secret-file', action='append', default=[])
    args = parser.parse_args(); root = Path(args.directory)
    known = []
    for name in args.known_secret_file:
        p = Path(name)
        if p.is_file():
            # Extract only full plausible keys. Never output file contents or matches.
            known.extend(KEY.findall(p.read_bytes()))
    failures = []; count = 0
    for path in root.rglob('*'):
        if not path.is_file():
            continue
        name = path.relative_to(root).as_posix()
        if path.is_symlink() or path.name in FORBIDDEN or 'known_hosts' in path.name or any(part in ('.cophone-secrets', '__pycache__', '.git', 'jobs') for part in path.relative_to(root).parts):
            failures.append(name + ': forbidden private/cache file'); continue
        for label, data in blobs(name, path.read_bytes()):
            count += 1
            if KEY.search(data) or any(value in data for value in known):
                failures.append(label + ': possible credential (value suppressed)')
        if path.suffix == '.ipa':
            with zipfile.ZipFile(path) as archive:
                info = plistlib.loads(archive.read('Payload/CoPhone.app/Info.plist'))
                if info.get('CophoneRequireManualAPI') is not True:
                    failures.append(name + ': not the manual-key shipping build')
                if any('/Documents/' in n or '/Library/' in n or 'ai-config' in n for n in archive.namelist()):
                    failures.append(name + ': unexpected user configuration in IPA')
    manifest = root/'SHA256SUMS.json'
    if manifest.is_file():
        rows = json.loads(manifest.read_text())
        actual = {p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p != manifest}
        if set(rows) != actual: failures.append('manifest file list differs')
        for name, digest in rows.items():
            if not (root/name).is_file() or hashlib.sha256((root/name).read_bytes()).hexdigest() != digest:
                failures.append(name + ': checksum differs')
    if failures:
        raise SystemExit('\n'.join(failures))
    print(f'PASS: {count} files/archive entries audited; no matching API credentials/private configuration; shipping IPA requires manual keys; manifest verified.')

if __name__ == '__main__': main()
