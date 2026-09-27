# TB328FU S000027 boot layout

The Lenovo Android 11 S000027 ROW PAC is the correct reference for the public
Linux 4.14.193 source. It uses an Android boot image v2, not the Android 12
boot-v4 plus `vendor_boot` layout used by the current V96 base.

## Provenance

```text
archive: TB328FU_S000027_220301_ROW.zip
MD5:     abdfc094dce28c402a92aace61322f93
SHA256:  a21b06c813294a0ca045695700b099b4c6bb91500c22c7575bf0207d40d028e3
PAC:     ums512_1h10_Natv_Tablet-user-gms_SHARKL5PRO_SUPER_TABLET_R.pac
```

The old `divinebird/pacextractor` produced invalid offsets for this PAC. The
Unisoc Perl unpacker mirrored by `NasdaqGodzilla/UNISOC_SPRD_PAC_UNPAC`
extracted a valid image with `ANDROID!` at offset zero.

## Verified stock boot image

```text
size:           67,108,864 bytes
SHA256:         40a0cd9c3cd71526bd00290a25571e50f97ad13e07a5c0fc6d008a90c4ca3b12
header:         Android boot image v2
page size:      2048
kernel:         19,351,568 bytes at 0x8000
ramdisk:        12,150,958 bytes at 0x05400000
DTB:            154,035 bytes at 0x01f00000
cmdline:        console=ttyS1,115200n8 buildvariant=user
OS/patch:       Android 11 / 2022-01
kernel SHA256:  aaf75680d7c294eba10bb8ff8b4abbdddcb0a3dca662106bfdc6d4476542a451
ramdisk SHA256: a3e9f8cbdd35743f4ac2bccf83ad96de10f24a4453acd2120b27506423241266
kernel release: 4.14.193+-ab230
```

The DTB has a 64-byte Unisoc wrapper followed by a normal FDT. Its payload
identifies `Unisoc UMS512 SoC` / `sprd,ums512`. The PAC contains no
`vendor_boot` partition.

Repacking the extracted stock kernel, ramdisk, and wrapped DTB with AOSP
`mkbootimg.py` reproduced the first 31,664,128 bytes exactly. The rest of the
64 MiB PAC image is padding. This proves the parameters in
`kernel/build-s000027-v2.sh`.

The config embedded in the stock kernel has `CONFIG_EFI` disabled. Therefore
the earlier EFI-stub theory came from mixing the Android 12 v4 container with
the Android 11 kernel and is not a valid requirement for this 4.14 path.

Building the clean S000020 source with the extracted S000027 config succeeds:

```text
Image size:   19,417,104 bytes
Image SHA256: 7def3859033a83f4fd12bccf8da8a6829c30d919b3b26f8133e85a5d395883fc
```

That is only 65,536 bytes larger than the S000027 binary. The next safe test is
a RAM-only `fastboot boot` using this kernel, the exact stock wrapped DTB, and
the v2 container. Do not flash it until RAM boot reaches the diagnostic init.
Set `RAMDISK_IMAGE` and `KERNEL_CMDLINE` when running the build script to make
that diagnostic variant; otherwise it preserves the stock ramdisk and cmdline.

## RAM-boot result on the upgraded bootloader

Both the rebuilt 4.14 diagnostic image and Lenovo's untouched 64 MiB S000027
`boot.img` were accepted by `fastboot boot`, then returned to fastboot without
starting ADB. The untouched-image control proves this is not caused by our
kernel build or repacking. The bootloader currently installed with the Android
12/V96 base no longer boots the old v2 path as the S000027 bootloader did.

Consequently, v2 is valuable as the matching 4.14 source/DTB reference but is
not directly bootable under the current firmware. Further tests must retain the
current v4 boot contract or deliberately restore the complete matching Android
11 boot-chain firmware; do not mix only the old boot image into the upgraded
chain.
