#!/bin/sh
set -eu

source_dir=${1:?usage: verify-wcn-suspend-source.sh KERNEL_SOURCE}
wlan="$source_dir/kernel_modules/kernel5.4/wcn/wlan/wlan_combo/sc2355/sdio.c"
sdio="$source_dir/drivers/unisoc_platform/sprdwcn/sdio/sdiohal_main.c"

test -f "$wlan" || { echo "missing SC2355 Wi-Fi source: $wlan" >&2; exit 1; }
test -f "$sdio" || { echo "missing UMS512 SDIO source: $sdio" >&2; exit 1; }

# TB328FU V96 loses Wi-Fi after deep suspend because the firmware handshake is
# attempted after the SDIO transport has quiesced.  The donor must bind the
# handshake to the TX-command channel and invoke it from the SDIO PM callbacks.
grep -q 'sdio_suspend_resume_handle' "$wlan"
grep -q 'SDIO_TX_CMD_PORT' "$wlan"
grep -q 'sdiohal_ops->power_notify(chn, false)' "$sdio"
grep -q 'sdiohal_ops->power_notify(chn, true)' "$sdio"
grep -q 'SET_SYSTEM_SLEEP_PM_OPS(sdiohal_suspend, sdiohal_resume)' "$sdio"

echo "WCN suspend source check: PASS"
