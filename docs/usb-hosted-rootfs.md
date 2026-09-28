# USB-hosted rootfs experiment

The stock V96 kernel cannot mount a root filesystem hosted by a PC because it
lacks USB Ethernet gadget support, NFS client support, and kernel IP setup.

The experimental UMS512 donor build now enables:

- USB ConfigFS ECM and RNDIS gadgets
- NFS client and NFS root
- kernel IP autoconfiguration and DHCP

Build output:

```text
kernel  6519e718520fde319d01153d36416f86b619ff7a85fd8121eae82f438dfd645a
image   1371da45f5c742be0142a8fa5b0f3f4bc26e7737e309fb95d2fbba8aeaec26c9
```

`out/tb328fu-usb-nfs-kernel-test.img` reuses the V96 ramdisk and is only a
kernel boot diagnostic. It does not yet create the ECM gadget or pivot to an
NFS root. Keep V96 as rollback and test this image with RAM-only `fastboot
boot`; do not flash it.

The next step is a small diagnostic initramfs that creates the ECM gadget,
assigns a fixed USB address, and writes an observable marker before attempting
an NFS mount.

## RAM-only result

`fastboot boot` accepted the image, but the tablet returned to fastboot before
the initramfs exposed ADB or USB Ethernet. A normal start then held at the
Lenovo logo. Reflashing the verified V96 image to `boot_a` recovered Ubuntu
without touching userdata.

Do not build the NFS initramfs yet: first solve the donor kernel's pre-init
boot incompatibility. The USB/NFS configuration itself compiled successfully.
