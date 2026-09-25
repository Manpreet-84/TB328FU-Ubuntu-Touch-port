#!/bin/sh
set -eu

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }
check() { label=$1; shift; if "$@" >/dev/null 2>&1; then pass "$label"; else fail "$label"; fi; }

failures=0

check tb328fu-bt.service systemctl is-active --quiet tb328fu-bt.service
check tb328fu-camera-patch.service systemctl is-active --quiet tb328fu-camera-patch.service

uid=$(id -u phablet)
if XDG_RUNTIME_DIR="/run/user/$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
  systemctl --user is-active --quiet tb328fu-camera-audio.service; then
  pass tb328fu-camera-audio.service
else
  fail tb328fu-camera-audio.service
fi

if findmnt -rn /usr/lib/aarch64-linux-gnu/qt5/plugins/mediaservice/libaalcamera.so | \
  grep -q '/etc/writable/tb328fu-camera/libaalcamera.video-only.so'; then
  pass camera-plugin-bind-mount
else
  fail camera-plugin-bind-mount
fi

check bluetooth-hci0 test -e /sys/class/bluetooth/hci0
check battery-sysfs test -r /sys/class/power_supply/battery/capacity

printf '\nUptime: '
uptime -p
printf 'Kernel: '
uname -r
printf 'Failures: %s\n' "$failures"
test "$failures" -eq 0
