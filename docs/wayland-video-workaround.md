# Local video playback workaround (V96 development image)

The stock Lomiri Media Player still fails on local MP4s. On the TB328FU V96
development image, `gst-play-1.0` using software H.264 decoding, `waylandsink`
and `pulsesink` plays both video and audio. Files can hand videos to it through
Lomiri Content Hub. This is a user-space workaround, not a fix for Media Hub or
hardware decoding.

Tested on 2026-09-21 with a four-second H.264/AAC test clip and a camera
recording opened from Files using **Open with another app → Wayland Video
(test)**. The receiver starts playback in a transient user systemd service so
Lomiri suspending the short-lived handler does not stop playback or leave a
stale Content Hub registration.

Files in `media-fix/` are the deployed source. They assume the existing V96
image has GStreamer 1.24.2, the `openh264dec`, `waylandsink` and `pulsesink`
plugins, Python D-Bus bindings, and `gst-play-1.0` unpacked from Ubuntu's
`gstreamer1.0-plugins-base-apps` ARM64 package at
`/home/phablet/media-fix/gst-apps/usr/bin/gst-play-1.0`. The package binary is
not redistributed here. Deploy the two scripts to `/home/phablet/media-fix/`,
the desktop entry to `/home/phablet/.local/share/applications/`, and the JSON
descriptor to
`/home/phablet/.local/share/lomiri-content-hub/tb328fu-wayland-player`.
Make `tb328fu-play` executable. The receiver can be checked with
`python3 tb328fu-content-receiver.py --self-test`.

Known limits: the built-in Preview/Media Player remains broken; zero-byte
camera recordings cannot be played; software decoding uses CPU; this test
player has no touch playback controls. Camera-recorded AAC was measured at
roughly -40 dB RMS. The user confirmed microphone audio is present in camera
recordings played through the workaround.

The native-player failure is narrower than the initial `qtdemux` error
suggested. With software H.264 decoding, `openh264dec` cannot map the pool
proposed by `hybrissink`; the upstream demuxer then reports
`GST_STREAM_ERROR_FAILED`. In an isolated pipeline,
`identity drop-allocation=true` between decoder and sink avoids that error.
A temporary Media Hub bridge produced working audio and end-of-file, but still
no visible video, and was rolled back. The [upstream Hybris sink source](https://gitlab.com/ubports/development/core/hybris-support/gst-hybris/-/blob/main/plugin/src/hybris/gsthybrissink.c)
shows why: frames not originating in its own pool enter a copy branch whose
actual copy is disabled. The [pool release code](https://gitlab.com/ubports/development/core/hybris-support/gst-hybris/-/blob/main/plugin/src/mir/mirpool.c)
renders by releasing a MediaCodec output buffer; software frames have no such
decoder delegate. Adding `videoconvert` before the sink did not make frames
originate in that pool. Native Media Player video therefore needs a different
software-frame rendering path, not just a decoder-rank or allocation tweak.

The only enumerated Hybris H.264 decoder on this image is
`amcviddec-c2unisocavcdecoder`. An isolated test and a Media Hub core dump
both crash while `gst_amc_codec_get_input_buffers()` calls into Android
`MediaCodecBuffer::data()`. The current libhybris wrapper dereferences every
entry returned by `getInputBuffers()` without checking for a null entry. A
null guard could prevent the crash, but would not by itself supply the input
buffers needed for playback. A real hardware-decoder fix must adapt the
libhybris/GStreamer codec path to this Android 12 C2 implementation and be
tested with the actual Hybris display surface.

Files' **Preview** action sends a `video://` URL to the system URL dispatcher,
which launches the native Media Player. **Open with another app** instead uses
Content Hub and can select Wayland Video. A second user-level `video://` handler
would conflict with the existing system handler rather than reliably replace
it, so this workaround deliberately keeps the explicit Content Hub choice.
