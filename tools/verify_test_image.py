"""Check the pre-AVB payload of a downloaded Reno recovery image locally."""
import hashlib
import json
import lzma
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from boot_v2 import parse_boot

root = Path(sys.argv[1])
image = Path(sys.argv[2]).read_bytes()
assert len(image) <= 64 * 1024 * 1024 - 69632, 'Recovery payload leaves no room for AVB'
header, pieces = parse_boot(image)
prebuilt = json.loads((root / 'prebuilt/manifest.json').read_text())
for name, key in [('kernel', 'kernel'), ('dtb.img', 'dtb'), ('recovery-dtbo.img', 'dtbo')]:
    assert hashlib.sha256(pieces[name]).hexdigest() == prebuilt['components'][key], name

compressed = pieces['ramdisk']
assert int.from_bytes(compressed[1:5], 'little') == 32 * 1024 * 1024
data = lzma.decompress(compressed, format=lzma.FORMAT_ALONE)
entries = {}
offset = 0
while True:
    hdr = data[offset:offset + 110]
    assert len(hdr) == 110 and hdr[:6] in (b'070701', b'070702')
    size = int(hdr[54:62], 16)
    namesize = int(hdr[94:102], 16)
    assert namesize and data[offset + 109 + namesize] == 0
    name = data[offset + 110:offset + 109 + namesize].decode().removeprefix('./')
    start = (offset + 110 + namesize + 3) & ~3
    if name == 'TRAILER!!!':
        break
    assert name not in entries and start + size <= len(data)
    entries[name] = data[start:start + size]
    offset = (start + size + 3) & ~3

for name, record in json.loads((root / 'proprietary/manifest.json').read_text()).items():
    assert hashlib.sha256(entries[name]).hexdigest() == record['sha256'], name
def arm64(name):
    binary = entries[name]
    assert binary[:5] == b'\x7fELF\x02' and binary[18:20] == b'\xb7\x00', name
    return binary


marker = b'aera-reno-metadata-upgrade-test'
assert marker in arm64('system/bin/recovery'), 'Reno marker missing from recovery'
keystore_path = 'system/bin/keystore2'
keystore = arm64(keystore_path)
if marker not in keystore:
    # Rust can place the experiment in the shared library instead of the executable.
    with tempfile.TemporaryDirectory() as temp:
        executable = Path(temp) / 'keystore2'
        executable.write_bytes(keystore)
        readelf = sys.argv[3] if len(sys.argv) > 3 else 'readelf'
        dynamic = subprocess.check_output([readelf, '-d', str(executable)], text=True)
    needed = re.findall(r'\(NEEDED\).*?\[(libkeystore2(?:\.dylib)?\.so)\]', dynamic)
    assert len(needed) == 1, 'Keystore2 marker missing and no unique linked libkeystore2 found'
    keystore_path = 'system/lib64/' + needed[0]
    assert marker in arm64(keystore_path), f'Reno marker missing from {keystore_path}'
assert 'system/bin/fastbootd' not in entries
print(json.dumps({'payload_bytes': len(image), 'ramdisk_bytes': len(compressed),
                  'keystore_marker_path': keystore_path, 'bundled_blob_hashes_match': True}, indent=2))
