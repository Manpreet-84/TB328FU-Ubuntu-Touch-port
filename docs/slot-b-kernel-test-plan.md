# Slot B kernel test plan

## Current truth

- `boot_a` contains the known-good Ubuntu Touch V96 boot image.
- Slot A is the daily-driver and rescue target. Do not overwrite it.
- `boot_b` is an alternate kernel/ramdisk partition, not the Android system.
- Ubuntu still requires Android/Halium vendor userspace and firmware for GPU,
  camera, audio, codecs, sensors, Wi-Fi, and Bluetooth.

## Native-kernel experiment

The public UMS512 5.4 donor can be tested in `boot_b` only after all gates pass:

1. Back up `boot_b` and record its size and SHA-256.
2. Rebuild the donor reproducibly from commit
   `ead7c4e34de9a1465cb9badd7e0cf56691800b16`.
3. Pass `kernel/verify-wcn-suspend-source.sh` and the diagnostic-image checks.
4. Include a unique initramfs marker and forced-panic/pstore evidence path.
5. Confirm boot image header, partition-size limit, and rollback image hashes.
6. Flash only `boot_b`, select B for one test, and keep V96 in `boot_a`.

The first experiment is a diagnostic kernel plus initramfs shell. It is not a
full Ubuntu replacement. A full boot comes later, after display, storage, USB,
and Android-vendor ABI compatibility are proved.

## First kernel target

Wi-Fi deep-suspend ordering. The donor source already contains the desired
design: SC2355 registers `sdio_suspend_resume_handle` as the TX-command
channel's `power_notify`, and the SDIO transport calls it while the bus is
alive from `sdiohal_suspend()`/`sdiohal_resume()`.

Until a native test kernel passes, keep `tb328fu-no-suspend.service` enabled on
the daily-driver system so Wi-Fi remains recoverable without rebooting.
