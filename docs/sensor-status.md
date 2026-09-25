# TB328FU sensor status

Updated: 2026-09-23

This inventory is based on the saved LineageOS sensor-service dump, kernel logs,
input-device listing and Ubuntu Touch test results. It does not infer hardware
from generic kernel configuration alone.

## Physical hardware confirmed

| Hardware | Android interface | Ubuntu Touch status | Evidence |
| --- | --- | --- | --- |
| Accelerometer | `android.sensor.accelerometer`, handles `0x01` and `0x33` | Working through `sensorfwd`; supplies rotation | Live three-axis samples were recorded in the Android sensor-service dump. |
| Ambient-light sensor | `android.sensor.light`, handles `0x05` and `0x37` | Live lux values work; automatic-brightness policy remains incomplete | Present in the sensor HAL and previously observed through sensorfw. |
| Proximity sensor | `android.sensor.proximity`, handle `0x3a` | Exposed through sensorfw; application and blanking behaviour still needs a repeatable test | HAL registration and kernel sensor-hub commands are present. |
| Hall-cover sensor | Linux input device `hall-switch-input` | Not yet integrated with Lomiri cover/sleep policy | Present in the captured Android input-device list. |
| Capacitive SAR sensor | Linux input device `aw9610x_sar` | Not expected to have a normal user-facing UI | Present in the captured Android input-device list. It is normally used for radio exposure/power policy. |

## Sensor-hub software interfaces

Android reports 40 sensor interfaces, but this does **not** mean the tablet has
40 physical sensors. The Spreadtrum sensor hub derives orientation and gestures
from the accelerometer, light and proximity inputs. Its advertised interfaces
include device orientation, stationary/motion detection, tilt, wake/glance/pick,
tap, flip, pocket mode, hand up/down, face up/down, context awareness, elevator,
any-motion and ChopChop, with wake-up variants for many of them.

These derived gestures should be treated as optional until individually tested.
They are not evidence of additional physical chips.

## Hardware not present or not exposed

- No gyroscope appears in the 40-entry Android sensor list.
- No magnetometer/compass appears in the Android sensor list.
- The kernel exposes an `sc27xx:vibrator` input node, but direct testing and
  stock Android produced no physical vibration. Treat it as a phantom/unused
  driver until hardware evidence proves otherwise.

The Android dump also reports all sensor-fusion modes disabled. Device
orientation is therefore a sensor-hub result based primarily on acceleration,
not a full gyro/compass fusion result.

## Intermittent rotation diagnosis

The accelerometer and orientation path are real and have produced valid events,
so an occasional failure to rotate is not a missing-sensor or axis-mapping
problem. Current evidence points to startup ordering:

1. the Android sensor HAL and Unisoc sensor hub must be ready;
2. Ubuntu `sensorfwd` must connect and register `com.nokia.SensorService`;
3. Lomiri must discover the orientation channel while starting.

The archived V64 launcher waited at most five seconds for the D-Bus service and
continued even after timeout. Starting Lomiri with a partially ready or stale
sensor channel can leave rotation unavailable until the next clean boot.
Bluetooth RF/controller experiments have also disturbed the sensor-hub path, so
Bluetooth initialization must remain outside the boot-critical sensor sequence.

## Safe next implementation

Do not change the known-good V96 image merely to test this theory. For the next
candidate build:

1. wait for the Android Sensors HAL service, not just the Ubuntu D-Bus name;
2. start `sensorfwd` with a bounded timeout and capture its log;
3. require an actual orientation sample before starting Lomiri;
4. on failure, restart only the bridge with a strict retry limit;
5. continue booting in fixed portrait after the retry limit instead of hanging;
6. keep Bluetooth initialization detached from this path;
7. validate ten cold boots and ten suspend/resume cycles before calling rotation stable.

This change should first be prepared as a standalone launcher helper and tested
post-boot. It should enter the boot image only after it has proved unable to hang
or delay the known-good V96 boot.
