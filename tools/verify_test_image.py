"""Check the Reno recovery payload before adding its AVB footer."""
import hashlib
import json
import lzma
import sys
from pathlib import Path

from boot_v2 import parse_boot

root = Path(__file__).resolve().parents[1]
image = Path(sys.argv[1]).read_bytes()
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
for name in ('system/bin/recovery', 'system/bin/keystore2'):
    binary = entries[name]
    assert binary[:5] == b'\x7fELF\x02' and binary[18:20] == b'\xb7\x00', name
    assert b'aera-reno-metadata-upgrade-test' in binary, name
assert 'system/bin/fastbootd' not in entries
print(json.dumps({'payload_bytes': len(image), 'ramdisk_bytes': len(compressed),
                  'reno_marker_in_both_executables': True, 'bundled_blob_hashes_match': True}, indent=2))
