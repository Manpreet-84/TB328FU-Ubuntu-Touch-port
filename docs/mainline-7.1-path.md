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
cameras     main I2C0 0x5a, front I2C1 0x6e
SAR         Awinic AW9610X, I2C2 address 0x12
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

Do not flash a mainline boot image alone. First build the TB328FU DTS and
initramfs offline, then choose one recoverable paired test path:

1. custom U-Boot/extlinux from microSD while retaining V96 on eMMC; or
2. a deliberately paired `boot` + `vendor_boot` slot experiment with verified
   backups and FDL recovery.

The microSD/extlinux route is preferred because kernel/DT changes do not touch
the working Ubuntu installation.

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

The microSD and eMMC PHY timing values now come from TB328FU's installed
DTBO overlay 1 rather than the donor RG board.

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

This is build proof, not boot proof. It must be paired with its DTB through
the microSD/extlinux U-Boot route; placing only the Image in Android boot v4
would silently reuse the incompatible installed `vendor_boot` DTB.

`kernel/mainline/build-v4-pair.sh` also creates an offline Android-v4-format
diagnostic pair. Both images independently unpack and reproduce the intended
kernel, initramfs, DTB and vendor ramdisk:

```text
Image SHA256:       c7768fe539fa03d5ff5d89b98beb9ae372bb5c6759f7093a87353df2638ab0b8
DTB SHA256:         4389ac8025110ab7d48dde5d004d8bff66afec6eab98db0e18d2859693ceb035
boot SHA256:        8d983d221fd381361ec5cf159d70e281b85fd12d36c2434f40e9dab3b1802e51
vendor_boot SHA256: 223d08b7b2023e6494ebe45212b7190ee56ab13e155c2255066dd6c407fdda6a
```

These are paired research artifacts only. `fastboot boot` cannot provide the
matching `vendor_boot`, and neither image is authorized for flashing yet.
