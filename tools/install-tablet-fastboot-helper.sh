#!/bin/sh
set -eu

helper=$(mktemp)
rule=$(mktemp)
root_rw=0
cleanup() {
	[ "$root_rw" -eq 0 ] || sudo mount -o remount,ro / || true
	rm -f "$helper" "$rule"
}
trap cleanup EXIT

cat >"$helper" <<'EOF'
#!/bin/sh
exec /system/bin/reboot bootloader
EOF

cat >"$rule" <<'EOF'
phablet ALL=(root) NOPASSWD: /usr/local/sbin/tb-fastboot
EOF

sudo -v
sudo mount -o remount,rw /
root_rw=1
sudo install -o root -g root -m 0755 "$helper" /usr/local/sbin/tb-fastboot
sudo install -o root -g root -m 0440 "$rule" /etc/sudoers.d/tb-fastboot
sudo visudo -cf /etc/sudoers.d/tb-fastboot
sudo mount -o remount,ro /
root_rw=0

echo 'Installed. PIN was not stored.'
