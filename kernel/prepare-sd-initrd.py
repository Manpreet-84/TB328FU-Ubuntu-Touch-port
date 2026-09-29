"""Patch an unpacked V96 initrd; refuse unknown mount logic."""
import pathlib
import sys
import tempfile

root = pathlib.Path(sys.argv[1])
target = root / 'scripts/halium'
text = target.read_text()
old = '''\ttell_kmsg "mounting system rootfs at /halium-system"
\tif [ -n "$_syspart" ]; then'''
new = '''\ttell_kmsg "mounting system rootfs at /halium-system"
\t. /scripts/tb-sd-root
\tif tb_sd_root; then
\t\t: # Keep V96 read-only overlay and persistent userdata behavior.
\telif [ -n "$_syspart" ]; then'''
assert text.count(old) == 1, 'Unexpected initrd: root mount anchor not unique'
updated = text.replace(old, new)
with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=target.parent,
                                 delete=False) as temporary:
    temporary.write(updated)
pathlib.Path(temporary.name).replace(target)
(root / 'scripts/tb-sd-root').write_bytes(
    pathlib.Path(__file__).with_name('sd-root.sh').read_bytes())
