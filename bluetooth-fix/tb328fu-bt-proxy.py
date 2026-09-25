#!/usr/bin/env python3
"""
TB328FU (Lenovo Tab M10 3rd Gen / Unisoc UMS512) Bluetooth HCI proxy - v2.

Problem
-------
The stock Lenovo 5.4.233 kernel drives the Unisoc CP2 BT controller through
/dev/ttyBT0 (vendor module sprdbt_tty, char major 489) with the kernel H4 line
discipline.  During init the CP2 rejects

    HCI_OP_WRITE_DEF_LINK_POLICY (0x080f)  ->  status 0x12

so the kernel aborts: "hci0 end: err -22" / "Can't init device hci0: Invalid
argument (22)" and the adapter never powers up.

Lenovo's 5.4.233 source is not published and the public 5.4.233 tree is not
module-ABI compatible, so the fix lives in userspace:

    kernel HCI (H4 ldisc) <--PTY--> proxy <--/dev/ttyBT0--> Unisoc CP2

Commands in SKIP_LOCAL are answered locally with a synthetic success so kernel
init can complete; everything else is relayed verbatim.

v2 fixes (why v1 dropped connections):
  * queued, resumable writes - v1 used non-blocking os.write() and silently
    truncated frames on EAGAIN/short writes, corrupting HCI during pairing and
    SCO traffic (the "headphones crash and Bluetooth turns off" symptom).
  * correct HCI status decoding in logs (v1 printed the opcode high byte).
  * ACL/SCO accounting so real traffic is visible.
  * exits when btattach dies so systemd restarts the whole chain.
"""

import collections
import fcntl
import os
import pty
import select
import struct
import subprocess
import sys
import termios
import time

CHIP = os.environ.get("BT_CHIP", "/dev/ttyBT0")
LOG_PATH = os.environ.get("BT_LOG", "/run/tb328fu-bt.log")
ATTACH_LOG = "/run/tb328fu-bt-attach.log"
PTY_FILE = "/run/tb328fu-bt.pty"

# Commands the CP2 rejects -> answered locally with status 0x00.
#   0x080f = HCI_OP_WRITE_DEF_LINK_POLICY (Write Default Link Policy Settings)
SKIP_LOCAL = {
    0x080f,
}

# opcode -> replacement parameter payload (unused by default)
PATCH = {}

# Events carrying status as their first parameter.
STATUS_FIRST_EVENTS = {0x03, 0x04, 0x05, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d,
                       0x1b, 0x1c, 0x1d, 0x2a, 0x2b, 0x2c, 0x36, 0x3e}
# Events always worth logging: connection / pairing / SCO life-cycle.
NOTABLE_EVENTS = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0b,
                  0x0d, 0x12, 0x13, 0x16, 0x17, 0x18, 0x19, 0x1b, 0x1c, 0x1f,
                  0x20, 0x22, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30,
                  0x31, 0x33, 0x38, 0x3b, 0x3e, 0x3f}
# LE Meta sub-events worth logging (connection setup, not adv spam).
LE_NOTABLE_SUBEVENTS = {0x01, 0x0a, 0x0c, 0x11}

TIOCSETD = 0x5423
N_HCI = 15
HCIUARTSETPROTO = 0x400455C8
HCI_UART_H4 = 0

MAX_QUEUE = 512

LOG = open(LOG_PATH, "a", buffering=1)


def log(msg):
    LOG.write("[%s] %s\n" % (time.strftime("%H:%M:%S"), msg))


def make_raw(fd):
    """Put a tty into raw mode so H4 framing bytes are never mangled."""
    try:
        attrs = termios.tcgetattr(fd)
    except Exception as exc:
        log("tcgetattr failed: %s" % exc)
        return
    attrs[0] &= ~(termios.IGNBRK | termios.BRKINT | termios.PARMRK |
                  termios.ISTRIP | termios.INLCR | termios.IGNCR |
                  termios.ICRNL | termios.IXON)
    attrs[1] &= ~termios.OPOST
    attrs[2] &= ~(termios.CSIZE | termios.PARENB)
    attrs[2] |= termios.CS8
    attrs[3] &= ~(termios.ECHO | termios.ECHONL | termios.ICANON |
                  termios.ISIG | termios.IEXTEN)
    attrs[6][termios.VMIN] = 1
    attrs[6][termios.VTIME] = 0
    try:
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
    except Exception as exc:
        log("tcsetattr failed: %s" % exc)


def frame_lengths(src, buf):
    """Return (need, plen) for the frame at buf[0], or (None, None)."""
    kind = buf[0]
    if kind == 0x04:                           # HCI event (either direction)
        if len(buf) < 3:
            return None, None
        return 3 + buf[2], buf[2]
    if kind in (0x01, 0x02, 0x03):             # cmd / ACL / SCO
        if len(buf) < 4:
            return None, None
        if kind == 0x01:
            return 4 + buf[3], buf[3]          # opcode + plen
        if len(buf) < 5:
            return None, None
        plen = buf[3] | (buf[4] << 8)          # handle + dlen
        return 5 + plen, plen
    return 0, 0


def extract(buf, src):
    """Return (frame, rest) or (None, buf) when more bytes are needed."""
    if not buf:
        return None, buf
    need, _plen = frame_lengths(src, buf)
    if need is None:
        return None, buf
    if need == 0:
        return b"", buf[1:]                    # drop stray byte
    if len(buf) < need:
        return None, buf
    return buf[:need], buf[need:]


def event_status(frame):
    """Best-effort HCI status byte for an event frame.

    Note the two asymmetric layouts:
      Command Complete (0x0e): ncmd(1) opcode(2) status(1)   -> status last
      Command Status   (0x0f): status(1) ncmd(1) opcode(2)   -> status first
    """
    if len(frame) < 4:
        return None
    evt = frame[1]
    if evt == 0x0e:
        return frame[6] if len(frame) >= 7 else None
    if evt == 0x0f:
        return frame[3]
    if evt in STATUS_FIRST_EVENTS:
        return frame[3]
    return None


def describe(frame):
    kind = frame[0]
    if kind == 0x04:
        evt = frame[1]
        status = event_status(frame)
        extra = "" if status is None else " status 0x%02x" % status
        return "event 0x%02x%s" % (evt, extra)
    if kind == 0x01:
        op = frame[1] | (frame[2] << 8)
        return "command 0x%04x" % op
    if kind == 0x02:
        ln = (frame[3] | (frame[4] << 8))
        return "ACL len %d" % ln
    if kind == 0x03:
        ln = (frame[3] | (frame[4] << 8))
        return "SCO len %d" % ln
    return "unknown 0x%02x" % kind


def start_kernel_hci(slave_name):
    """Attach the kernel HCI H4 line discipline to the PTY slave."""
    proc = subprocess.Popen(
        ["btattach", "-B", slave_name, "-P", "h4"],
        stdout=open(ATTACH_LOG, "ab"), stderr=subprocess.STDOUT,
        close_fds=True)
    log("btattach pid %d on %s" % (proc.pid, slave_name))
    time.sleep(1.5)
    if proc.poll() is not None:
        log("btattach exited rc=%s -> ioctl fallback" % proc.returncode)
        fd = os.open(slave_name, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        make_raw(fd)
        fcntl.ioctl(fd, TIOCSETD, struct.pack("i", N_HCI))
        fcntl.ioctl(fd, HCIUARTSETPROTO, struct.pack("i", HCI_UART_H4))
        log("H4 ldisc attached via ioctl on %s" % slave_name)
        return None
    return proc


def flush_queue(fd, queue, label, counters):
    """Write as much of queue[0] as the fd accepts; keep the remainder."""
    while queue:
        frame = queue[0]
        try:
            written = os.write(fd, frame)
        except (BlockingIOError, InterruptedError):
            return
        except OSError as exc:
            log("write error to %s: %s (dropping %d bytes)"
                % (label, exc, len(frame)))
            counters["dropped"] += 1
            queue.popleft()
            continue
        if written < len(frame):
            queue[0] = frame[written:]
            return
        queue.popleft()


def enqueue(queue, frame, label, counters):
    if len(queue) >= MAX_QUEUE:
        queue.popleft()
        counters["dropped"] += 1
        log("queue %s overflow - dropped oldest frame" % label)
    queue.append(frame)


def main():
    try:
        os.unlink(PTY_FILE)
    except OSError:
        pass

    master, slave = pty.openpty()
    make_raw(slave)
    make_raw(master)
    slave_name = os.ttyname(slave)
    with open(PTY_FILE, "w") as handle:
        handle.write(slave_name)
    log("=== v2 bridge start: pty=%s chip=%s ===" % (slave_name, CHIP))

    attach = start_kernel_hci(slave_name)

    chip = os.open(CHIP, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    make_raw(chip)
    termios.tcflush(chip, termios.TCIOFLUSH)
    os.set_blocking(master, False)
    log("chip fd %d opened" % chip)

    to_chip = collections.deque()
    to_kern = collections.deque()
    counters = collections.Counter()
    seen_cmds = set()
    kbuf = b""
    cbuf = b""
    last_report = time.time()

    while True:
        if attach is not None and attach.poll() is not None:
            log("btattach exited rc=%s - exiting so systemd restarts"
                % attach.returncode)
            return 1

        writers = []
        if to_chip:
            writers.append(chip)
        if to_kern:
            writers.append(master)
        try:
            ready, writable, _ = select.select([master, chip], writers, [], 1.0)
        except InterruptedError:
            continue

        for fd in writable:
            if fd == chip:
                flush_queue(chip, to_chip, "chip", counters)
            else:
                flush_queue(master, to_kern, "kernel", counters)

        for fd in ready:
            try:
                data = os.read(fd, 8192)
            except (BlockingIOError, InterruptedError):
                continue
            except OSError as exc:
                log("read error fd=%d: %s" % (fd, exc))
                continue
            if not data:
                continue

            if fd == master:                       # kernel -> chip
                kbuf += data
                while True:
                    frame, kbuf = extract(kbuf, "kernel")
                    if frame is None:
                        break
                    if frame == b"":
                        counters["stray"] += 1
                        continue
                    kind = frame[0]
                    if kind == 0x01:
                        opcode = frame[1] | (frame[2] << 8)
                        counters["cmd"] += 1
                        if opcode in SKIP_LOCAL:
                            event = bytes([0x04, 0x0e, 0x04, 0x01,
                                           frame[1], frame[2], 0x00])
                            enqueue(to_kern, event, "kernel", counters)
                            counters["skipped"] += 1
                            log("cmd 0x%04x SKIPPED -> fake success (total %d)"
                                % (opcode, counters["skipped"]))
                            continue
                        if opcode in PATCH:
                            frame = frame[:3] + PATCH[opcode]
                            log("cmd 0x%04x patched" % opcode)
                        elif opcode not in seen_cmds:
                            seen_cmds.add(opcode)
                            log("cmd 0x%04x (first seen)" % opcode)
                    elif kind == 0x02:
                        counters["acl_to_chip"] += 1
                    elif kind == 0x03:
                        counters["sco_to_chip"] += 1
                    enqueue(to_chip, frame, "chip", counters)
            else:                                  # chip -> kernel
                cbuf += data
                while True:
                    frame, cbuf = extract(cbuf, "chip")
                    if frame is None:
                        break
                    if frame == b"":
                        counters["stray"] += 1
                        continue
                    kind = frame[0]
                    if kind == 0x04:
                        counters["evt"] += 1
                        evt = frame[1]
                        sub = frame[3] if evt == 0x3e and len(frame) > 3 else None
                        if evt == 0x3e:
                            status = frame[4] if (sub in (0x01, 0x0a)
                                                 and len(frame) > 4) else None
                            worth = (sub in LE_NOTABLE_SUBEVENTS
                                     or status not in (None, 0))
                        else:
                            status = event_status(frame)
                            worth = (evt in NOTABLE_EVENTS
                                     or status not in (None, 0))
                        if worth:
                            body = frame.hex() if len(frame) <= 40 else \
                                frame[:40].hex() + "..."
                            label = "evt 0x%02x" % evt
                            if sub is not None:
                                label += " sub 0x%02x" % sub
                            log("%s len %d %s%s"
                                % (label, len(frame),
                                   "" if status is None
                                   else "status 0x%02x " % status, body))
                    elif kind == 0x02:
                        counters["acl_to_kernel"] += 1
                    elif kind == 0x03:
                        counters["sco_to_kernel"] += 1
                    enqueue(to_kern, frame, "kernel", counters)

        if time.time() - last_report > 300:
            last_report = time.time()
            log("stats: %s" % dict(counters))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)

