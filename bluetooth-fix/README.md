# Experimental V96 Bluetooth proxy

This is a delayed userspace H4 bridge for the TB328FU's Unisoc CP2
Bluetooth controller. It relays traffic between Linux's H4 line discipline and
Lenovo's `/dev/ttyBT0`, while locally accepting opcode `0x080f`, which this
controller rejects and which otherwise aborts Linux HCI initialization.

The bridge has demonstrated discovery, pairing and A2DP playback with P2961
headphones and AirPods Pro.

## Safety properties of this build

- Only a timer is enabled; it invokes the service two minutes after boot, after
  Ubuntu and Lomiri are usable.
- The launcher independently refuses to run in the first 120 seconds.
- It does not load `sprdbt_tty`, toggle rfkill or power-cycle CP2.
- It configures the tty as raw before applying Lenovo's PSKEY/RF payloads. This
  restores the stored controller address instead of the firmware fallback.
- If devtmpfs omits `/dev/ttyBT0`, it creates the node from the registered
  sysfs major/minor; it never guesses the device number.
- Missing/unpowered hardware causes a clean failure rather than a boot delay.
- There is no automatic restart loop.

These restrictions are intentional. The Lenovo driver has previously blocked
inside `/dev/ttyBT0` open/close and `stop_marlin()`, and an uninterruptible
kernel wait cannot be repaired by an ordinary userspace timeout.

## Offline verification

```sh
sh -n tb328fu-bt-start-safe.sh install-bt-persistent.sh test-bt-start-safe.sh
./test-bt-start-safe.sh
python3 -m py_compile tb328fu-bt-proxy.py
```

## Future device test

The complete sequence has been proven once from `/tmp`. The timer design keeps
the operation outside the boot-critical path, but repeated cold-boot and
failure-path validation is still required before calling Bluetooth stable.
