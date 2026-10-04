#!/usr/bin/env python3
"""Create a portable source ZIP without build output, local configuration or SDKs."""
from pathlib import Path
import hashlib
import re
import zipfile

root = Path(__file__).resolve().parents[1]
version = re.search(r'^version:\s*(\S+)', (root / 'pubspec.yaml').read_text(), re.M)[1]
target = root.parent / f'darai-flutter-chat-{version}.zip'
skip_dirs = {'.git', '.dart_tool', 'build', '.gradle', '.kotlin', '.cxx', '__pycache__'}
skip_files = {'local.properties', 'darai-config.json', '.flutter-plugins',
              '.flutter-plugins-dependencies', '.packages', 'key.properties',
              'GeneratedPluginRegistrant.java'}
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(root.rglob('*')):
        relative = file.relative_to(root)
        if not file.is_file() or set(relative.parts) & skip_dirs:
            continue
        if file.name in skip_files or file.suffix in {'.jks', '.keystore'}:
            continue
        if relative.as_posix() == 'pubspec.lock':
            continue  # Library dependencies are resolved by the consuming app.
        archive.write(file, f'darai-flutter-chat/{relative.as_posix()}')
digest = hashlib.sha256(target.read_bytes()).hexdigest()
target.with_suffix('.zip.sha256').write_text(f'{digest}  {target.name}\n')
print(target)
print(f'SHA256: {digest}')
