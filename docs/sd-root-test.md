# SD root test — 2026-09-29

Confirmed boot on slot B using the unchanged V96 kernel and an Ubuntu Touch
24.04.4 rootfs directory copied to ext4 microSD. Persistent boot probe reports:

```text
SD probe starting
Device=179:1 UUID=f24eab58-441e-4a6a-8021-6af03a1cf209
SD ROOT SELECTED
```

ADB returned, slot suffix was `_b`, kernel was
`5.4.233-android12-9-g79e86a50ca56`, and lightdm was active.
Visual UI behavior still requires user observation.

This moves the base rootfs to SD, not the kernel, user data, or Android hardware
support. The existing internal userdata overlay remains active; `df /` reports
its capacity. The lower SD mount may not appear separately after switch-root.
The earlier inference of internal fallback based on its absence was unsupported.

`kernel/prepare-sd-initrd.py` patches an extracted V96 initrd and installs
`kernel/sd-root.sh`. The helper checks the specific card UUID, mounts ext4
read-only, and binds its `rootfs` directory before the original V96 overlay
setup. Failure falls through to the original internal root mount.
The persistent probe is `/userdata/sd-root-probe.log`.

Slot A retains V96. No SD-absent fallback test or repeated cold-boot validation
has been performed yet. This is not an independent custom-kernel boot.

## Cold-start failure (2026-09-29)

After shutdown and power-on, slot B stayed at the Lenovo logo. Switching to
slot A also stayed at the logo until the verified V96 image was flashed back to
`boot_a` (SHA-256 `fa0655e8dc00ca2ff69bdb314094058f35a069267d1d3910a5ffbabfe4302486`).
Ubuntu then booted on slot A with ADB, the V96 kernel, and active LightDM.
The previous SD probe log still says `SD ROOT SELECTED`, but it was written
during the earlier successful warm boot; it does not prove the cold boot
reached the SD probe. No journal entry exists for the failed cold start.
Treat the SD boot image as warm-boot-only until early boot evidence explains
the cold-start failure. Do not set slot B active for normal use.

## Full-partition image test

The failed SD test image and the V96 recovery flash were both 43,913,216-byte
short images. The saved V96 `boot_a` partition is 67,108,864 bytes, and its
first 43,913,216 bytes exactly match the short V96 image. Its final 64 bytes
start with the `AVBf` footer magic. A short flash leaves the previous partition
tail/footer in place. This is a plausible cause of the cold-start failure,
not yet proof of bootloader behavior.

On 2026-09-29 the full V96 `boot_a` backup (SHA-256
`7cd0dfb12a9508c0a90cc882d33140230c78b24744ae438363d9f41ad8e526f8`)
was flashed to A. Ubuntu booted, and the owner confirmed one subsequent cold
start reached Ubuntu. A second cold start is pending confirmation.

An unflashed `out/tb328fu-v96-sd-root-full.img` was built by copying the full
V96 backup and overwriting only the initial 43,913,216 bytes with the SD test
image. It is exactly 67,108,864 bytes, its prefix matches the SD test image,
and its final 64 bytes retain `AVBf`. This image is experimental and has not
been tested on the tablet.
