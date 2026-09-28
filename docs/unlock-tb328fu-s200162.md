# Guarded TB328FU S200162 bootloader unlock

This replaces the unsafe TB328XU `unlock.bat` workflow. It is intentionally
limited to the exact combination proven on the project tablet:

- Lenovo Tab M10 Gen 3 Wi-Fi `TB328FU`
- build containing `S200162`
- UMS512
- Windows

It does **not** erase or write `splloader`, use XU restore images, copy another
tablet's unlock record, repartition storage or call `adb reboot autodloader`.

## Why the older instructions fail

The XU batch erases `splloader` first and later restores an image from another
tablet. If the run stops between those operations, the tablet repeatedly falls
back to black-screen BootROM. Entering `autodloader` also confused several
testers because it is not the clean powered-off BROM connection expected by the
exploit.

## Required files

Create `tools/unlock-assets/` and copy these five files from the tested research
package:

```text
spd_dump.exe
fdl1-dl.bin
fdl2-dl.bin
fdl2-cboot.bin
spl-unlock-fu.bin
```

The script checks their exact SHA-256 values before doing anything. Firmware,
loaders and third-party binaries are excluded from this Git repository.

## Run

1. Back up personal files. Unlocking normally requires a factory reset.
2. In stock Android, enable OEM unlocking and USB debugging and authorize the PC.
3. Charge the tablet, use a reliable cable, and close Lenovo/SPD flashing tools.
4. Open PowerShell in the repository and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\unlock-tb328fu-s200162.ps1
```

Follow the prompts literally. For every BROM step: power fully off, unplug USB,
start the waiting command by pressing Enter, then hold **Volume Down** while
plugging USB in. Do not use `adb reboot autodloader`.

Before the first partition write the tool creates a timestamped backup folder,
hash manifest, and `RECOVER-NOW.cmd`. It stops on a wrong model/build, wrong
loader hash, missing/zero backup, incompatible partition table, zero unlock
record, or failed U-Boot readback.

If interrupted after the temporary cboot write, run `RECOVER-NOW.cmd` from that
backup folder and enter clean BROM. It restores only files read from that same
tablet. A black screen with `SPRD U2S Diag` present in Device Manager is BootROM,
not necessarily a dead tablet.

Success ends with:

```text
UNLOCK RECORD VERIFIED; ORIGINAL UBOOT_B VERIFIED.
```

Android Recovery may then require **Factory data reset** for
`init_user0_failed`. Never relock after installing modified images.

