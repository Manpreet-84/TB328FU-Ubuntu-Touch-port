# Suspend status

Verified on V96, 2026-09-25:

- Kernel exposes `s2idle [deep]`; deep is selected.
- repowerd runs but cannot initialize Android libsuspend, so it falls back to
  logind.
- No repowerd suspend-block request was active.
- A controlled USB-connected suspend entered deep sleep and resumed in about
  one second.
- Kernel identified the exact wake source:

```text
PM: suspend entry (deep)
PM: pm_system_irq_wakeup: 58 triggered musb-hdrc.1.auto
Resume caused by IRQ 58, musb-hdrc.1.auto
PM: suspend exit
```

- Camera patch, camera audio bridge, Bluetooth proxy, `hci0` and battery sysfs
  remained healthy after resume.

An unplugged test then remained in deep sleep for about 23 seconds and woke from
the power key through PMIC parent IRQ 74. Camera and Bluetooth remained healthy.

Wi-Fi did not recover. NetworkManager recreated `wlan0`, but every scan failed
in the vendor driver with:

```text
sprd-wlan: sc2355_tx_get_msg can not get msg: hif->exit
wlan sprd-marlin3:wlan wlan0: sc2355_scan failed (-12)
```

Radio toggling, NetworkManager activation and reloading the two Wi-Fi modules
did not reset the shared WCN transport. Recovery currently requires reboot.
Related UMS512 work identifies the architectural fault: SDIO quiesces before
the Wi-Fi firmware suspend handshake because their devices are unordered in
the kernel power-management list. Proper fix belongs in the kernel SDIO
`power_notify` path; userspace reconnect scripts cannot repair it.

Until that kernel fix exists, `config/systemd/tb328fu-no-suspend.service`
blocks system sleep while still allowing screen blanking and locking. Disable
that unit only when testing a kernel with repaired SC2355 resume.
