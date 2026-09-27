#!/bin/sh
set -eu

kernel=${KERNEL_IMAGE:?set KERNEL_IMAGE}
stock=${STOCK_UNPACK_DIR:?set STOCK_UNPACK_DIR}
mkbootimg=${MKBOOTIMG:?set MKBOOTIMG to mkbootimg.py}
output=${OUTPUT_IMAGE:?set OUTPUT_IMAGE}
ramdisk=${RAMDISK_IMAGE:-$stock/ramdisk}
cmdline=${KERNEL_CMDLINE:-console=ttyS1,115200n8 buildvariant=user}

test -f "$kernel"
test -f "$ramdisk"
test -f "$stock/dtb"

python3 "$mkbootimg" \
    --header_version 2 --os_version 11.0.0 --os_patch_level 2022-01 \
    --kernel "$kernel" --ramdisk "$ramdisk" --dtb "$stock/dtb" \
    --pagesize 2048 --base 0 --kernel_offset 0x8000 \
    --ramdisk_offset 0x05400000 --second_offset 0 --tags_offset 0x100 \
    --dtb_offset 0x1f00000 --board '' \
    --cmdline "$cmdline" \
    --output "$output"

# Match the 64 MiB BOOT partition image from Lenovo's PAC.
truncate -s 67108864 "$output"
sha256sum "$output" "$kernel" "$ramdisk" "$stock/dtb"
