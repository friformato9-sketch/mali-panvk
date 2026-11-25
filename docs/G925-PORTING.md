# G-925 PanVK project setup

## Repository and baseline
- Fork: https://github.com/friformato9-sketch/mali-panvk
- Upstream: https://github.com/JimVulkan/mali-panvk
- Baseline branch: main, synced from upstream at 58f2c55854bd48b18df756edb11f187af9cd2fde
- Android package output is created by upstream `build.sh` as a ZIP containing `meta.json`, `libvulkan_panfrost.so`, and `NOTICE.txt`.

## Target
- Samsung Galaxy Tab S11
- MediaTek Dimensity 9400+
- Arm Immortalis-G925 MC12 (PanVK CSF / kbase)
- Android arm64, minimum API 31 per the upstream release package.

## Important engineering boundary
PanVK is a Mesa Vulkan ICD for the existing Android Mali kbase kernel driver (`/dev/mali0`). It is not a Windows GPU driver and does not replace the Windows translation layers. Eden, Bannerlator/Winlator and similar launchers need to support custom Vulkan driver ZIPs and load the ICD through their driver-loader namespace.

Do not add G-925-specific feature claims without device validation. Start by reproducing the upstream r10 build and comparing `vulkaninfo`, PanVK startup logs, swapchain presentation and emulator game workloads against the system Arm driver.

## Current host status (2026-11-25)
- Windows 10 Pro x64, Helios-14
- Git 2.52, GitHub CLI 2.102 authenticated as friformato9-sketch
- VS Code 1.140
- LLVM 23.1.5, Vulkan SDK 1.4.363.0
- Android SDK platform 35; Android NDK 28.2.13676358 (API 31 clang target available)
- WSL not installed; Windows optional-feature inspection requires elevation in this session.
- Upstream README tests r29 and Linux/WSL; NDK r29 is not currently present.

## Build prerequisites
See `build-support/helios14-wsl-setup.sh`. Use a fresh Ubuntu 24.04 WSL2 distribution and install the LLVM host toolchain versions matching the source requirements. Keep Windows-side Android SDK intact; install NDK r29 side-by-side rather than replacing r28.

## G-925 validation checklist
1. Confirm the device reports Immortalis-G925 / expected GPU product ID and kbase CSF support.
2. Confirm `/dev/mali0` access and kbase UAPI queries succeed from the launcher process.
3. Confirm ICD discovery and Vulkan 1.4 enumeration.
4. Run Vulkan CTS subsets for device creation, memory, descriptors, render pass, synchronization, formats, pipeline cache and WSI.
5. Verify Android gralloc import and presentation, including AFBC paths used by MediaTek.
6. Run Eden graphics tests and real titles; separately test Bannerlator/Winlator DXVK and VKD3D-Proton.
7. Capture `PANVK_DEBUG=startup`, Mesa logs, launcher logs, GPU faults and game repro details.
8. Only publish a fork-built ZIP after the binary has been tested on the actual Tab S11.

## Safety
Do not install the ICD as a system driver, replace vendor blobs, flash partitions, or alter kernel modules. Use the launcher's custom-driver import, keep the stock driver as fallback, and remove the test package from that launcher if it fails to load.
