# Android-independent Linux roadmap

## Progress snapshot (2026-09-25)

- Halium/Android-backed Ubuntu Touch daily-driver: about 75–85%.
- Independent kernel with basic hardware: about 25–35%.
- Independent daily-driver: about 10–20%.

These are engineering estimates, not completion claims. Current Ubuntu UI is
usable, but GPU, camera, audio, media, sensors, Wi-Fi and Bluetooth still rely
on Lenovo/Android kernel or vendor components.

## Definition

The first target is native Linux userspace: no LXC Android container, `/android`
mounts, Binder/HIDL services or libhybris clients. Keeping Lenovo's bootloader,
Android boot-image format, a downstream Linux kernel and redistributable firmware
is acceptable initially. A mainline kernel is a separate later milestone.

## Dependency map

| Subsystem | Present Linux interface | Replacement needed |
| --- | --- | --- |
| Touch, keys, backlight | input/sysfs | Reuse directly |
| Storage and USB | block/gadget devices | Native initramfs and root filesystem |
| Display/GPU | no usable DRM node observed | DRM/KMS plus Mesa, or framebuffer first |
| Wi-Fi | `wlan0` works with NetworkManager | Prove operation without Android; package module/firmware |
| Audio | `sprdphone-sc2730` ALSA card | ALSA UCM2 and native PipeWire/PulseAudio routing |
| Sensors | partial input/sysfs exposure | IIO/input drivers and sensorfw configuration |
| Battery/charging | power-supply data available | Validate without Android health/power services |
| Bluetooth | no native HCI controller | Native SDIO/UART HCI transport |
| Video decode | software/browser decode works | Native V4L2 codec driver for acceleration |
| Camera | no `/dev/video*` node observed | V4L2 media-controller/libcamera ISP stack |
| Suspend | kernel enters suspend | Correct MUSB and SC2730 wake masking |

## Milestones

1. **Native shell:** boot a minimal Ubuntu initramfs without starting Android and
   obtain a visible banner plus a recovery shell.
2. **Essential I/O:** bring up storage read-only, console/framebuffer or DRM,
   touch, keys, backlight, battery and charging.
3. **Network and audio:** prove NetworkManager without Android; replace the
   32-bit audio HAL bridge with a minimal native ALSA UCM2 profile.
4. **Graphics and Lomiri:** establish DRM/KMS and Mesa before starting Mir/Lomiri.
5. **Power and sensors:** fix wake IRQs, pass repeated suspend cycles, and expose
   the real sensors through standard Linux interfaces.
6. **Bluetooth, codecs and camera:** implement native transports and media drivers;
   camera remains last because it requires an ISP stack, not another shim.
7. **Mainline:** forward-port the board DT and UMS512 drivers and upstream them in
   small subsystem patches.

## Immediate experiment

Keep known-good V96 in `boot_a`. Build, but do not flash yet, a native
diagnostic image for `boot_b` from the ARM64 initramfs and UMS512 donor kernel.
Include only read-only probes for framebuffer or DRM, input, backlight, ALSA,
power supply, Wi-Fi and USB recovery. Verify boot header, size, contents,
unique diagnostic markers and rollback hashes off-device before flashing.

First kernel target is SC2355 Wi-Fi deep-suspend ordering. Donor source already
places firmware suspend/resume handshake in SDIO `power_notify`, while bus is
alive. Build now checks this invariant. Daily-driver keeps deep sleep inhibited
until native-kernel test proves resume safe.

