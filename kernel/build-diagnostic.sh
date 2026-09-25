#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
kernel=${KERNEL_IMAGE:?set KERNEL_IMAGE to our ARM64 Image}
busybox=${BUSYBOX:?set BUSYBOX to a static ARM64 BusyBox}
rescue=${RESCUE_IMAGE:?set RESCUE_IMAGE to the verified V96 boot image}
output=${OUTPUT_IMAGE:-$repo_dir/out/tb328fu-own-kernel-v2-diag.img}
work=${BUILD_DIR:-$repo_dir/out/diagnostic-v2}
mkbootimg=${MKBOOTIMG:?set MKBOOTIMG to mkbootimg.py}
rescue_sha=7cd0dfb12a9508c0a90cc882d33140230c78b24744ae438363d9f41ad8e526f8

test "$(sha256sum "$rescue" | cut -d' ' -f1)" = "$rescue_sha" || {
    echo "refusing build: V96 rescue image hash is wrong" >&2
    exit 1
}
test -f "$kernel" || { echo "kernel image not found" >&2; exit 1; }
test -x "$busybox" || { echo "static BusyBox not found" >&2; exit 1; }

rm -rf "$work"
mkdir -p "$work/root/bin" "$work/root/sbin" "$work/root/dev" \
    "$work/root/proc" "$work/root/sys" "$work/root/run" "$(dirname "$output")"
if [ -n "${BASE_INITRD_DIR:-}" ]; then
    cp -a "$BASE_INITRD_DIR/." "$work/root/"
else
    cp "$busybox" "$work/root/bin/busybox"
fi
cp "$repo_dir/kernel/diagnostic/init" "$work/root/init"
chmod 0755 "$work/root/init" "$work/root/bin/busybox"
for applet in sh mount umount mkdir mknod cat uname setsid cttyhack sleep sync ls head ln; do
    ln -sf busybox "$work/root/bin/$applet"
done

(
    cd "$work/root"
    find . -print0 | cpio --null -o --format=newc --owner=0:0 2>/dev/null |
        lz4 -l -9 -c
) >"$work/ramdisk.lz4"

python3 "$mkbootimg" \
    --header_version 4 \
    --kernel "$kernel" \
    --ramdisk "$work/ramdisk.lz4" \
    --cmdline 'console=tty0 printk.devkmsg=on panic=30 loglevel=8 ignore_loglevel' \
    --os_version 12.0.0 \
    --os_patch_level 2025-06 \
    --output "$output"

sha256sum "$output" "$kernel" "$work/ramdisk.lz4" "$rescue"
stat -c '%n %s bytes' "$output"

