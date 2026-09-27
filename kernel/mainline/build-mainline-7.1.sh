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

make -C "$source_dir" O="$output_dir" ARCH=arm64 \
    CROSS_COMPILE="$cross" defconfig
make -C "$source_dir" O="$output_dir" ARCH=arm64 \
    CROSS_COMPILE="$cross" -j"$(getconf _NPROCESSORS_ONLN)" \
    Image sprd/ums512-tb328fu.dtb

sha256sum \
    "$output_dir/arch/arm64/boot/Image" \
    "$output_dir/arch/arm64/boot/dts/sprd/ums512-tb328fu.dtb"
