#!/bin/sh
set -eu

image=${1:?usage: verify-diagnostic.sh DIAGNOSTIC_IMAGE KERNEL_IMAGE RESCUE_IMAGE}
kernel=${2:?usage: verify-diagnostic.sh DIAGNOSTIC_IMAGE KERNEL_IMAGE RESCUE_IMAGE}
rescue=${3:?usage: verify-diagnostic.sh DIAGNOSTIC_IMAGE KERNEL_IMAGE RESCUE_IMAGE}
unpack=${UNPACK_BOOTIMG:?set UNPACK_BOOTIMG to unpack_bootimg.py}
rescue_sha=7cd0dfb12a9508c0a90cc882d33140230c78b24744ae438363d9f41ad8e526f8
marker=TB328FU_OWN_KERNEL_V2_REACHED_INIT
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

test "$(sha256sum "$rescue" | cut -d' ' -f1)" = "$rescue_sha"
test "$(stat -c %s "$image")" = 67108864
test ! "$image" -ef "$rescue"
test "$(tail -c 64 "$image" | head -c 4)" = AVBf
python3 "$unpack" --boot_img "$image" --out "$work/unpacked" >/dev/null
cmp "$kernel" "$work/unpacked/kernel"
lz4 -dc "$work/unpacked/ramdisk" >"$work/ramdisk.cpio"
test "$(cpio -i --to-stdout init <"$work/ramdisk.cpio" 2>/dev/null | grep -c "$marker")" -eq 1

echo "PASS: header-v4 diagnostic image contains the expected kernel and init marker"
sha256sum "$image" "$work/unpacked/kernel" "$work/unpacked/ramdisk" "$rescue"

