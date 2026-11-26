# PanVK fork audit — 2026-11-26

Scope: all 23 forks listed by GitHub for `JimVulkan/mali-panvk`. Fork default branches were fetched into the isolated `work/fork-audit-repo` checkout and compared with upstream `58f2c55854bd48b18df756edb11f187af9cd2fde`. This audit is a screening pass; it does not claim every fork's downstream branch history is canonical upstream work.

Target context: our local driver is commit `be13e3a4131fc8f1000b4d5f59e3c83f21843475`, uses PanVK CSF on Immortalis-G925 MC12 (Mesa maps G925 to PAN_ARCH 13), and has existing uncommitted diagnostics. Fork code was not blindly cherry-picked. The working tree remains untouched beyond its pre-existing edits and the v12 fault report.

## Every fork

| Fork | Delta / useful insight | Decision for G925 CSF |
|---|---|---|
| [friformato9-sketch](https://github.com/friformato9-sketch/mali-panvk) | Setup scripts, VS Code settings, Helios-14/G925 notes only. | Useful local setup reference; no driver code. |
| [Liliya2727](https://github.com/Liliya2727/mali-panvk) | Four commits: JM Valhall layer-offset fix; JM/kbase import and submit/fault changes; MediaTek 5.10 sticky-resource and grow-on-fault behavior. | JM changes do not exercise this CSF path; kbase changes are kernel/platform-specific and unsupported by current evidence. No port. |
| [Maddoghavenosay](https://github.com/Maddoghavenosay/mali-panvk) | Identical to upstream. | No unique change. |
| [slaide](https://github.com/slaide/mali-panvk) | Identical to upstream. | No unique change. |
| [ViniciusC00-blip](https://github.com/ViniciusC00-blip/mali-panvk) | Android build workflow plus substantial DMA-BUF/AHardwareBuffer allocation/import changes and device-memory edits. | External-memory behavior is high risk and not shown necessary on Samsung G925. No port. |
| [mci-codex](https://github.com/mci-codex/mali-panvk) | Identical to upstream. | No unique change. |
| [crjesusraul-del](https://github.com/crjesusraul-del/mali-panvk) | CI workflow/build automation only. | No runtime driver improvement. |
| [An7ik11er](https://github.com/An7ik11er/mali-panvk) | CI and diagnostics/stability fixes mostly in JM; Bifrost FP32 transcendental quirk is explicitly for older architectures (up to v8); coherent-local exec BO fallback. | JM and v8 quirk are inapplicable; current G925 exec path provides no evidence for the fallback. No port. |
| [jeancssantos1996-svg](https://github.com/jeancssantos1996-svg/mali-panvk) | Identical to upstream. | No unique change. |
| [loddv](https://github.com/loddv/mali-panvk) | Identical to upstream. | No unique change. |
| [JesusChapman](https://github.com/JesusChapman/mali-panvk) | Build portability for macOS/older Android API and gralloc build selection. | Not relevant to this Android 16 device/build setup. No driver code to port. |
| [dendakaramus](https://github.com/dendakaramus/mali-panvk) | Identical to upstream. | No unique change. |
| [yqwert0987-code/mali-panvk-g1-ultra](https://github.com/yqwert0987-code/mali-panvk-g1-ultra) | 81 commits/41 files: geometry/tessellation emulation, Bifrost compiler/RA work, CSF changes, opt-in stats, descriptor/TLS reuse and extensive custom diagnostics. Target repository is G1 Ultra (PAN_ARCH 14); G925 is PAN_ARCH 13. | Best source of future experiments. Isolated zero-live-node skipping in Bifrost RA may reduce compiler CPU time and is a candidate for measured A/B validation. Opt-in stats can inform a telemetry design. Descriptor/TLS reuse and GS/tessellation are larger feature/risk areas. Nothing ported yet: test compiler equivalence and quantify before integration. |
| [dissidius](https://github.com/dissidius/mali-panvk-harmonyos4.2-android12) | Huawei-specific 32-byte kbase MEM_IMPORT ABI handling and CI. | Samsung kernel ABI differs; no port. |
| [Pro-Termux-arch](https://github.com/Pro-Termux-arch/mali-panvk) | Identical to upstream. | No unique change. |
| [Revodum](https://github.com/Revodum/mali-panvk) | Identical to upstream. | No unique change. |
| [zombieloko2016-source](https://github.com/zombieloko2016-source/mali-panvk) | Identical to upstream. | No unique change. |
| [Wasidulislam](https://github.com/Wasidulislam/mali-panvk) | Identical to upstream. | No unique change. |
| [kingyagamy](https://github.com/kingyagamy/mali-panvk) | One kernel patch changes ring-full waits from fixed 50-us sleeps to initial yields then capped backoff with a 10-s deadline; remaining unique commits are CI. | Plausible kbase CPU/latency experiment but modifies shared submission behavior and is not a demonstrated renderer correctness/performance win. Keep as a separate follow-up; do not mix into fault diagnosis. |
| [ar37-rs](https://github.com/ar37-rs/mali-panvk) | Older branch at upstream ancestor `d896b0a`; no unique code. | No candidate. |
| [Cadu0910](https://github.com/Cadu0910/mali-panvk) | Same older upstream ancestor `d896b0a`; no unique code. | No candidate. |
| [sandibabsel](https://github.com/sandibabsel/mali-panvk) | CI plus fallback gralloc plane-info discovery for TECNO/MediaTek allocator handles. | Platform-specific; not Samsung G925 evidence. No port. |
| [OursCodeur](https://github.com/OursCodeur/mali-panvk) | Older RG35XX/Mali-G31/Wayland branch; has focused JM fixes, Bifrost uniform descriptor-range handling, and tests for that target. | The descriptor-range/compiler and JM changes deserve source-level review against current upstream before reuse; the branch is old and its tested platform is G31, so no direct cherry-pick. The huge loader/Wayland additions are unrelated. |

## Candidate disposition

1. **Bifrost register allocator live-node scan (yqwert fork):** strongest general CPU-side candidate. Port only the zero-live-byte scan in a separate branch; compare compiled shader outputs and shader compile times, then benchmark multiple workloads. Do not take its optional spill-policy switches with it.
2. **Adaptive kbase ring wait (kingyagamy):** possible CPU scheduling improvement, but kernel wait policy is separate from the observed GPU fault and should only be trialed with latency/CPU measurements and ring stress coverage.
3. **PANVK_STATS (yqwert fork):** useful as a model for per-second draw/CPU timing telemetry. Avoid importing its large G1-specific diagnostics module; implement focused local counters if needed.
4. **Descriptor pool reuse, TLS sharing, GS/tessellation emulation:** potentially useful for specific workloads, but too broad and concurrency-sensitive for adoption without workload evidence and isolated tests.
5. **CSF indexed count immediate patch:** it changes a later upstream dynamic-count path that is absent in local `be13e3a`; no equivalent hunk exists to port safely.

## Conclusion

This audit yields no validated performance or compatibility patch suitable for immediate inclusion. The promising work is now identified with explicit validation gates rather than copied wholesale. No fork patch was imported, no commit was created, and no GitHub push was made. The full fetch/comparison artifacts are in `work/panvk-fork-audit-summary.txt` and `work/panvk-fork-comparisons.json` for this session.
