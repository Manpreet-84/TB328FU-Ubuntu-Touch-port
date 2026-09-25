#!/bin/sh
# Manual-only launcher for the TB328FU Bluetooth H4 proxy.
# It deliberately does not load drivers, toggle rfkill or initialize firmware.
set -eu

MIN_UPTIME=${BT_MIN_UPTIME:-120}
CHIP=${BT_CHIP:-/dev/ttyBT0}
SYSFS=${BT_SYSFS_ROOT:-/sys}
PROXY=${BT_PROXY:-/etc/writable/tb328fu-bt/tb328fu-bt-proxy.py}
INITIALIZER=${BT_INITIALIZER:-/etc/writable/tb328fu-bt/bt-vendor-init.py}

uptime=${BT_UPTIME:-$(cut -d. -f1 /proc/uptime)}
if [ "$uptime" -lt "$MIN_UPTIME" ]; then
    echo "refusing Bluetooth start at ${uptime}s; wait until ${MIN_UPTIME}s" >&2
    exit 75
fi

if [ ! -e "$SYSFS/class/tty/ttyBT0" ]; then
    echo "ttyBT0 is not registered; leaving Bluetooth disabled" >&2
    exit 69
fi

if [ ! -c "$CHIP" ]; then
    device=$(cat "$SYSFS/class/tty/ttyBT0/dev" 2>/dev/null || true)
    major=${device%:*}
    minor=${device#*:}
    case "$major:$minor" in
        *[!0-9:]*|:|*:)
            echo "invalid ttyBT0 device number: $device" >&2
            exit 69
            ;;
    esac
    mknod "$CHIP" c "$major" "$minor"
    chown root:bluetooth "$CHIP" 2>/dev/null || true
    chmod 660 "$CHIP"
fi

powered=0
for state in "$SYSFS"/class/rfkill/rfkill*/state; do
    [ -e "$state" ] || continue
    name=$(cat "${state%state}name" 2>/dev/null || true)
    if [ "$name" = bluetooth ] && [ "$(cat "$state")" = 1 ]; then
        powered=1
        break
    fi
done
if [ "$powered" -ne 1 ]; then
    echo "Bluetooth rfkill is off; refusing to power-cycle it automatically" >&2
    exit 69
fi

if [ "${BT_SKIP_INITIALIZER:-0}" != 1 ]; then
    /usr/bin/timeout --signal=TERM --kill-after=2 45 \
        /usr/bin/python3 "$INITIALIZER" --send
fi

exec /usr/bin/python3 "$PROXY"

