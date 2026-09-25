#!/bin/sh
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
START="$HERE/tb328fu-bt-start-safe.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

expect_fail() {
    if "$@" >/dev/null 2>&1; then
        echo "expected failure: $*" >&2
        exit 1
    fi
}

expect_fail env BT_UPTIME=1 BT_SYSFS_ROOT="$TMP" BT_CHIP=/dev/null "$START"
expect_fail env BT_UPTIME=121 BT_SYSFS_ROOT="$TMP" BT_CHIP=/dev/null "$START"

mkdir -p "$TMP/class/tty/ttyBT0" "$TMP/class/rfkill/rfkill0"
echo bluetooth >"$TMP/class/rfkill/rfkill0/name"
echo 0 >"$TMP/class/rfkill/rfkill0/state"
expect_fail env BT_UPTIME=121 BT_SYSFS_ROOT="$TMP" BT_CHIP=/dev/null "$START"

echo 1 >"$TMP/class/rfkill/rfkill0/state"
env BT_UPTIME=121 BT_SYSFS_ROOT="$TMP" BT_CHIP=/dev/null \
    BT_SKIP_INITIALIZER=1 BT_PROXY="$HERE/test-bt-proxy-exit.py" "$START"

echo "safe launcher tests passed"

