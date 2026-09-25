# Camera recording bridge

The stock Android-backed Camera recorder can freeze on Start or Stop. A live
`camera_service` trace points to its Android audio recorder waiting for the
missing `media.audio_flinger` service. A device-specific plugin patch disables
Android audio capture and keeps Camera video recording responsive.

[`record-audio-bridge.py`](record-audio-bridge.py) watches Camera's MP4
directory, captures the microphone from PulseAudio while Camera records, then
uses a home-directory GStreamer tool to atomically replace the silent MP4 with
the audio-muxed result. A mux failure leaves the original untouched. On 2026-09-22,
Camera remained responsive and Gallery played both video and voice from the
bridged clip. A second clip's clap was reported roughly in sync when opened
through Files Preview. The new single-file replacement and delayed persistent
services still need a fresh recording test.

The root-owned plugin copy is applied with a bind mount 90 seconds after boot;
the original system file is never overwritten. The microphone bridge runs as
the phablet user. No PINs, personal media or proprietary binaries are in this
directory; installation copies the patch from the owner's tablet after an
exact hash check.
