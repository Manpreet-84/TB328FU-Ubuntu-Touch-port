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

A full-size, header-v4 RAM-only diagnostic container was built and independently
unpacked successfully. It contains the exact kernel and expected init marker:

```text
image  1d04d822c897a8daa0c5ded6feee31299425db9a7795d2cbca3fdd924a336041
kernel 44afeda84fcb0230abf3765bcdb422ee4c3ed7bdf2093d3016fe6e6ae150f08a
ramdisk 93589580a769dd4e65e8405a8b58556ecd637266ba326e6088a35715e74c0f0a
size   67,108,864 bytes
```

The image remains outside Git and has not been sent to or written onto the
tablet. Preserve V96 as rollback; test only with `fastboot boot` when the user
is ready at the device.

## Lenovo 4.14 RAM-only results

The first RAM-only test was accepted by fastboot, then automatically returned
to V96 on slot A. Ubuntu reported no pstore record and the cache partition had
no diagnostic-init marker. Therefore the 4.14 kernel did not reach `/init`.

Patch `0002-tb328fu-earliest-ramoops-marker.patch` applies to Lenovo 4.14 with
only a context offset. A second build confirms `stext` branches to the marker
as its first instruction. Its verified full-size diagnostic hashes are:

```text
image  4c113183fa604cb73b684f40e4c8fcddd1971f781c6bf4c911bdd378492474e3
kernel 35043166459432e1c51b03af51eecd75933d02a41b62045a040f6ff8ff04cbd4
ramdisk 4c8e026de67a80927efc53d1ec9ef14f8c5521b8f898d1870e4d4ef110c7f86f
```

This marker variant has not yet been sent to the tablet. Its RAM-only result
will distinguish bootloader/pre-entry rejection from a later 4.14 boot failure.

Google's `android12-5.4.233_r00` tag builds successfully but is conclusively not
ABI-compatible with the Lenovo modules. A public UMS512 5.4.254 donor is closer and
can build a minimum ARM64 Image, but it is still experimental and not a substitute
for Lenovo's exact source.

Relevant upstream references:

- Lenovo open-source portal: <https://support.lenovo.com/us/en/solutions/ht511330>
- Android common 5.4.233 tag: <https://android.googlesource.com/kernel/common/+/refs/tags/android12-5.4.233_r00>
- UBports porting introduction: <https://docs.ubports.com/en/latest/porting/introduction/Intro.html>
- UBports standalone kernel requirements: <https://docs.ubports.com/en/latest/porting/build_and_boot/standalone_kernel_build.html>

