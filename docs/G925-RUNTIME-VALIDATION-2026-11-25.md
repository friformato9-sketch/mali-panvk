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

1. The initial PanVK attempt with the earlier a4b8b6b package loaded the custom ICD but failed with CSF group faults and produced no benchmark result.
2. The initial System-driver control attempt also failed in AIO's vkQueueSubmit path and logged CSF group faults. Those first attempts did not isolate a PanVK-specific regression.
3. After the SYNC_WAIT scope changes were built as cdb8aa7, a controlled AIO A/B completed three runs per driver with both Winlator Renderer Driver and guest Vulkan Driver verified as System or cdb8aa7 for the corresponding condition. See the controlled A/B section and G925-AIO-AB-2026-11-25.md.
4. The three valid cdb8aa7 runs completed and their captured log windows contained no matches for the prior GROUP_ERROR_FATAL / 0x24c00488 fault signatures, VK_ERROR, SHAREABILITY_FAULT, or an AIO assertion. This is encouraging evidence for the tested submission path, not a universal synchronization-correctness proof.
5. The benchmark is a synthetic Vulkan cube workload. Its relative FPS difference must not be presented as a BannerHub or real-game uplift. Vulkan CTS and application-level testing remain outstanding.
6. The Android factory/system driver was not replaced and no root operations were used. Container-1 remains the System control; PanVK_G925_Test is the custom-driver test container.

## CSF SYNC_WAIT scope finding and candidate fix

The device log reports GROUP_ERROR_FATAL with status 0x24c00488 and exception 0x88. The low status byte matches the SHAREABILITY_FAULT signature discussed in https://github.com/MineGraph-bilibili/panvk-Android/issues/3, whose analysis associates 0x88 with a shareability fault and status bits [15:8] = 0x04 with an atomic access. That report concerns a different Mali generation and kernel, so it is a diagnostic lead, not proof of the G925 root cause.

Source inspection of this fork found a matching encoding gap:

- CS SYNC_ADD32/64 and CS SYNC_SET32/64 describe the Scope field at bits 2:1, but CS SYNC_WAIT32/64 omitted it in genxml v10 through v14.
- The shared cs_sync32/64_wait() builder helper did not accept or write a scope.
- PanVK waits on same-group subqueue sequence/sync cells and the kbase ring wait on its CSF_EVENT sequence cells are intra-group operations; their producer signals use CSG scope.
- The pandecode output did not expose a wait's scope, making this class of issue harder to inspect.

A candidate correction is now in the working tree:

1. Add the missing Scope field to SYNC_WAIT32/64 for genxml v10-v14.
2. Thread an explicit scope through the CS builder and PanVK instrumentation wrapper.
3. Emit MALI_CS_SYNC_SCOPE_CSG for the three internal same-group wait call paths and encode CSG (2 << 1) in the raw kbase ring wait.
4. Print .csg or .system in the CSF decoder for wait instructions.

The Android arm64 build completed successfully after these changes (all five architecture variants and libvulkan_panfrost.so linked). The cdb8aa7 package was subsequently installed and exercised on the physical SM-X730 in a three-run AIO A/B; all three valid PanVK runs completed without the previously observed 0x88 / GROUP_ERROR_FATAL signatures in the captured log windows. This supports the candidate correction for the tested workload, but does not prove every CSF synchronization path is correct. The cited investigation also reports that adding the missing scope was a real bug but did not eliminate every 0x88 fault on its device.
## Controlled AIO A/B validation (2026-11-25)

A three-run AIO Vulkan cube A/B was completed on the physical SM-X730. Winlator has separate Renderer Driver and Vulkan Driver selectors; both were verified as System for the control and both as cdb8aa7 for PanVK. All runs used the same 1280x720 guest desktop and the same AIO arguments.

See [G925-AIO-AB-2026-11-25.md](G925-AIO-AB-2026-11-25.md) for raw values and limitations. Three-run means were 994.97 FPS / 254.10 1% low for System and 1,813.84 FPS / 430.05 1% low for PanVK (+82.3% average FPS, +69.2% 1% low in this synthetic workload).

Across the three valid cdb8aa7 PanVK logs, the loader opened the new libvulkan_panfrost.so; filtered logs contained no GROUP_ERROR_FATAL, 0x24c00488 / 0x88, SHAREABILITY_FAULT, VK_ERROR, or AIO assertion. This is encouraging runtime evidence for the CSG-scoped SYNC_WAIT candidate, but not a universal correctness proof or a real-game uplift claim.

An earlier mixed-driver benchmark (Renderer cdb8aa7, guest Vulkan a4b8b6b) was excluded from the A/B. PANVK_DEBUG=perf was not yet enabled, so the queue-submit timings needed for roadmap point 1 remain to be collected. BannerHub remains the next application-level validation target.
## Next validation steps

1. Repeat the AIO Vulkan cube workload in alternating PANVK_DEBUG=perf on/off conditions (at least three runs per condition) to estimate logging overhead and sample variance; the first successful capture is documented in [G925-PANVK-PERF-2026-11-25.md](G925-PANVK-PERF-2026-11-25.md).
2. Run the same fixed BannerHub scene on Container-1 (System) and PanVK_G925_Test, recording frame pacing and at least three runs per condition.
3. Use Android Perfetto and, where available, Mali G925 queue/MCU/memory counters to assess vertex/tiler, fragment and compute overlap.
4. Test G925 HSR prepass as a separate A/B experiment only after the baseline and submit telemetry are captured.

## Safety and reproducibility

- Keep Android's factory/system Vulkan driver unchanged.
- Keep `Container-1` on `System`; use `PanVK_G925_Test` for the custom driver.
- Retain the known-good PanVK package and its SHA-256 outside the source tree.
- Do not infer performance from the AIO window's initial cube rendering or from SurfaceFlinger queue FPS logs.
