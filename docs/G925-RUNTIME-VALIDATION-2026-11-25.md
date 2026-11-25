# G925 Runtime Validation - 2026-11-25

## Device and test environment

- Device: Samsung Galaxy Tab S11 Wi-Fi, model `SM-X730`.
- SoC: MediaTek `MT6991`; target GPU: Arm Immortalis-G925.
- Android: 17 (SDK level 36).
- Host link: ADB over USB, authorized; no root access used.
- Windows compatibility layer: Winlator Ludashi 5.0, Proton 11.0-7 arm64ec.
- Winlator desktop: 1280x720.
- Test application: AIO Graphics Test 64-bit, release 2.3.1.
- Test launch arguments: `--cube vk --bench 15 --autoclose 5`.
- Test output directory: `/sdcard/Download/AIO Results/Benchmark/`.

## Custom PanVK driver load

The package `mali-panvk-27.0.0-devel-a4b8b6b-perf-debug.zip` was imported through Winlator's local driver-package importer. Winlator registered it as:

`PanVK Mali Bifrost and Valhall (kbase) (Mesa 27.0.0-devel-a4b8b6b)`

Android logcat confirms that the custom loader opened:

`.../contents/adrenotools/PanVK Mali Bifrost and Valhall (kbase) (Mesa 27.0.0-devel-a4b8b6b)/libvulkan_panfrost.so`

The container `PanVK_G925_Test` reached the Winlator desktop and started AIO's Vulkan test. The Android Mali driver emitted `GROUP_ERROR_FATAL` for CSF groups 0 and 1. The AIO benchmark result directory remained empty. No FPS or frametime result was produced.

`PANVK_DEBUG=perf` was not enabled: this Winlator build's shortcut environment editor does not expose arbitrary environment variables, and no alternative injection mechanism has yet been validated. Consequently, no `PANVK_PERF` records were collected.

## System-driver control attempt

A separate AIO shortcut was explicitly associated with Winlator container `Container-1`, whose graphics-driver selection is `System` (not `PanVK_G925_Test`). The Vulkan cube window appeared and rendered the cube initially.

The run then displayed a Wine C++ Runtime assertion from AIO's Vulkan cube implementation:

- Source: `src/cube.c`
- Line: `1142`
- Expression: `!err`
- Failing operation: `vkQueueSubmit(...)`

The corresponding Android log also contains `GROUP_ERROR_FATAL` for CSF groups 0 and 1, with sideband status `0x24c00488`. The benchmark output directory remained empty. AIO does not print the `VkResult` value before asserting, so the precise Vulkan error code is unknown.

## Interpretation and limitations

1. The custom PanVK library is demonstrably loaded by Winlator's custom-driver hook on this physical G925 device.
2. The PanVK AIO run did not produce a valid benchmark result and reported CSF group faults.
3. The separate System-driver AIO run also reached Vulkan rendering, then failed in `vkQueueSubmit` and logged CSF group faults.
4. Therefore, this AIO/Winlator test currently does **not** isolate a PanVK-specific regression. It may be exposing a problem in the test's submission/present sequence, the Winlator environment, the device/kernel CSF path, or an interaction between them. More instrumentation is required before assigning root cause.
5. No FPS comparison is valid. The attempts were diagnostic reproductions, not completed benchmark runs; each condition must be repeated after a stable workload is found.
6. The Android factory/system driver was not replaced, no root operations were performed, and the existing `Container-1` was not modified to use PanVK.

## Next validation steps

1. Reproduce the System control with a minimal Vulkan workload that reports each `VkResult` instead of asserting, and confirm whether the failure is specific to queue submit, present, or teardown.
2. Run the same workload from `PanVK_G925_Test`, collecting the exact Vulkan result and kbase group-fault logs.
3. Enable `PANVK_DEBUG=perf` through a verified process environment path; do not substitute Turnip's `TU_DEBUG` variables.
4. Only after a stable Vulkan workload completes on both drivers, collect repeated performance measurements and return to BannerHub.

## Safety and reproducibility

- Keep Android's factory/system Vulkan driver unchanged.
- Keep `Container-1` on `System`; use `PanVK_G925_Test` for the custom driver.
- Retain the known-good PanVK package and its SHA-256 outside the source tree.
- Do not infer performance from the AIO window's initial cube rendering or from SurfaceFlinger queue FPS logs.
