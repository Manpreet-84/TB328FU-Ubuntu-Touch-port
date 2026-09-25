#!/usr/bin/env python3
"""One-shot, RAM-only Unisoc BT vendor init. Run only with HCI proxy stopped."""

import os
from pathlib import Path
import runpy
import select
import subprocess
import sys
import time
import termios


PACK = runpy.run_path(str(Path(__file__).with_name("bt-pack-ini.py")))["pack_ini"]
CHIP = "/dev/ttyBT0"


def payloads():
    firmware = Path("/android/vendor/firmware")
    chipid = Path("/sys/devices/platform/sprd-marlin3/sprd-marlin3:sprd-mtty/chipid").read_text()
    suffix = "" if chipid.startswith("2/") else "_aa"
    pskey = bytearray(PACK((firmware / f"bt_configure_pskey{suffix}.ini").read_text()))
    rf = PACK((firmware / f"bt_configure_rf{suffix}.ini").read_text())
    mac_file = Path("/mnt/vendor/btmac.txt")
    if not mac_file.exists():
        mac_file = Path("/etc/writable/tb328fu-bt/btmac.txt")
    mac_text = mac_file.read_text().strip()
    assert len(mac_text) == 12 and all(c in "0123456789abcdefABCDEF" for c in mac_text)
    pskey[20:26] = bytes.fromhex(mac_text)[::-1]
    assert len(pskey) == 160 and len(rf) == 252
    # Lenovo's descriptor for the final field is 6 x u32, not the INI's 2 x u32.
    pskey.extend(bytes(16))
    assert len(pskey) == 176
    print(f"chipid={chipid.strip()} rf_variant={suffix or 'base'} mac={mac_text}", flush=True)
    print(f"payload lengths: pskey={len(pskey)} rf={len(rf)}", flush=True)
    return bytes(pskey), rf


def command(fd, opcode, payload):
    packet = bytes((1, opcode & 255, opcode >> 8, len(payload))) + payload
    pending = memoryview(packet)
    deadline = time.monotonic() + 6
    while pending:
        if not select.select([], [fd], [], max(0, deadline - time.monotonic()))[1]:
            raise TimeoutError(f"write 0x{opcode:04x}")
        pending = pending[os.write(fd, pending):]
    buf = bytearray()
    while time.monotonic() < deadline:
        if not select.select([fd], [], [], max(0, deadline - time.monotonic()))[0]:
            break
        buf.extend(os.read(fd, 8192))
        while len(buf) >= 3:
            if buf[0] != 4:
                buf.pop(0)
                continue
            size = 3 + buf[2]
            if len(buf) < size:
                break
            evt = bytes(buf[:size])
            del buf[:size]
            if evt[1] == 0x0e and len(evt) >= 7:
                got = evt[4] | evt[5] << 8
                if got == opcode:
                    print(f"0x{opcode:04x}: complete status 0x{evt[6]:02x}", flush=True)
                    if evt[6]:
                        raise RuntimeError(f"controller rejected 0x{opcode:04x}")
                    return
            elif evt[1] == 0x0f and len(evt) >= 7:
                got = evt[5] | evt[6] << 8
                if got == opcode and evt[3]:
                    raise RuntimeError(f"0x{opcode:04x}: status 0x{evt[3]:02x}")
    raise TimeoutError(f"no completion for 0x{opcode:04x}")


def main():
    pskey, rf = payloads()
    if "--send" not in sys.argv:
        print("dry run; no HCI commands sent")
        return
    if os.geteuid() != 0:
        raise PermissionError("--send requires root")
    if subprocess.run(["pgrep", "-f", "tb328fu-bt-proxy.py"],
                      stdout=subprocess.DEVNULL).returncode == 0:
        raise RuntimeError("HCI proxy is still active; refusing concurrent chip access")
    fd = os.open(CHIP, os.O_RDWR | os.O_NONBLOCK | os.O_NOCTTY)
    try:
        attrs = termios.tcgetattr(fd)
        attrs[0] = 0
        attrs[1] = 0
        attrs[2] = (attrs[2] & ~(termios.CSIZE | termios.PARENB)) | termios.CS8
        attrs[3] = 0
        attrs[6][termios.VMIN] = 1
        attrs[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        termios.tcflush(fd, termios.TCIOFLUSH)
        for opcode, data in ((0xfca0, pskey), (0xfca2, rf),
                             (0xfca1, b"\x00\x09\x01"), (0x0c03, b"")):
            command(fd, opcode, data)
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()

