#!/bin/sh
set -eu

source_dir=${KERNEL_SOURCE:?set KERNEL_SOURCE to Lenovo s000020 kernel4.14}
output_dir=${KERNEL_OUT:?set KERNEL_OUT to a build directory}
clang_dir=${CLANG_DIR:?set CLANG_DIR to Android clang bin directory}

test "$(sed -n 's/^VERSION = //p' "$source_dir/Makefile")" = 4
test "$(sed -n 's/^PATCHLEVEL = //p' "$source_dir/Makefile")" = 14
test "$(sed -n 's/^SUBLEVEL = //p' "$source_dir/Makefile")" = 193
test -x "$clang_dir/clang"

# Lenovo's archive drops the executable bit from this build helper.
chmod +x "$source_dir/arch/arm64/kernel/vdso/gen_vdso_offsets.sh"
mkdir -p "$output_dir"

common="ARCH=arm64 O=$output_dir CC=$clang_dir/clang LD=$clang_dir/ld.lld AR=$clang_dir/llvm-ar NM=$clang_dir/llvm-nm OBJCOPY=$clang_dir/llvm-objcopy OBJDUMP=$clang_dir/llvm-objdump STRIP=$clang_dir/llvm-strip CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu-"

# shellcheck disable=SC2086
make -C "$source_dir" $common sprd_sharkl5Pro_defconfig
# Old vendor code needs warnings demoted and a newer-Clang builtin disabled.
# shellcheck disable=SC2086
make -C "$source_dir" $common KCFLAGS='-Wno-error -fno-builtin-stpcpy' \
    -j"$(getconf _NPROCESSORS_ONLN)" Image

sha256sum "$output_dir/arch/arm64/boot/Image" "$output_dir/.config"
