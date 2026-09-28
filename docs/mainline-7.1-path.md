# Mainline 7.1 path for TB328FU

For independence from Android, the strongest current base is the UMS512 work
in [`beebono/rg-rotate-linux`](https://github.com/beebono/rg-rotate-linux), not
the older Lenovo 4.14 release. Its sibling board uses the same UMS512/T618
`ums512_1h10` / SharkL5Pro platform and boots Linux 7.1 with a native panel,
eMMC, microSD, USB serial, GPU, cpufreq, thermal, Wi-Fi, Bluetooth, audio and
deep suspend.

The referenced source revisions inspected on 2026-09-27 are:

```text
linux-mainline-sprd rg-rotate: 464b3e7bf
u-boot-ums512 main:            d1f9108
```

An unmodified build succeeds locally with GCC cross tools:

```text
Image size:   43,371,008 bytes
Image SHA256: 0b2df4864c20fa45b29379cad648b7cc59f5665bb5efe00ac71cb8385c56f78d
RG DTB size:  77,765 bytes
RG DTB SHA256:f728f75c6b025a37115ada49ad5afd1c4d9712d97ca6df3fc8ad04e21179c47a
```

## TB328FU hardware recovered from installed DTBO

The installed Android 12 `dtbo_a` contains two overlays; boot argument
`androidboot.dtbo_idx=1` selects the tablet overlay. Its important board data:

```text
panel       BOE HX83102E, 1200x2000, three listed revisions
touch       Himax hxcommon, I2C3 address 0x48
hall        GPIO 130, supplied by vddgen0
Wi-Fi/BT    Marlin3Lite / SC2355 SDIO
microSD     SDIO0, EIC 19 card detect, vddsdcore + vddsdio rails
charger     TI BQ25601D, I2C2 address 0x6b (live REG0B = 0x11)
SAR         Awinic AW96105A, I2C2 address 0x12, IRQ AP GPIO90
cameras     main I2C0 0x5a, front I2C1 0x6e
PMIC        SC2730
SoC/board   UMS512-1H10 / T610 Wi-Fi-only SKU
```

The RG project already has the difficult SoC-wide pieces. A TB328FU DTS should
start from `ums512-rg-rotate.dts`, preserve its clocks, regulators, eMMC,
watchdog, GPU, cpufreq, thermal and WCN fixes, then replace board-specific
display, touch, GPIO and reserved-memory descriptions using the installed
TB328FU base DTB plus overlay 1.

## Boot boundary

The stock Android 12 U-Boot v4 flow always obtains its FDT from installed
`vendor_boot`. `fastboot boot` sends only `boot.img`, so it cannot safely test a
new mainline DTB by itself. The proven external project solves this with a
custom vendor U-Boot and an extlinux microSD development path.

Do not flash a mainline boot image alone. Two paired routes remain:

1. custom U-Boot/extlinux from microSD while retaining V96 on eMMC; or
2. a deliberately paired `boot_b` + `vendor_boot_b` experiment with verified
   backups and FDL recovery.

The microSD route is safer, but no card is currently available. An eMMC test
must leave slot A's V96 boot chain untouched and restore both slot-B images as
a pair after any failure.

## Initial TB328FU build

`kernel/mainline/ums512-tb328fu.dts` is the conservative phase-1 board file.
It declares the tablet's 4 GiB memory and retains the proven UMS512 storage,
USB and SC2355 WCN blocks. RG-specific display, touch, keys, audio, fuel gauge
and external charger nodes are disabled until their TB328FU wiring is ported.

It builds successfully with `kernel/mainline/build-mainline-7.1.sh`:

```text
Image SHA256: 1795be9ca2d2717b01eb1212ebdde00f5474c2c325cd93535dcd266c8644c593
DTB SHA256:   a600ae3855d1fbd0067547a88f415a20eac624cabc075fe6d467f8c23fca13d9
```

The microSD and eMMC PHY timing values come from TB328FU's installed DTBO
overlay 1 rather than the donor RG board.

Live inspection identifies the touch IC more precisely as HX83102E with
firmware `0x8203`. The phase-1 DTS enables I2C3 at Lenovo's 1 MHz rate, EIC
line 0 falling-edge interrupt, AP GPIO 145 reset, and the 1200x2000 coordinate
range. Patch `kernel/mainline/patches/0001-input-himax-add-hx83102e.patch`
extends the existing mainline Himax driver with product ID `0x83102e`.

The resulting touch-enabled build succeeds:

```text
Image SHA256: 116c18c3b8d5e8073cdb54d95f4e990312f702b64f803b8a4eb05f2414a4b29e
DTB SHA256:   5e731fe6a2a53eee0454af181c821809a776a1c0f9eb2f93454cc6728a038329
```

The display is confirmed as Lenovo's BOE HX83102E third revision. Its exact
1200x1920 timing, four-lane 988 MHz DSI configuration, GPIO 132/133 power
rails, GPIO 50 reset and 50-command initialization sequence are now carried in
the TB328FU DTS through the donor tree's generic DSI driver. A native 12-bit
DCS backlight provides runtime brightness control. The complete built-in SPRD
DRM stack links successfully.

Lenovo's system inputs are also mapped: PMIC EIC 1 power, PMIC EIC 4 volume
down, AP GPIO 124 volume up and AP GPIO 130 hall-cover switch. The unrelated
RG donor gamepad remains disabled.

The battery description now uses Lenovo's installed 5,000 mAh, 4.432 V
capacity, OCV and temperature-resistance data instead of the donor handheld's
pack. Charging and the fuel gauge remain disabled until their native drivers
and wiring can be validated on hardware.

Live I2C and register evidence also replaces the donor AW32257 charger with the
tablet's BQ25601D at I2C2 address `0x6b`; its upstream driver builds in, but the
DT node remains disabled. The SAR firmware identifies an AW96105A at `0x12`.
Its upstream driver exists, but the exact supply rail is not yet proven, so no
unsafe supply guess has been added.

This is build proof, not boot proof. Placing only the Image in Android boot v4
would silently reuse the incompatible installed `vendor_boot` DTB.

`kernel/mainline/build-v4-pair.sh` also creates an offline Android-v4-format
diagnostic pair. Both images independently unpack and reproduce the intended
kernel, initramfs, DTB and vendor ramdisk:

```text
Image SHA256:       e899d20f985fbdcc2b2a82a95e73e5b08d864f6479f31cbd0fa0cfc2e710f034
DTB SHA256:         7f2c7e3329636287049f6d5cace5d817c1fd255e5a0da9e873db7297bd96eee6
boot SHA256:        ca30fb8ca06670e37032a2b266c1f594e518e2ab3188a21ae66865a29c69ddf2
vendor_boot SHA256: 96939b239b577f247c8265b9ddaa01a28f195c92892222f81387c8eb9dec985b
```

The builder accepts only the exact backed-up live `vendor_boot_b` template
(SHA-256 `b95c4cae0ebed9162dab49f1bdbdd1daaddc10f86f9d3bf1d9f3a4b5c7530922`).
These are paired research artifacts only. `fastboot boot` cannot provide the
matching `vendor_boot`; use only the controlled paired-slot procedure below.

## Paired slot-B result — 2026-09-28

The exact pair above was written to `boot_b` and `vendor_boot_b` after checking
partition sizes and rollback hashes. Selecting B returned directly to fastboot;
no diagnostic USB device or initramfs appeared. Both B partitions were restored
from their verified backups, slot A was selected, and V96 returned with ADB.

Because this test supplied the matching TB328FU DTB, the remaining blocker is
before normal Linux or DT probing: the upgraded bootloader's image validation,
loading, or kernel-entry contract. Do not repeat this pair unchanged.
