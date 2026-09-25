#!/bin/sh
set -eu

base=ead7c4e34de9a1465cb9badd7e0cf56691800b16
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_dir=${KERNEL_SOURCE:?set KERNEL_SOURCE to the UMS512 5.4 checkout}
output_dir=${KERNEL_OUT:?set KERNEL_OUT to an empty build directory}
seed_config=${KERNEL_CONFIG:?set KERNEL_CONFIG to the captured TB328FU config}
clang_dir=${CLANG_DIR:?set CLANG_DIR to Android clang-r416183b/bin}
fragment="$repo_dir/config/kernel/halium.config.fragment"

test "$(git -C "$source_dir" rev-parse HEAD)" = "$base" || {
    echo "wrong kernel revision; expected $base" >&2
    exit 1
}
test -x "$clang_dir/clang" || { echo "clang not found" >&2; exit 1; }
test -f "$seed_config" || { echo "seed config not found" >&2; exit 1; }
"$repo_dir/kernel/verify-wcn-suspend-source.sh" "$source_dir"
mkdir -p "$output_dir"

# Keep the generated kernel identity stable across machines and build dates.
export KBUILD_BUILD_USER=tb328fu
export KBUILD_BUILD_HOST=builder
export KBUILD_BUILD_TIMESTAMP="$(git -C "$source_dir" show -s --format=%cI "$base")"

for patch_file in "$repo_dir"/kernel/patches/*.patch; do
    if git -C "$source_dir" apply --check "$patch_file" 2>/dev/null; then
        git -C "$source_dir" apply "$patch_file"
    elif ! git -C "$source_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
        echo "kernel patch is neither applicable nor already applied: $patch_file" >&2
        exit 1
    fi
done

cp "$seed_config" "$output_dir/.config"
cp "$fragment" "$output_dir/tb328fu-halium.config"
"$source_dir/scripts/kconfig/merge_config.sh" -m -O "$output_dir" \
    "$output_dir/.config" "$output_dir/tb328fu-halium.config"

make -C "$source_dir" O="$output_dir" ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu- \
    CC="$clang_dir/clang" LD="$clang_dir/ld.lld" \
    AR="$clang_dir/llvm-ar" NM="$clang_dir/llvm-nm" \
    OBJCOPY="$clang_dir/llvm-objcopy" OBJDUMP="$clang_dir/llvm-objdump" \
    STRIP="$clang_dir/llvm-strip" olddefconfig
make -C "$source_dir" O="$output_dir" ARCH=arm64 \
    CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu- \
    CC="$clang_dir/clang" LD="$clang_dir/ld.lld" \
    AR="$clang_dir/llvm-ar" NM="$clang_dir/llvm-nm" \
    OBJCOPY="$clang_dir/llvm-objcopy" OBJDUMP="$clang_dir/llvm-objdump" \
    STRIP="$clang_dir/llvm-strip" -j"$(getconf _NPROCESSORS_ONLN)" Image

sha256sum "$output_dir/arch/arm64/boot/Image" "$output_dir/.config"

