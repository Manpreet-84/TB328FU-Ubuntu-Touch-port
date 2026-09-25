#!/usr/bin/env python3
"""Offline-only Unisoc BT INI packing check. Does not contact the controller."""

import hashlib
import re
import sys
from pathlib import Path


def pack_ini(text):
    total = re.search(r"Total Length=(\d+)", text)
    if not total:
        raise ValueError("missing total length")
    groups = []
    width = None
    values = []

    def finish():
        if width is None:
            return
        if not values or width % len(values):
            raise ValueError(f"field size {width} cannot hold {len(values)} values")
        size = width // len(values)
        if size not in (1, 2, 4):
            raise ValueError(f"unsupported value size {size}")
        groups.append(b"".join(v.to_bytes(size, "little") for v in values))

    for line in text.splitlines():
        field = re.match(r"#\[\d+\.\d+\]__/L=(\d+)", line.strip())
        if field:
            finish()
            width = int(field.group(1))
            values = []
        elif width is not None and "=" in line and not line.lstrip().startswith("#"):
            values.extend(int(v.strip(), 0) for v in line.split("=", 1)[1].split(","))
    finish()
    packed = b"".join(groups)
    if len(packed) != int(total.group(1)):
        raise ValueError(f"packed {len(packed)} bytes; expected {total.group(1)}")
    return packed


if __name__ == "__main__":
    for filename in sys.argv[1:]:
        data = pack_ini(Path(filename).read_text())
        print(f"{filename}: {len(data)} bytes, sha256 {hashlib.sha256(data).hexdigest()}")
        if "pskey" in filename:
            print("  device_addr field at offset 20:", data[20:26].hex())
            # Lenovo libbt-vendor.so's final other_rfu_w descriptor is 6 x u32
            # at offset 152. The INI provides 2 x u32; BSS initializes the
            # remaining 4 to zero. Its 0xfca0 call sends all 176 bytes.
            assert len(data) == 160 and data[152:160] == bytes(8)
            vendor_payload = data + bytes(16)
            assert len(vendor_payload) == 176
            print("  Lenovo 0xfca0 payload:", len(vendor_payload), "bytes, sha256",
                  hashlib.sha256(vendor_payload).hexdigest())

