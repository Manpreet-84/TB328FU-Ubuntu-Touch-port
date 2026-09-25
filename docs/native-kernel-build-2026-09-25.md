# Native kernel build — 2026-09-25

Clean detached source: `kernel_ums512_5.4` commit
`ead7c4e34de9a1465cb9badd7e0cf56691800b16`.

Build gates passed:

- SC2355 SDIO suspend/resume `power_notify` wiring present.
- Unrelated Omnivision touchscreen disabled; TB328FU uses Himax.
- LTO/CFI disabled for build memory limits.
- Module framework retained because vendor scheduler code requires it;
  `CONFIG_MODVERSIONS` disabled and no Lenovo modules are packaged.
- ARM64 `Image` built with Android Clang 12 (`r416183b`).

Hashes:

```text
Image  a7e21838367db4dec63db017dfc8c5ab759c6389169ab697da9ab3e6934cbe35
config 3dc427f80584cf1dc9cea2bb56df8651afe315e4cf92a8f7fbb1870306361673
diag   2915cd5effc45c3a843fb3bc9404b89770fb10c50c67ba5366ba1c299203ad08
ramdisk 82b0c489a66fdb245a7f5a2260e0918b39d487fb4024b819e55a2cfd8f4f7ca0
V96 rescue 7cd0dfb12a9508c0a90cc882d33140230c78b24744ae438363d9f41ad8e526f8
```

Diagnostic image size: `29,048,832` bytes; partition limit:
`67,108,864` bytes. Header-v4 unpack verification confirmed exact kernel and
`TB328FU_OWN_KERNEL_V2_REACHED_INIT` marker.

At build completion no device partition had been written. Test proceeded only
after backing up and hashing live `boot_b` and confirming bootloader fastboot.

## Slot-B result

Live `boot_b` was backed up at 67,108,864 bytes. Its SHA-256 was
`7cd0dfb12a9508c0a90cc882d33140230c78b24744ae438363d9f41ad8e526f8`,
identical to V96. Diagnostic image was flashed only to `boot_b`; `boot_a`
remained the rollback slot.

Slot B stopped at Lenovo logo. No USB device enumerated. After restoring V96
to `boot_a`, Ubuntu booted on slot A. Both pstore and the cache-partition marker
were empty, proving diagnostic `/init` did not execute. V96 and diagnostic both
use Android boot header v4 with signature size zero, so missing v4 signature is
not the cause.

Failure boundary is before initramfs: bootloader-to-kernel handoff, early kernel
startup, or incompatible board DT/clock/power assumptions. Next test must add an
earlier kernel-side proof or use a closer TB328FU 5.4.233 source; userspace and
Wi-Fi suspend work cannot be tested with this donor yet.

## Earliest-entry test image

Patch `0002-tb328fu-earliest-ramoops-marker.patch` inserts the first branch at
ARM64 `stext`. Before MMU or CPU setup, it writes a valid 29-byte persistent-RAM
console record to the exact Lenovo DT ramoops console zone at `0xfffb0000`, then
cleans that cache line. Marker: `TB328FU_EARLY_HEAD_S_REACHED`.

Disassembly confirms `stext` begins by branching to the marker routine. Updated
Image SHA-256 is
`83ef7c3f78348bcdf89063be6dbcff6deca8e616cdd3efa1fb199f34f8c41e3c`;
verified diagnostic image SHA-256 is
`3bcdf4fc653a991c653fd9f8eeadde782587e3da38a0ef1f27cd2d881e40b6da`.
