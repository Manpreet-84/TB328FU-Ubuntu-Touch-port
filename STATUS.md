# Port status

Updated: 2026-09-25

## Latest verified baseline

The 2026-09-25 live audit supersedes older experimental notes below:

- V96 had remained up for more than 37 hours.
- Persistent Camera video patch and user microphone bridge were active.
- Camera recording starts/stops responsively; Gallery shows one final clip with
  thumbnail, video and sound. The bridge replaces the silent intermediate, so
  Gallery no longer shows duplicate recordings.
- Delayed Bluetooth proxy was active for more than 31 hours. Discovery,
  pairing and A2DP playback work with P2961 and AirPods Pro.
- Installed Bluetooth scripts and units match repository copies by SHA-256.
- First reboot exposed missing `/dev/ttyBT0` despite registered sysfs tty. The
  launcher now creates the node from sysfs major/minor; Bluetooth then started,
  powered `hci0`, and remained outside the boot-critical path.
- Temporary `tb328fu-no-suspend.service` blocks deep sleep because SC2355 Wi-Fi
  cannot resume. Screen blanking/locking remains available.
- Repeated cold-boot testing remains required before release.
- Deep suspend itself works. A controlled attached-USB test resumed in about
  one second, and kernel logs identified MUSB IRQ 58 as the exact wake source.
  Unplugged deep suspend wakes correctly from power-key IRQ 74, and all
  camera/Bluetooth services survive. Wi-Fi does not: vendor SC2355 resumes
  with `hif->exit`, so scans fail until reboot. See `docs/suspend-status.md`.

See [known-good baseline](docs/known-good-baseline.md).

## Device

- Lenovo Tab M10 Gen 3 Wi-Fi, model TB328FU.
- Unisoc T610 / UMS512 platform.
- Stock base: Android 12, VNDK 31, Linux 5.4.233.
- Android boot header v4 with A/B dynamic partitions and Virtual A/B.

## Working Ubuntu Touch reference

The current V96 development image boots Ubuntu Touch 24.04 and Lomiri with
persistent home and NetworkManager data. The image itself is not distributed
because it contains or depends on proprietary vendor material.

Confirmed working:

- display, touchscreen and tablet-scaled Lomiri UI;
- application/shell rotation and rotation lock;
- manual and automatic brightness;
- Wi-Fi, browser rendering, YouTube and local MP4 playback in Morph;
- charging and battery reporting;
- speaker output, microphone recording and gradual hardware volume control;
- rear/front camera preview and still capture; a persistent video-only Camera
  patch records and stops without freezing. A user-session microphone bridge
  captures PulseAudio and atomically replaces the silent intermediate with one
  H.264/AAC MP4 that plays with voice and thumbnail in Gallery;
- H.264/AAC local video and audio in built-in Files Preview / Media Player,
  including a camera recording, using the Qt GStreamer backend with software
  H.264 decoding; Gallery also indexes and plays valid camera MP4s using
  software-decoder overrides for its scanner and thumbnail helpers
  (see [playback fix](docs/native-media-player.md));
- developer shell and persistent user data.
- experimental Bluetooth HCI controller registration through a userspace
  proxy for the Unisoc UART; P2961 headphones paired and A2DP playback worked
  in a live RAM-only vendor-initialization test on 2026-09-22.

On 2026-09-22, `bluetoothctl` saw nearby devices and `hci0` powered on.
Windows on the user's PC could see the tablet, but Add device failed or hung
at Connecting. Neither BlueZ nor the controller proxy reported a completed
pairing; no paired device appeared on either Bluetooth stack. A `btmon` trace
confirmed the controller accepts inquiry/page-scan enable with HCI success,
but did not capture an incoming connection attempt during the Windows test.
The PC itself did not appear in the tablet's scan. This leaves pairing
unresolved; do not describe Bluetooth as connected or audio-capable. Tablet
discoverability was turned back off after the test, while the HCI proxy and
Bluetooth service remained running.

Later on 2026-09-22, the user put P2961 headphones into red/blue pairing mode.
The tablet received their BR/EDR extended inquiry result as P2961 at
`41:42:A5:1C:F9:77` with RSSI around -44 to -49 dBm. A clean `bluetoothctl`
session stopped discovery before pairing, but returned
`org.bluez.Error.ConnectionAttemptFailed`. The controller's HCI Connection
Complete event gave status `0x04` (page timeout). A separate low-level
`hcitool cc` attempt failed with the same `0x04`, before authentication or any
audio profile negotiation. No ACL packets or successful bonds were observed.
This points to a controller/baseband connection problem, not a PulseAudio/A2DP
configuration issue, although its exact firmware/transport cause is unproven.
No Bluetooth proxy or firmware changes were made during these tests.
Read-only inspection found the stock Android `libbt-vendor.so` exposes
`marlin3_lite_init`, RF and PSKEY preload functions and uses the vendor
`bt_configure_rf*.ini` / `bt_configure_pskey*.ini` files. The current Linux
HCI proxy attaches `/dev/ttyBT0` but does not perform that Android vendor
initialization. Missing controller initialization is a plausible explanation
for inquiry working while ACL paging times out, but has not been proven; do
not send guessed vendor-specific HCI commands or alter the working boot path.

Later that day, the Android vendor library's exact initialization payload
layout and opcodes were traced and packed from the installed Lenovo INI files
by `research/TB328FU-Ubuntu-Touch-prep-20260902/bt-pack-ini.py`. The
RAM-only `bt-vendor-init-test.py` sent PSKEY (0xfca0), RF (0xfca2), core
enable (0xfca1), and HCI reset; all returned HCI success. The controller then
reported its provisioned address `40:45:DA:D8:31:D5` instead of the default
`27:93:31:14:22:11`. BlueZ successfully paired/bonded with P2961, proving
the earlier page timeout was due to missing vendor initialization. It then
could not connect A2DP because PulseAudio's Bluetooth module was not loaded.
The custom 32-bit PulseAudio chroot lacked `/run/dbus`; a temporary bind mount
of the host `/run/dbus` let `module-bluetooth-discover` load. BlueZ connected,
PulseAudio created `bluez_sink.41_42_A5_1C_F9_77.a2dp_sink`, and the user
heard the test voice prompt in P2961. The headphones are paired/trusted, but
the vendor init was not yet integrated into startup, so Bluetooth audio did
not yet survive a reboot. No boot image was modified during that live test.

The PulseAudio half was subsequently made persistent: its chroot now bind
mounts `/run/dbus`, loads `module-bluetooth-discover`, and orders the audio
service after `bluetooth.service`. This survived reboot and preserved the
normal speaker/microphone card. Do not add the one-shot vendor initializer as
an `ExecStartPre` of `tb328fu-bt.service`: testing proved that opening the
Unisoc UART can enter an uninterruptible kernel wait and block the Ubuntu boot
target at the Lenovo logo. A v96 recovery image with
`systemd.mask=tb328fu-bt.service` was used to regain Ubuntu, the pre-start was
removed, and the original verified v96 boot image was restored. A subsequent
normal v96 boot succeeded with the original HCI proxy and all three services
active. The vendor initializer and cached MAC remain renamed `.disabled` on
the tablet. Permanent controller initialization must be detached from the boot
critical path and must have an externally enforceable timeout/recovery path.

Further isolation testing showed that starting the vendor initializer manually
after Ubuntu had been up for several minutes could still block in an
uninterruptible `/dev/ttyBT0` open unless the controller had first been power
cycled. The HCI proxy was therefore disabled from automatic startup; normal
v96 boot was confirmed again with Ubuntu usable. During this work the
orientation channel temporarily stopped updating even though `sensorfwd` and
the Android sensors HAL were active. Restarting those processes did not recover
it, but a clean boot with the Bluetooth service disabled restored automatic
rotation. Treat sensor-hub recovery and Bluetooth RF power sequencing as
separate stability issues.

A later post-boot RF-reset experiment narrowed this further. Writing `0` to
the Bluetooth rfkill state blocks in the vendor kernel for about 31 seconds
inside `stop_marlin(MARLIN_BLUETOOTH)`, then completes; power-on returns
quickly. Even after that reset, a cold one-shot `0xfca0` PSKEY command produced
no completion and the tty driver logged payload bytes as unknown H4 heads. The
initializer eventually failed once (automatic retry is now disabled), closed
the tty after the same slow power-off, and left Ubuntu, audio, and rotation
working. This indicates that the earlier successful userspace injection had
inherited transport/controller state from an already-attached HCI proxy; RF
power cycling alone is insufficient for a reproducible cold start.

On 2026-09-23 the cold-start failure was root-caused in userspace: both the H4
proxy and one-shot initializer opened `/dev/ttyBT0` without putting the actual
vendor tty into raw mode. Terminal processing transformed binary HCI bytes;
the kernel's `unknown head` trace contained caret/control-byte expansions.
Applying raw mode and flushing the tty before traffic made PSKEY (`0xfca0`), RF
configuration (`0xfca2`), sleep configuration (`0xfca1`) and HCI Reset
(`0x0c03`) all complete with status `0x00`. The controller then reported its
stored address `40:45:DA:D8:31:D5` instead of fallback `27:93:31:14:22:11`.
P2961 and AirPods Pro were paired; the AirPods produced confirmed stereo A2DP
audio. A persistent service and a separate two-minute delayed timer are now
installed. The service is not part of the boot target, never toggles rfkill,
has no restart loop and fails closed when prerequisites are absent. Its exact
persistent copy completed initialization and brought `hci0` UP with zero
errors. A real cold-boot validation is still required before this is marked
fully stable.

The clean permanent direction is a native HCI driver over the Unisoc SDIO WCN
channels, not increasingly complex boot-time userspace sequencing. A related
UMS512 implementation (`btsprd_hci.c` plus `btsprd_ini.c`) already demonstrates
the required design: register `hci0` directly, use channels 3/17, make PSKEY the
first command, then send RF, enable, and reset. Adapting that code remains
blocked by the missing exact Lenovo 5.4.233 kernel source/module ABI. Until
then, keep `tb328fu-bt.service` disabled and one-shot (`Restart=no`).

The native reference was subsequently ported far enough to compile against
the closest public Android 12 5.4.233 tree with the exact running-kernel
vermagic. It was intentionally not loaded: Lenovo modules require
`module_layout` CRC `2f279e7b`, while the public-tree build produces
`2b55ad43`; `request_firmware`, `release_firmware`, and `nvmem_cell_get` CRCs
also differ. This confirms that an external module cannot safely cross the
current ABI gap. The build and symbol evidence are preserved in the private
research tree's `native-bt-module/README.md`.

The separate Wayland test player also works, but is no longer required for
ordinary Files playback. Neither path fixes the underlying hardware codec.
Stock Camera video-mode freezing is under investigation. A valid MP4 may be
written even when the UI hangs on Stop. Do not treat stock recording as reliable.
The Start freeze has been traced to a synchronous `android_recorder_start()`
call in `AalMediaRecorderControl::startRecording()`. In one Stop freeze,
`android_recorder_stop()` and `android_recorder_reset()` returned and the MP4
was finalized, but `android_recorder_release()` blocked. A RAM-only test of
48 kHz mono recorder settings (matching the microphone feed) did not eliminate
the Stop freeze. A second RAM-only test omitting reset before release also
froze on Stop. A later stock-state freeze confirmed the same release call as
the blocking point. All camera tweaks disappear on reboot; none is a
confirmed fix.

A live `debuggerd -b` trace of Android `camera_service` showed the recorder
main thread blocked in `StagefrightRecorder::createAudioSource()` /
`AudioRecord::createRecord_l()` / `AudioSystem::get_camera_record_service()`;
a Binder thread doing `MediaRecorderClient::release()` was blocked in
`AudioRecord::~AudioRecord()` / `AudioSystem::releaseAudioSessionId()` /
`AudioSystem::get_audio_flinger()`. Android lists `media.audio_policy` but no
`media.audio_flinger` service. The RAM-only patch that skips Android audio
capture eliminates the Camera Start/Stop freeze, isolating the fault to the
Android audio-recorder path. The Ubuntu PulseAudio bridge in
[`camera-fix/record-audio-bridge.py`](camera-fix/record-audio-bridge.py)
captures the mic, AAC-encodes it with GStreamer, and creates a separate
`-with-audio.mp4` without altering the video-only original. One live test on
2026-09-22 confirmed responsive Camera and video plus voice in native Gallery.
A second clap test played with sound in Files Preview and was reported roughly
in sync. Gallery shows both the original silent clip and the `-with-audio` copy
without filenames, so selecting the silent copy is easy. The bridge and patch
are experimental, manually started, and not enabled at boot. A permanent fix
still requires replacing or restoring Android recorder audio integration and
repeat testing.

## Current blockers

1. Lenovo's published TB328FU source contains Linux 4.14.193, while the installed
   firmware uses a Lenovo-modified 5.4.233 kernel.
2. Google's public Android 5.4.233 tree is not module-ABI compatible with the
   Lenovo kernel: 2,924 of 6,642 imported symbol CRCs conflict and 411 imports
   are absent.
3. The closer UMS512 5.4.254 donor builds, but is not yet proven compatible with
   this board and its vendor modules.
4. Native DRM/KMS, ALSA routing, sensor IIO, Bluetooth HCI, V4L2 codecs and camera
   ISP support are required to remove the Android runtime.
5. Deep suspend starts, but USB MUSB IRQ 58 and an SC2730 PMIC parent IRQ can wake
   the device immediately.

## Independent-kernel phase (2026-09-25)

Work has entered preparation for isolated native-kernel testing. `boot_a` is
the known-good Ubuntu Touch V96 rescue/daily-driver and must remain untouched.
`boot_b` is an alternate kernel/ramdisk slot—not an Android system partition—
and is the planned diagnostic test slot after its current contents are backed
up and hashed.

The UMS512 5.4 donor already contains the desired SC2355 suspend architecture:
Wi-Fi registers `sdio_suspend_resume_handle` on the TX-command channel and the
SDIO PM callbacks invoke it before transport shutdown and after wake. The donor
build now rejects source trees missing that wiring. First boot will test only a
diagnostic kernel/initramfs shell; it will not replace Android vendor services
or promise a full Ubuntu UI.

See [`docs/slot-b-kernel-test-plan.md`](docs/slot-b-kernel-test-plan.md).

The first isolated slot-B donor test completed on 2026-09-25. It stopped at the
Lenovo logo with no USB enumeration. Recovery to V96 slot A succeeded after
reflashing the verified image. Pstore contained no record and the diagnostic
cache marker was absent, so initramfs `/init` never ran. Boot header version and
v4 signature size match V96. Current boundary is pre-userspace: early donor
kernel/board-DT compatibility or bootloader handoff.

## Sensor facts

Lenovo specifies accelerometer, ambient light, Hall-cover and proximity sensors.
No physical vibration motor, gyroscope or compass should be assumed merely because
the downstream kernel exposes generic nodes.

## Safety

- Keep a verified rollback image and recovery slot.
- Never flash guessed DTBO, vendor_boot, vbmeta or super images.
- Never use another M10 model's image based only on the marketing name.
- Verify the active slot and image hashes before every write.
