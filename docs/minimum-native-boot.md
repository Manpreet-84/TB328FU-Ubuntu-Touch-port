# Minimum native Ubuntu boot

Success for the first native milestone means the tablet starts a Linux kernel and
runs our initramfs `/init` without launching Android. Display acceleration, camera,
audio and Lomiri are deliberately out of scope.

1. Build the UMS512 5.4 donor using the captured TB328FU configuration.
2. Create a small ARM64 initramfs that mounts `/proc`, `/sys` and `/dev`, prints a
   unique banner, and exposes the earliest safe recovery shell.
3. Repack an Android header-v4 test boot image while preserving the verified board
   DTB and vendor-boot layout.
4. Verify headers, hashes, size and initramfs contents off-device.
5. Flash only after preparing and hash-checking the exact working rollback image.

Stop if the image exceeds the partition budget, the target slot is uncertain, or
recovery cannot be demonstrated. Do not modify vbmeta, DTBO, vendor_boot, super or
persistent partitions as part of this experiment.

