#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
kernel=${KERNEL_IMAGE:?set KERNEL_IMAGE}
dtb=${DTB_IMAGE:?set DTB_IMAGE}
vendor_template=${VENDOR_BOOT_TEMPLATE:?set VENDOR_BOOT_TEMPLATE}
vendor_ramdisk=${VENDOR_RAMDISK:?set VENDOR_RAMDISK}
output_dir=${OUTPUT_DIR:?set OUTPUT_DIR}
mkbootimg=${MKBOOTIMG:?set MKBOOTIMG}
vendor_template_sha=b95c4cae0ebed9162dab49f1bdbdd1daaddc10f86f9d3bf1d9f3a4b5c7530922

test "$(sha256sum "$vendor_template" | cut -d' ' -f1)" = "$vendor_template_sha" || {
    echo "refusing build: vendor_boot_b backup hash is wrong" >&2
    exit 1
}
test "$(stat -c %s "$vendor_template")" = 104857600
test "$(od -An -tx1 -N8 "$vendor_template" | tr -d ' \n')" = 564e4452424f4f54
test "$(tail -c 64 "$vendor_template" | head -c 4)" = AVBf

mkdir -p "$output_dir"

KERNEL_IMAGE="$kernel" \
OUTPUT_IMAGE="$output_dir/boot-mainline-7.1-tb328fu.img" \
BUILD_DIR="$output_dir/initramfs-build" \
MKBOOTIMG="$mkbootimg" \
sh "$repo_dir/kernel/build-diagnostic.sh"

short="$output_dir/vendor_boot.short.img"
python3 "$mkbootimg" \
    --header_version 4 --vendor_boot "$short" \
    --vendor_ramdisk "$vendor_ramdisk" --dtb "$dtb" \
    --vendor_cmdline 'console=ttyS1,115200n8 buildvariant=user' \
    --pagesize 4096 --base 0 --kernel_offset 0x8000 \
    --ramdisk_offset 0x05400000 --tags_offset 0x100 \
    --dtb_offset 0x1f00000

test "$(stat -c %s "$short")" -lt 104857536

vendor_output="$output_dir/vendor_boot-mainline-7.1-tb328fu.img"
cp "$vendor_template" "$vendor_output"
dd if="$short" of="$vendor_output" conv=notrunc status=none

test "$(stat -c %s "$vendor_output")" = 104857600
test "$(tail -c 64 "$vendor_output" | head -c 4)" = AVBf
sha256sum "$output_dir/boot-mainline-7.1-tb328fu.img" "$vendor_output"
