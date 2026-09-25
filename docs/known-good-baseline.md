# Known-good V96 baseline

Captured 2026-09-25 without rebooting or modifying the tablet.

- Kernel: `5.4.233-android12-9-g79e86a50ca56`.
- Ubuntu root: persistent `ubuntu_b` system image, booted from Android slot A.
- Observed uptime: more than 37 hours.
- Camera video patch: active bind mount from `/etc/writable/tb328fu-camera`.
- Camera microphone bridge: enabled user service; latest observed recording was
  muxed successfully in place and confirmed by the owner in Gallery.
- Bluetooth: delayed service active for more than 31 hours; discovery, pairing
  and A2DP output confirmed with P2961 and AirPods Pro.
- Bluetooth files installed on the tablet match the repository copies by SHA-256.
- Cold-boot Bluetooth node creation was repaired using sysfs major/minor data.
- Deep sleep is temporarily inhibited to keep Wi-Fi working until kernel resume
  ordering is fixed.

Run the read-only health check on the tablet:

```sh
sudo sh tools/verify-working-state.sh
```

Remaining validation: repeated cold boots, suspend/resume and failure recovery.
Do not alter V96 boot, vendor_boot, DTBO or vbmeta during these tests.
