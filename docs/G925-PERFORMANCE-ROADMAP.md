# G925 PanVK Performance Investigation

## Scope and baseline

Target: Arm Immortalis-G925 (Pan model v13), Android kbase CSF path, Mesa 27.0.0-devel PanVK.
Baseline source: `a4b8b6b` (the fork commit used for the initial BannerHub-compatible package).

The goal is to improve real game frame time and frame pacing without weakening Vulkan synchronization, changing the stock system driver, or tuning against a synthetic workload that does not represent BannerHub.

## Ranked optimization candidates

### 1. CSF queue overlap and kbase submit stalls — first investigation

PanVK creates three CSF subqueues: vertex/tiler (binning), fragment (main rendering), and compute. The kbase submit path maps command-buffer streams onto those queues. When a semaphore wait cannot be associated with a prior submission in the same kbase CSF group, PanVK falls back to a CPU-side wait on all syncobjs. That can stall the application thread before subsequent work is submitted.

The submission path also allocates and assembles kbase CS-call arrays and signals completion for the three subqueues. These are correctness-sensitive mechanisms. First measure CPU fallback wait time, command stream count/bytes per subqueue, CPU preparation time and kbase submit-call latency; then correlate with GPU queue-overlap traces. Do not remove waits or alter completion semantics without an A/B correctness test.

### 2. G925 HSR prepass and Z/S tile interleaving

G925 (PAN_ARCH >= 13) has hardware HSR prepass controls in its framebuffer descriptor. The current PanVK path only sets `allow_hsr_prepass` when `PANVK_DEBUG=hsr_prepass` is enabled. The descriptor builder further gates the prepass on Z/S tile-buffer interleaving (`pan_fb_can_pipeline_zs`, or the equivalent tile-budget check).

This is a high-value experiment for overdraw-heavy scenes, but not a safe unconditional default: the source explicitly warns that HSR prepass without interleaving can be detrimental. A/B it only on supported G925 workloads and keep depth/stencil correctness, frame time, GPU active cycles and external-memory traffic under observation.

### 3. End-of-command-buffer cache cleaning

For every non-idle subqueue, `finish_cs()` emits an L2 and LS-cache clean before command-buffer memory can be recycled. This protects against stale dirty cache lines overwriting data written by the CPU after the command pool reuses memory. It may contribute to GPU queue drain/serialization, but the clean has a documented memory-reuse correctness purpose. Measure its frequency and cost before considering a narrower lifetime/flush strategy.

### 4. Tiler heap, tile size and core allocation

G925's model and device profile expose tiler heap chunk sizing and compute/fragment core masks. Review initial/max heap chunks, tile-buffer budgets, and the number of shader cores allowed to compute/fragment queues. Tune against real game traces; do not assume maximum core allocation is always optimal or that more tile memory always improves FPS.

### 5. Shader/pipeline warm-up and specialization

PanVK already has precompiled helper shaders, a disk shader cache and precompiled-shader cache handling. Turnip's broader lesson is to treat pipeline creation, specialization, cache misses and expensive render-pass patterns as workload data. Investigate shader compile stalls and pipeline cache hit rate separately from GPU execution time before changing compiler heuristics.

### 6. Feature gaps versus pure performance gaps

The current project notes that sparse resources are unavailable through its kbase path (no GPU page remapping) and mesh shaders are not supported on the current Bifrost/Valhall implementation. These are API capability gaps, not the first explanation for low FPS in existing games. Verify extension exposure and app fallback behavior before treating them as a performance issue.

## Turnip comparison: transferable ideas vs non-transferable hardware

Turnip has useful engineering patterns worth studying: adaptive per-render-pass profiling/autotuning, GPU timestamp and sample-based feedback, pipeline/shader specialization, and careful synchronization/resource lifetime management.

Do not port Adreno-only mechanisms literally:
- LRZ is an Adreno hardware feature; use Mali early-ZS/HSR/CRC mechanisms instead.
- GMEM/VSC and Adreno CCU/UCHE cache policies are not Mali's tiler/cache architecture.
- Adreno command-processor packets and ring-buffer scheduling are not interchangeable with Mali CSF command streams.

The appropriate PanVK equivalent to Turnip's autotuning is to profile Mali-native choices (HSR prepass, tile/heap parameters, queue overlap, cache maintenance and shader variants), with G925-specific measurements and safe fallbacks.

## First implementation on this branch

Added opt-in `PANVK_DEBUG=perf` telemetry for the Android kbase CSF submit path. For each regular command submission it logs:
- CPU-side submission preparation time;
- CPU semaphore-wait fallback duration and whether that fallback occurred;
- time spent in the kbase CSF submit call;
- command-buffer count, internal BC refresh presence and total CS-call count;
- command-call count and stream bytes for vertex/tiler, fragment and compute.

This flag does not request extra GPU synchronization and does not change waits, queue priorities, cache operations or command streams. It is intended to separate CPU submission stalls from queue workload distribution. Present-only wait/signal fast-path submissions return before this log and are not counted.

Runtime switch: `PANVK_DEBUG=perf`.

## Measurement protocol

1. Keep the factory/system driver intact. Use the custom PanVK package only through the existing custom-driver loader with a reversible selection.
2. Pick a fixed BannerHub scene, resolution, graphics settings and frame-rate cap. Record at least three runs per configuration; discard first-run shader-cache warm-up from steady-state comparison and also record it separately.
3. Capture CPU/GPU timeline with Android Perfetto. Inspect binning, fragment and compute queue overlap; sync waits; cache flushes; CPU submission gaps.
4. Where available, correlate with G925 counters: queue-active cycles, GPU-active cycles, interrupt-pending cycles, MCU-active cycles and external-memory read/write stalls.
5. Compare baseline versus `PANVK_DEBUG=perf`, then baseline versus `PANVK_DEBUG=hsr_prepass` as a separate A/B experiment. Do not combine flags when attributing an FPS change.
6. Only change behavior after a repeatable bottleneck is identified. Preserve the untouched system driver and a known-good PanVK ZIP for rollback.

## Latest physical-device validation

See [`G925-RUNTIME-VALIDATION-2026-11-25.md`](G925-RUNTIME-VALIDATION-2026-11-25.md) for the first SM-X730 runtime attempts. PanVK custom-library loading is confirmed; both PanVK and the separate System-driver AIO attempts hit CSF group faults, so no valid FPS comparison or PanVK-specific root cause has been established yet.

## CSF synchronization correctness investigation

The first physical G925 run exposed GROUP_ERROR_FATAL / exception 0x88. Source review found missing Scope metadata and emission on SYNC_WAIT32/64 in the CSF path. A candidate CSG-scope correction is implemented in the current branch worktree and builds successfully; see [G925-RUNTIME-VALIDATION-2026-11-25.md](G925-RUNTIME-VALIDATION-2026-11-25.md). Do not treat it as a confirmed fix until the rebuilt package is tested on the physical SM-X730 with the same workload and fault logs are rechecked.
## Physical G925 AIO A/B checkpoint (2026-11-25)

Three AIO Vulkan cube runs per driver were completed with the Winlator Renderer Driver and guest Vulkan Driver both verified on each condition. PanVK cdb8aa7 averaged 1,813.84 FPS versus 994.97 FPS on System (+82.3% in this synthetic benchmark); 1% low averaged 430.05 versus 254.10 (+69.2%). The three valid PanVK logs showed no recurrence of the earlier CSF 0x88 fault. Raw results and limitations are in [G925-AIO-AB-2026-11-25.md](G925-AIO-AB-2026-11-25.md).

This is not a BannerHub/game FPS claim. Point 1 is still open: enable and collect PANVK_DEBUG=perf submit telemetry, then validate the same workloads in BannerHub and inspect Mali-native queue overlap.
## Status

- [x] Add opt-in kbase submit diagnostics.
- [x] Build Android AArch64 PanVK package.
- [ ] Collect BannerHub baseline and diagnostic logs on the physical G925 device.
- [ ] A/B test G925 HSR prepass.
- [ ] Select and implement the first behavior-changing optimization based on measurements.
