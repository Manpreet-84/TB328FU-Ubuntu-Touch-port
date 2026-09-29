# Stock kernel binary analysis — 2026-09-29

## Working references

The original Lenovo Android 12 S200157/S200162 kernel and the kernel inside the
working Ubuntu Touch V96 image are different binaries, but they have the same
embedded 6,402-line configuration and the same exact size:

| Image | Release | Kernel bytes | Kernel SHA-256 |
|---|---|---:|---|
| Lenovo S200157/S200162 | `5.4.233-android12-9-g7f705e12916b` | 37,632,512 | `86016648c6f7ab0a0d709e111b5c974116c40fa852bd86753f8fdeb4b1be221f` |
| Ubuntu Touch V96 | `5.4.233-android12-9-g79e86a50ca56` | 37,632,512 | `23dc040a371cfeb45653d3216cee2f313e54e64ab10faba5572aa4151ce3a652` |

Both were built with Android Clang 12 `r416183b`, full Clang LTO, CFI, CFI
shadow, and ARM64 shadow call stack. V96 proves that boot-header-v4 signature
size zero is accepted by the unlocked device, so a missing v4 signature alone
does not explain donor rejection.

Their PE/COFF metadata is also identical, including `.text` size `0x21ee000`,
EFI entrypoint `0x2020350`, and total PE image size `0x26a0000`. The rebuilt
donor has `.text` size `0x223a000`, entrypoint `0x2070350`, and PE image size
`0x26e9000`. This layout difference is a useful next target if the stock-config
test still fails: remove donor-only built-ins before considering any artificial
padding or entrypoint patching.

## Why the first donor was not a fair comparison

The Halium fragment deliberately disabled LTO/CFI to fit the earlier WSL memory
limit. The resulting public UMS512 5.4.254 kernel was 28,781,056 bytes and its
generated config differed from Lenovo/V96 in 240 entries.

An early EFI framebuffer probe built from that donor was flashed only to
`boot_b`. The tablet remained on the normal Lenovo logo and showed no magenta
probe. V96 was restored on `boot_a`. This is consistent with pre-entry rejection
but is not absolute proof because the firmware may scan out a different
framebuffer address.

## Stock-config-matched donor

The V96 embedded config was used directly, without the Halium fragment. Full
LTO/CFI required about 23 GB peak memory. One compiler-correctness patch was
needed for four Omnivision I2C helpers: initialize their fallback result to
`-EIO`.

```text
Image bytes:   37,888,512
Image SHA256:  1e107f4b2a589a3d63e5216c26a4f76c88341169b1f3e66a79dd3e6ac9f9316a
config SHA256: 2c004957585ddb9f9a901cc0b115a46041f53e13e8ce8d0ca452a6258e6dc94b
boot SHA256:   2ca80e7a66224681a51dc67056b3fe6b1038e069a9b3d4f6123294f1ec237d1c
```

The donor source has different Kconfig symbols from Lenovo's private tree, so
`olddefconfig` still changes 163 entries. Important unmatched areas include
Unisoc display, audio, charging, USB, storage, camera power domains and device
specific input drivers. This image is an entry diagnostic, not a usable
replacement kernel.

## Reproduce

Use the extracted V96 config as `KERNEL_CONFIG` and suppress the normal Halium
fragment by setting `KERNEL_FRAGMENT` to an empty string:

```sh
KERNEL_FRAGMENT= \
KERNEL_SOURCE=/path/to/ums512-5.4 \
KERNEL_OUT=/path/to/out \
KERNEL_CONFIG=/path/to/v96.config \
CLANG_DIR=/path/to/clang-r416183b/bin \
sh kernel/build-donor.sh
```

The next device test is isolated to `boot_b`; V96 remains the rollback image on
`boot_a`. If it reaches diagnostic init, restore missing hardware options in
small groups. If it fails before entry again, matching configuration and LTO
are insufficient and the private Lenovo code/boot contract remains the blocker.

## Device result

The verified stock-config LTO image was flashed only to `boot_b` and slot B was
selected. It remained on the static Lenovo logo with no framebuffer marker,
USB enumeration, diagnostic-init marker or recoverable pstore record. The
verified V96 image was then restored to `boot_a`; Ubuntu returned on kernel
`5.4.233-android12-9-g79e86a50ca56`.

Matching Lenovo's compiler family, LTO/CFI settings and near-stock image size
is therefore insufficient. Do not repeat this image unchanged. Further work
must target the 163 private-tree configuration/source differences or keep the
accepted Lenovo kernel and move the experimental root filesystem to microSD.
