#!/usr/bin/env python3
"""Mic bridge for video-only Camera recordings.

Run as phablet while the RAM-only video-only Camera patch is active.
The silent MP4 is atomically replaced only after a successful audio mux.
"""

import ctypes
import os
from pathlib import Path
import select
import signal
import struct
import subprocess
import sys


VIDEOS = Path("/home/phablet/Videos/camera.ubports")
WORK = Path("/home/phablet/camera-fix")
GST = str(WORK / "tools/usr/bin/gst-launch-1.0")
IN_CREATE = 0x00000100
IN_CLOSE_WRITE = 0x00000008


def gst(*args):
    subprocess.run([GST, "-q", *args], check=True, timeout=60)


def finish(video, proc, audio_file):
    proc.send_signal(signal.SIGINT)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
    audio_file.close()
    raw = WORK / (video.stem + ".raw")
    aac = WORK / (video.stem + ".m4a")
    temporary = WORK / (video.stem + "-with-audio.mp4")
    if raw.stat().st_size < 48000:
        print("No microphone data for", video.name, flush=True)
        return
    try:
        gst("filesrc", "location=" + str(raw), "!", "rawaudioparse",
            "format=pcm", "pcm-format=s16le", "sample-rate=48000",
            "num-channels=1", "!", "audioconvert", "!", "voaacenc",
            "!", "aacparse", "!", "mp4mux", "!", "filesink",
            "location=" + str(aac))
        gst("mp4mux", "name=mux", "!", "filesink",
            "location=" + str(temporary), "filesrc", "location=" + str(video),
            "!", "qtdemux", "name=d", "d.video_0", "!", "queue", "!",
            "h264parse", "!", "mux.video_0", "filesrc",
            "location=" + str(aac), "!", "qtdemux", "name=a",
            "a.audio_0", "!", "queue", "!", "aacparse", "!",
            "mux.audio_0")
        if temporary.stat().st_size == 0:
            raise RuntimeError("mux produced an empty file")
        temporary.replace(video)
        print("Added microphone audio to", video, flush=True)
    finally:
        raw.unlink(missing_ok=True)
        aac.unlink(missing_ok=True)
        temporary.unlink(missing_ok=True)


def main():
    libc = ctypes.CDLL("libc.so.6", use_errno=True)
    fd = libc.inotify_init1(os.O_CLOEXEC)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "inotify_init1")
    if libc.inotify_add_watch(fd, os.fsencode(VIDEOS), IN_CREATE | IN_CLOSE_WRITE) < 0:
        raise OSError(ctypes.get_errno(), "inotify_add_watch")
    active = {}
    print("Watching", VIDEOS, flush=True)
    while True:
        readable, _, _ = select.select([fd], [], [])
        if not readable:
            continue
        events = os.read(fd, 65536)
        at = 0
        while at < len(events):
            _, mask, _, length = struct.unpack_from("iIII", events, at)
            name = events[at + 16:at + 16 + length].split(b"\0", 1)[0].decode()
            at += 16 + length
            if not name.endswith(".mp4") or name.endswith("-with-audio.mp4"):
                continue
            video = VIDEOS / name
            if mask & IN_CREATE and name not in active:
                raw = WORK / (video.stem + ".raw")
                audio_file = raw.open("wb")
                env = dict(os.environ, PULSE_SERVER="unix:/run/user/32011/pulse/native")
                proc = subprocess.Popen(
                    ["parec", "--device=source.primary_input", "--format=s16le",
                     "--rate=48000", "--channels=1", "--raw"],
                    stdout=audio_file, stderr=subprocess.DEVNULL, env=env)
                active[name] = (proc, audio_file)
                print("Mic started for", name, flush=True)
            if mask & IN_CLOSE_WRITE and name in active:
                proc, audio_file = active.pop(name)
                try:
                    finish(video, proc, audio_file)
                except Exception as exc:
                    print("Mux failed for", name, ":", exc, file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()

