# Kernel source status

The running tablet reports:

```text
5.4.233-android12-9-g79e86a50ca56
Android clang 12.0.5 / clang-r416183b
```

Lenovo's available `tb328fu_s000020_220125_row` archive instead contains Linux
4.14.193. It remains useful for board documentation but cannot reproduce the
running kernel.

The official archive was downloaded from Lenovo and verified on 2026-09-26:

```text
URL: https://download.lenovo.com/consumer/mobiles/tb328fu_opensource_tb328fu_s000020_220125_row.tar.gz
size: 1,668,478,591 bytes
sha256: b1011b2829b4e20ed084c7167329881c6162fd982782c6e25640f8f05b520de5
```

Its `kernel4.14/` tree is Linux 4.14.193 and contains native Spreadtrum
`sprd_sharkl5Pro_defconfig`, `ums512-1h10-overlay.dts`, UMS512 SoC/DVFS DTSI,
and associated vendor drivers. Keep the archive outside Git because it is
1.55 GiB compressed and 2.9 GiB for the kernel tree alone.

The native tree builds with Android clang-r416183b after restoring the archive's
missing executable bit on `arch/arm64/kernel/vdso/gen_vdso_offsets.sh` and using
`KCFLAGS='-Wno-error -fno-builtin-stpcpy'` for modern-toolchain compatibility.
The unmodified `sprd_sharkl5Pro_defconfig` Image SHA-256 is
`610c9caf700eab5102551c423b7f575becf8e02a41256d7605cef0b544a467a6`.
Use `kernel/build-lenovo-s000020.sh` to reproduce it.

This defconfig lacks `CONFIG_DEVTMPFS` and framebuffer console support. It is a
device-native boot baseline, not yet an Ubuntu-ready kernel. Add the smallest
Halium/Ubuntu config fragment before producing a RAM-only diagnostic image.

Google's `android12-5.4.233_r00` tag builds successfully but is conclusively not
ABI-compatible with the Lenovo modules. A public UMS512 5.4.254 donor is closer and
can build a minimum ARM64 Image, but it is still experimental and not a substitute
for Lenovo's exact source.

Relevant upstream references:

- Lenovo open-source portal: <https://support.lenovo.com/us/en/solutions/ht511330>
- Android common 5.4.233 tag: <https://android.googlesource.com/kernel/common/+/refs/tags/android12-5.4.233_r00>
- UBports porting introduction: <https://docs.ubports.com/en/latest/porting/introduction/Intro.html>
- UBports standalone kernel requirements: <https://docs.ubports.com/en/latest/porting/build_and_boot/standalone_kernel_build.html>

