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
