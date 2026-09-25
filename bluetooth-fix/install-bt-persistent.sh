#!/bin/bash
# TB328FU: install the Bluetooth HCI proxy permanently.
set -e
echo "== install files (persistent: /etc/writable + /etc/systemd/system are on userdata) =="
install -d -m 0755 /etc/writable/tb328fu-bt
install -m 0755 /tmp/tb328fu-bt-proxy.py /etc/writable/tb328fu-bt/tb328fu-bt-proxy.py
install -m 0755 /tmp/tb328fu-bt-start-safe.sh /etc/writable/tb328fu-bt/tb328fu-bt-start-safe.sh
install -m 0755 /tmp/bt-vendor-init.py /etc/writable/tb328fu-bt/bt-vendor-init.py
install -m 0644 /tmp/bt-pack-ini.py /etc/writable/tb328fu-bt/bt-pack-ini.py
install -m 0644 /tmp/tb328fu-bt.service /etc/systemd/system/tb328fu-bt.service
install -m 0644 /tmp/tb328fu-bt.timer /etc/systemd/system/tb328fu-bt.timer
ls -l /etc/writable/tb328fu-bt/ /etc/systemd/system/tb328fu-bt.service
python3 -m py_compile /etc/writable/tb328fu-bt/tb328fu-bt-proxy.py && echo "installed proxy compiles OK"

echo "== bluebinder stays masked (needs /dev/vhci, absent from stock kernel) =="
systemctl stop bluebinder.service 2>/dev/null || true
systemctl mask bluebinder.service 2>/dev/null || true
systemctl is-enabled bluebinder.service 2>&1 || true

echo "== stop manually started test instances =="
pkill -9 -f 'tb328fu-bt-proxy.py' 2>/dev/null || true
pkill -9 -f 'btattach -B /dev/pts' 2>/dev/null || true
sleep 2

echo "== enable delayed, boot-detached timer =="
systemctl daemon-reload
systemctl disable tb328fu-bt.service 2>/dev/null || true
systemctl stop tb328fu-bt.service 2>/dev/null || true
systemctl enable tb328fu-bt.timer
echo "Installed. The timer starts Bluetooth two minutes after boot."

