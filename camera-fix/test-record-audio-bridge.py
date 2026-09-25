#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import signal
import tempfile


class FakeProcess:
    def send_signal(self, value):
        assert value == signal.SIGINT

    def wait(self, timeout=None):
        return 0

    def kill(self):
        raise AssertionError("clean test process should not be killed")


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    spec = importlib.util.spec_from_file_location(
        "camera_bridge", Path(__file__).with_name("record-audio-bridge.py"))
    bridge = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bridge)
    bridge.WORK = root / "work"
    bridge.WORK.mkdir()
    video = root / "clip.mp4"
    video.write_bytes(b"silent-video")
    raw = bridge.WORK / "clip.raw"
    raw.write_bytes(b"a" * 48001)
    audio_file = raw.open("ab")
    calls = [0]

    def fake_gst(*args):
        calls[0] += 1
        locations = [Path(arg[9:]) for arg in args if arg.startswith("location=")]
        output = locations[-1] if calls[0] == 1 else locations[0]
        output.write_bytes(b"muxed-video-with-audio")

    bridge.gst = fake_gst
    bridge.finish(video, FakeProcess(), audio_file)

    assert video.read_bytes() == b"muxed-video-with-audio"
    assert not (root / "clip-with-audio.mp4").exists()
    assert not raw.exists()
    assert calls[0] == 2

print("camera bridge atomic replacement test passed")
