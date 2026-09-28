#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
source_dir=${KERNEL_SOURCE:?set KERNEL_SOURCE to linux-mainline-sprd}
output_dir=${KERNEL_OUT:?set KERNEL_OUT}
cross=${CROSS_COMPILE:-aarch64-linux-gnu-}

test -f "$source_dir/Makefile"
test -x "$(command -v "${cross}gcc")"

cp "$repo_dir/kernel/mainline/ums512-tb328fu.dts" \
    "$source_dir/arch/arm64/boot/dts/sprd/ums512-tb328fu.dts"

for patch_file in "$repo_dir"/kernel/mainline/patches/*.patch; do
    if git -C "$source_dir" apply --check "$patch_file" 2>/dev/null; then
        git -C "$source_dir" apply "$patch_file"
    elif ! git -C "$source_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
        echo "mainline patch is neither applicable nor already applied: $patch_file" >&2
        exit 1
    fi
done

make -C "$source_dir" O="$output_dir" ARCH=arm64 \
    CROSS_COMPILE="$cross" defconfig
"$source_dir/scripts/config" --file "$output_dir/.config" \
    --enable DRM \
    --enable DRM_SPRD \
    --enable DRM_FBDEV_EMULATION \
    --enable BACKLIGHT_CLASS_DEVICE \
    --enable DRM_PANEL_GENERIC_DSI \
    --enable TOUCHSCREEN_HIMAX_HX83112B \
    --enable CHARGER_BQ256XX \
    --enable DRM_PANEL_HIMAX_HX83102
make -C "$source_dir" O="$output_dir" ARCH=arm64 \
    CROSS_COMPILE="$cross" olddefconfig
make -C "$source_dir" O="$output_dir" ARCH=arm64 \
    CROSS_COMPILE="$cross" -j"$(getconf _NPROCESSORS_ONLN)" \
    Image sprd/ums512-tb328fu.dtb

sha256sum \
    "$output_dir/arch/arm64/boot/Image" \
    "$output_dir/arch/arm64/boot/dts/sprd/ums512-tb328fu.dtb"
