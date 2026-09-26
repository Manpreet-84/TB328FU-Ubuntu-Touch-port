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

The smallest Halium/Ubuntu fragment also builds successfully. Set
`HALIUM_FRAGMENT=config/kernel/halium.config.fragment` when invoking the build
script. Its Image is 23,255,056 bytes with SHA-256
`44afeda84fcb0230abf3765bcdb422ee4c3ed7bdf2093d3016fe6e6ae150f08a`.
The resulting config enables namespaces, cgroup devices, devtmpfs, and tmpfs
xattrs. This 4.14 tree has no `CONFIG_MMC_SDHCI_SPRD` symbol; its native
`CONFIG_MMC_SPRD_SDHCR11=y` storage driver remains enabled instead.

This remains a device-native diagnostic baseline, not a replacement for the
running Lenovo Android 12 kernel. First boot test must be RAM-only and needs a
matching diagnostic initramfs; do not flash it directly.

Google's `android12-5.4.233_r00` tag builds successfully but is conclusively not
ABI-compatible with the Lenovo modules. A public UMS512 5.4.254 donor is closer and
can build a minimum ARM64 Image, but it is still experimental and not a substitute
for Lenovo's exact source.

Relevant upstream references:

- Lenovo open-source portal: <https://support.lenovo.com/us/en/solutions/ht511330>
- Android common 5.4.233 tag: <https://android.googlesource.com/kernel/common/+/refs/tags/android12-5.4.233_r00>
- UBports porting introduction: <https://docs.ubports.com/en/latest/porting/introduction/Intro.html>
- UBports standalone kernel requirements: <https://docs.ubports.com/en/latest/porting/build_and_boot/standalone_kernel_build.html>

