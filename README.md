# Ubuntu Touch on Lenovo Tab M10 Gen 3 (TB328FU)

Community bring-up notes and safe configuration for the **Lenovo Tab M10 Gen 3
Wi-Fi (TB328FU)**, based on the **Unisoc T610 / UMS512** platform.

The current development system boots **Ubuntu Touch 24.04 with Lomiri** using a
Halium 12 / Android 12 vendor base. The longer-term goal is an
Android-independent Linux userspace and, eventually, a maintainable upstream
kernel port.

> [!WARNING]
> This is an experimental bring-up repository, not an installer. There is no
> public flashable release yet. Do not flash images from other Lenovo M10 models:
> similar product names use unrelated SoCs and board layouts.

## Current status

| Area | Status |
| --- | --- |
| Boot and Lomiri | Working and persistent |
| Display and touchscreen | Working |
| Rotation and rotation lock | Working |
| Manual and automatic brightness | Working |
| Wi-Fi | Working |
| Browser video and local MP4 | Working |
| Charging and battery reporting | Working |
| Speaker, microphone and volume keys | Working through Android audio HAL bridge |
| Rear/front camera and still capture | Working through Android camera HAL |
| Video recording | Working through persistent video-only Camera patch plus microphone mux bridge; Gallery shows one playable H.264/AAC clip |
| Built-in Media Player / Files Preview | H.264/AAC playback working through Qt GStreamer software decoding |
| Suspend | Deep suspend confirmed; attached USB wakes it immediately through MUSB IRQ 58; unplugged test pending |
| Bluetooth | Working post-boot through delayed H4 proxy; discovery, pairing and P2961/AirPods A2DP verified; repeated cold-boot validation remains |
| MTP, Waydroid and long-duration stability | Not validated |

See [STATUS.md](STATUS.md) for evidence and [ROADMAP.md](ROADMAP.md) for the
Android-independent plan.

## Repository contents

- `config/repowerd/config-tb328fu.xml` — tested automatic-brightness profile.
- `config/systemd/tb328fu-no-suspend.service` — temporary Wi-Fi-safe suspend inhibitor.
- `config/kernel/halium.config.fragment` — minimum known Halium kernel delta.
- `bluetooth-fix/` — delayed, boot-detached Unisoc initialization and H4 proxy.
- `docs/minimum-native-boot.md` — safe first native-Ubuntu boot milestone.
- `docs/kernel-source-status.md` — exact-source and ABI findings.
- `docs/kernel-layer-plan.md` — pinned donor, ownership boundary and native-kernel gates.
- `docs/sensor-status.md` — verified physical/virtual sensor inventory and rotation-race plan.
- `docs/known-good-baseline.md` — frozen V96 service state and validation boundary.
- `docs/suspend-status.md` — measured deep-suspend and wake-source evidence.
- `tools/verify-working-state.sh` — read-only camera/Bluetooth/battery health check.
- `kernel/build-donor.sh` — reproducible ARM64 donor-kernel build.
- `kernel/patches/` — small reviewable UMS512/TB328FU patch series.
- `ROADMAP.md` — staged removal of Android userspace dependencies.

## What is intentionally excluded

No SSH keys, credentials, serial numbers, personal files, device captures,
firmware, vendor partitions, proprietary HAL binaries, boot images or recordings
are published here. Stock firmware must come from Lenovo or the owner's own
device, subject to the applicable licences.

## Contributing

Useful contributions include exact TB328FU kernel-source leads, UMS512 driver
work, sanitized hardware logs and reproducible tests. Remove tokens, account
details, device identifiers and private keys before opening an issue or pull
request.

## Licence

Original material in this repository is available under the [MIT License](LICENSE).
Third-party names and referenced hardware data remain the property of their
respective owners.
