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

No device partition was written. Before any slot-B test, back up live `boot_b`,
hash it, confirm bootloader fastboot and current slot, then re-check rollback.
