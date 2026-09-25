# Kernel source status

The running tablet reports:

```text
5.4.233-android12-9-g79e86a50ca56
Android clang 12.0.5 / clang-r416183b
```

Lenovo's available `tb328fu_s000020_220125_row` archive instead contains Linux
4.14.193. It remains useful for board documentation but cannot reproduce the
running kernel.

Google's `android12-5.4.233_r00` tag builds successfully but is conclusively not
ABI-compatible with the Lenovo modules. A public UMS512 5.4.254 donor is closer and
can build a minimum ARM64 Image, but it is still experimental and not a substitute
for Lenovo's exact source.

Relevant upstream references:

- Lenovo open-source portal: <https://support.lenovo.com/us/en/solutions/ht511330>
- Android common 5.4.233 tag: <https://android.googlesource.com/kernel/common/+/refs/tags/android12-5.4.233_r00>
- UBports porting introduction: <https://docs.ubports.com/en/latest/porting/introduction/Intro.html>
- UBports standalone kernel requirements: <https://docs.ubports.com/en/latest/porting/build_and_boot/standalone_kernel_build.html>

