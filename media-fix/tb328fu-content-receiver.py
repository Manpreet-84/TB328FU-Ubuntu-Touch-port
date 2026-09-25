#!/usr/bin/python3
"""Receive a Content Hub video and open it with the Wayland player."""

import os
import subprocess
import sys
import uuid

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib


PLAYER = "/home/phablet/media-fix/tb328fu-play"
SERVICE = "com.lomiri.content.dbus.Service"
TRANSFER = "com.lomiri.content.dbus.Transfer"
HANDLER = "com.lomiri.content.dbus.Handler"
OBJECT_PATH = "/com/lomiri/content/hub/peers/tb328fu_wayland_player"


def video_uris(items):
    return [str(item[3]) for item in items
            if len(item) == 4 and str(item[3]).startswith("file://")]


class Receiver(dbus.service.Object):
    def __init__(self, bus, loop):
        super().__init__(bus, OBJECT_PATH)
        self.bus = bus
        self.loop = loop

    @dbus.service.method(HANDLER, in_signature="o")
    def HandleImport(self, path):
        transfer = dbus.Interface(self.bus.get_object(SERVICE, path), TRANSFER)
        uris = video_uris(transfer.Collect())
        if uris:
            runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
            bus = os.environ.get("DBUS_SESSION_BUS_ADDRESS", f"unix:path={runtime}/bus")
            subprocess.run([
                "systemd-run", "--user", "--collect",
                f"--unit=tb328fu-video-{uuid.uuid4().hex[:12]}",
                f"--setenv=XDG_RUNTIME_DIR={runtime}",
                f"--setenv=DBUS_SESSION_BUS_ADDRESS={bus}",
                f"--setenv=WAYLAND_DISPLAY={os.environ.get('WAYLAND_DISPLAY', 'wayland-0')}",
                PLAYER, *uris,
            ], check=True)
        else:
            print("Content Hub sent no local video URI", file=sys.stderr)
        GLib.idle_add(self.loop.quit)

    @dbus.service.method(HANDLER, in_signature="o")
    def HandleShare(self, path):
        self.HandleImport(path)

    @dbus.service.method(HANDLER, in_signature="o")
    def HandleExport(self, path):
        GLib.idle_add(self.loop.quit)


def main():
    if sys.argv[1:] == ["--self-test"]:
        assert video_uris([("", b"", "flower", "file:///tmp/flower.mp4")]) == ["file:///tmp/flower.mp4"]
        assert video_uris([("", b"", "remote", "https://example.org/video")]) == []
        return
    if len(sys.argv) > 1:
        subprocess.run([PLAYER, *sys.argv[1:]], check=True)
        return

    DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    loop = GLib.MainLoop()
    Receiver(bus, loop)
    service = dbus.Interface(bus.get_object(SERVICE, "/"), SERVICE)
    service.RegisterImportExportHandler("tb328fu-wayland-player", dbus.ObjectPath(OBJECT_PATH))
    GLib.timeout_add_seconds(30, loop.quit)
    loop.run()


if __name__ == "__main__":
    main()
