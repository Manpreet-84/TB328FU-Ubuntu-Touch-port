# Built-in Media Player playback

On the TB328FU V96 image, Lomiri Media Player defaults to Qt's Android/AAL
backend. Local H.264/AAC files can play audio with a black video frame.
The already-installed Qt GStreamer backend plays both picture and sound with
software H.264 decoding. This retains the built-in Media Player and Files
Preview interface; it does not use the separate Wayland test player.

The user-level launcher override confirmed on the tablet is
[`media-fix/lomiri-mediaplayer-app.desktop`](../media-fix/lomiri-mediaplayer-app.desktop).
Its only changed line is:

```ini
Exec=env QT_MULTIMEDIA_PREFERRED_PLUGINS=gstreamer GST_PLUGIN_FEATURE_RANK=amcviddec-c2unisocavcdecoder:0,openh264dec:3000 lomiri-mediaplayer-app %u
```

Install it as `~/.local/share/applications/lomiri-mediaplayer-app.desktop`,
then fully close Media Player before testing a new launch. The owner confirmed
video and audio in both a test MP4 and a camera recording after the temporary
system-wide setting was cleared. This leaves the
system desktop file intact and limits the backend choice to Media Player.
To undo it, remove that exact user-level desktop file and relaunch the app.

The `amcviddec` rank disables the crashing Unisoc C2 H.264 decoder for this
app; `openh264dec` selects software decoding. This is a userspace playback
workaround, not a fix for the underlying hardware codec or media-hub path.
High-resolution files may be slower and battery-intensive. Verify camera,
seeking, pause/resume and playback after reboot separately.

## Gallery camera recordings

Gallery delegates a video's play button to the same built-in Media Player, but
uses MediaScanner and Thumbnailer first to list the file and draw its preview.
Their GStreamer helpers also tried the crashing Unisoc H.264 decoder. A valid
camera MP4 was absent from Gallery, and `vs-thumb` exited with status 139;
running it with the software-decoder rank produced a TIFF thumbnail.

User-level D-Bus activation overrides for both helpers are in
[`media-fix/`](../media-fix/). Install them under
`~/.local/share/dbus-1/services/` as
`com.lomiri.Thumbnailer.service` and
`com.lomiri.MediaScanner2.Extractor.service`. Their `Exec` lines pass the same
`GST_PLUGIN_FEATURE_RANK` setting to the respective helper; they leave system
service files unchanged. After the session bus reloads its service paths,
restart `mediascanner-2.0.service` and clear the regenerable failed-thumbnail
cache with `lomiri-thumbnailer-admin clear`. The owner then confirmed a camera
recording appeared in Gallery and played with picture and sound.

Zero-byte MP4s left by failed Camera recordings are invalid and will not be
indexed; this Gallery workaround does not cure Camera's recording freeze.
