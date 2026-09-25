# TB328FU kernel layer

The long-term port will ship a complete Linux kernel, not a module layered over
Lenovo's binary kernel.  Our maintained layer consists of a pinned UMS512 base,
TB328FU configuration and device-tree data, small reviewable patches, an
initramfs, and packaging metadata.

## Baseline

- Base: `marohinmark/kernel_ums512_5.4` at
  `ead7c4e34de9a1465cb9badd7e0cf56691800b16` (Linux 5.4.254).
- Compiler: Android clang `r416183b`, matching the compiler family reported by
  the Lenovo 5.4.233 kernel.
- Reproducible v1 build: 28,133,888-byte ARM64 `Image`, SHA-256
  `3a1496ad1157f62dcc0f481a5ab4bc80df76b03c452dac683f3fe9b938cd1678`.
- Merged config SHA-256:
  `00b07e1d49d50e204d7262e81ed11b80f5ac1f6fdaa9a1db86639a1e789cf34a`.
- The build already enables devtmpfs, namespaces, cgroups, Binder, DRM and the
  UMS512 MUSB/PHY path.

This base is useful because it contains Unisoc platform code missing from
Google's generic Android 5.4 tree.  It is still a donor: it is not Lenovo's
missing source and is not ABI-compatible with Lenovo's binary modules.

## Ownership boundary

| Component | Source | Repository policy |
| --- | --- | --- |
| Kernel base | Pinned public UMS512 tree | Record commit; do not vendor entire tree |
| Build fixes and TB328FU quirks | Our patch series | Public |
| Halium config delta | `config/kernel/halium.config.fragment` | Public |
| TB328FU DT description | Reconstructed from live DT and verified hardware | Public after review |
| Initramfs/build scripts | This repository | Public |
| Radio, Wi-Fi, Bluetooth and camera firmware | Extracted from owner's tablet | Never commit; stage locally |
| Keys, partition dumps and personal data | Owner's backup | Never commit |

## Bring-up gates

1. **Reproducible kernel:** rebuild the pinned donor and match the recorded
   `Image` hash before adding further changes.
2. **Kernel-owned shell:** boot our kernel and initramfs, preserving the V96
   rollback image.  Success means `/init` runs and writes a unique pstore log.
3. **Board essentials:** storage, USB gadget, buttons, touch, regulators,
   charging and display.  Add only DT nodes confirmed from the live Lenovo DT.
4. **Daily-driver hardware:** Wi-Fi, audio, sensors, suspend/resume and
   Bluetooth.  Port public UMS512 drivers into our tree instead of loading them
   into Lenovo's ABI-incompatible kernel.
5. **Multimedia:** GPU/display acceleration, codecs and cameras.  Firmware may
   be staged during installation but remains outside the public repository.
6. **Ubuntu Touch packaging:** produce a repeatable boot image and installer,
   then run reboot, suspend, charging and recovery tests before calling it
   stable.

No image from this track is flashed until an offline verifier confirms its
header, size, kernel hash, initramfs marker and exact V96 rollback image.

