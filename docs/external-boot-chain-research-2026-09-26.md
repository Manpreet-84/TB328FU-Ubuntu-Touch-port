# External boot-chain research — 2026-09-26

## Device distinction

The Lenovo forum thread for TB125FU is not directly applicable to TB328FU.
TB125FU uses MediaTek MT8786/Helio G80 (`maple`), while TB328FU uses Unisoc
T610/UMS512 (`ums512_1h10`). Their bootloaders, keys, exploits, kernels, and
device trees are different.

## TB328FU evidence

- A TB328FU research repository identifies Android boot header/ramdisk patching,
  A/B partitions, signed FDL files, and Unisoc download mode. It also reports
  that `fastboot boot <image>` accepted modified images on that unit.
  <https://github.com/johannhipp/lenovo-tab-m10-unbrick>
- A 2026 report for the same TB328FU firmware family records the same failure we
  see: modified/Magisk boot images loop before ADB, while `vbmeta` and SPL writes
  fail signature verification. This supports a bootloader/TrustOS verification
  boundary rather than a Linux driver crash.
  <https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/issues/293>
- The Unisoc unlock project describes CVE-2022-38694 as a one-time BootROM
  verification bypass and points to CVE-2022-38691/38692 for persistent bypass.
  Its support documentation covers UMS512/T610 at FDL1 address `0x5500` and
  FDL2 address `0x9efffe00`.
  <https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader>
- Its Magisk notes say older fused UMS512 devices require signed or "big resign"
  boot images. Android 12 is generally described as not requiring boot signing,
  but the TB328FU report above is a concrete exception or vendor-specific chain.
  Never re-sign or overwrite vbmeta without a verified recovery route.
  <https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/wiki/Magisk>
- A separate UMS512 native-Linux project reports that its boot image had to be
  signed and achieved Linux userspace using the stock boot environment. Its DT
  and peripherals are not TB328FU-compatible, but its boot-chain findings are
  relevant.
  <https://github.com/Seriousattempts/rp3plus-native-attempts>

## Consequence for this port

V96 works because it retains Lenovo's accepted stock kernel and replaces
userspace/initramfs behavior. A clean donor kernel can be structurally valid yet
rejected before normal ARM64 startup. The next low-risk diagnostic is a RAM-only
`fastboot boot` of the V6 EFI-entry-marker image, if this bootloader exposes that
command. Keep V96 on slot A and do not modify vbmeta, SPL, TrustOS, or U-Boot.

If RAM boot is also rejected, the independent-kernel path needs a verified
TB328FU-specific UMS512 signing/unlock method or a persistent verification
bypass. Until then, the stable distributable port should keep Lenovo's stock
kernel and place maintained fixes in the initramfs/userspace layer.
