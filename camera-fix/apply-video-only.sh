#!/bin/sh
set -eu

SOURCE=/etc/writable/tb328fu-camera/libaalcamera.video-only.so
TARGET=/usr/lib/aarch64-linux-gnu/qt5/plugins/mediaservice/libaalcamera.so
STOCK=2369e1826f59c982d452d55342ff3cb099834052f64b6cb9318f8d7fd513c69c
PATCHED=b345645f9f42eaf4b2efd02ab33963f457c6e9ee9812b4100f67e359d87f3393

hash() { sha256sum "$1" | cut -d ' ' -f 1; }
test "$(hash "$SOURCE")" = "$PATCHED" || {
    echo "camera patch hash mismatch" >&2
    exit 1
}

current=$(hash "$TARGET")
if [ "$current" = "$PATCHED" ]; then
    exit 0
fi
test "$current" = "$STOCK" || {
    echo "unexpected Camera plugin hash: $current" >&2
    exit 1
}

mount --bind "$SOURCE" "$TARGET"
test "$(hash "$TARGET")" = "$PATCHED"
