#!/bin/bash
set -e

BASE=/etc/writable/tb328fu-camera
PATCH=/home/phablet/camera-fix/libaalcamera.video-only-test.so
PATCH_HASH=b345645f9f42eaf4b2efd02ab33963f457c6e9ee9812b4100f67e359d87f3393

test "$(sha256sum "$PATCH" | cut -d ' ' -f 1)" = "$PATCH_HASH"
install -d -m 0755 "$BASE"
install -m 0644 "$PATCH" "$BASE/libaalcamera.video-only.so"
install -m 0755 /tmp/apply-video-only.sh "$BASE/apply-video-only.sh"
install -m 0755 /tmp/record-audio-bridge.py "$BASE/record-audio-bridge.py"
install -m 0644 /tmp/tb328fu-camera-patch.service /etc/systemd/system/
install -m 0644 /tmp/tb328fu-camera-patch.timer /etc/systemd/system/
install -d -o phablet -g phablet -m 0755 /home/phablet/.config/systemd/user
install -o phablet -g phablet -m 0644 /tmp/tb328fu-camera-audio.service \
    /home/phablet/.config/systemd/user/

systemctl daemon-reload
systemctl enable tb328fu-camera-patch.timer
systemctl start tb328fu-camera-patch.service

runuser -u phablet -- env \
    XDG_RUNTIME_DIR=/run/user/32011 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus \
    systemctl --user daemon-reload
runuser -u phablet -- env \
    XDG_RUNTIME_DIR=/run/user/32011 \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/32011/bus \
    systemctl --user enable --now tb328fu-camera-audio.service

echo "Camera recording fix installed."
