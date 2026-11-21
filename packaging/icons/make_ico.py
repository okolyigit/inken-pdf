"""PNG'lerden Windows .ico yazar (her boy PNG olarak gömülü; Vista+).

Kullanım: python3 make_ico.py <çıktı.ico> <a.png> <b.png> ...
"""
import struct
import sys

out, *pngs = sys.argv[1:]
images = []
for path in pngs:
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"PNG değil: {path}")
    width, height = struct.unpack(">II", data[16:24])
    images.append((width, height, data))
images.sort(key=lambda i: i[0])

header = struct.pack("<HHH", 0, 1, len(images))
offset = len(header) + 16 * len(images)
entries, blobs = b"", b""
for width, height, data in images:
    entries += struct.pack(
        "<BBBBHHII",
        width % 256,  # 256 → 0
        height % 256,
        0,
        0,
        1,
        32,
        len(data),
        offset,
    )
    blobs += data
    offset += len(data)
open(out, "wb").write(header + entries + blobs)
