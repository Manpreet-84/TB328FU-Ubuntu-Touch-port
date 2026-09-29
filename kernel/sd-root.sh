# Sourced inside V96 mountroot immediately before the normal root mount.
tb_sd_root() {
    exec 8>>/tmpmnt/sd-root-probe.log
    echo 'SD probe starting' >&8
    tell_kmsg 'TB328FU_SD_PROBE_BEGIN'
    mkdir -p /sd-boot
    n=0
    while [ ! -e /sys/class/block/mmcblk1p1/dev ] && [ "$n" -lt 15 ]; do
        sleep 1
        n=$((n + 1))
    done
    [ -e /sys/class/block/mmcblk1p1/dev ] || { echo 'No SD partition in sysfs' >&8; tell_kmsg 'TB328FU_SD_NO_DEVICE'; return 1; }
    nums=$(cat /sys/class/block/mmcblk1p1/dev)
    [ -b /dev/mmcblk1p1 ] || mknod /dev/mmcblk1p1 b "${nums%:*}" "${nums#*:}" || return 1
    uuid=$(blkid -s UUID -o value /dev/mmcblk1p1)
    echo "Device=$nums UUID=$uuid" >&8
    tell_kmsg "TB328FU_SD_DEVICE=$nums UUID=$uuid"
    [ "$uuid" = f24eab58-441e-4a6a-8021-6af03a1cf209 ] || return 1
    mount -t ext4 -o ro /dev/mmcblk1p1 /sd-boot 2>&8 || { tell_kmsg 'TB328FU_SD_MOUNT_FAILED'; return 1; }
    if [ -x /sd-boot/rootfs/sbin/init ] && mount -o bind /sd-boot/rootfs /halium-system; then
        tell_kmsg 'TB328FU_SD_ROOT_SELECTED'
        echo 'SD ROOT SELECTED' >&8
        sync
        return 0
    fi
    tell_kmsg 'TB328FU_SD_ROOT_BIND_OR_INIT_FAILED'
    echo 'Root bind or init check failed' >&8
    umount /sd-boot
    return 1
}
