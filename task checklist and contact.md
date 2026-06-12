# task checklist and contact

Branch: origin_vespa_tdx

## Hard rules

- Original `python/chan.py` remains the only Chan calculation engine.
- Flutter/Dart must not recreate Chan FX/BI/SEG/ZS/BSP logic.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Bridge fallback is not accepted as a completed native result.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- Normal Windows workflow uses App-managed bundled Python.
- Validation mode and strategy mode must stay separate.
- No strategy signal may be accepted unless Copy Signal proves source BSPs, native relation range, strict-step visibility, and signal state.
- Speed optimization must not replace chan.py calculation semantics.
- No `fast` / `turbo` / `极速` mode may be accepted without same-request result validation proving no meaningful deviation from original chan.py output.
- Step-frame compact export may change App adapter transport/export shape only; it must not change chan.py core output semantics.
- No Chan result cache is accepted. F1f accepted only a raw K-line cache.
- Performance work is now stopped after F1k. Do not continue with F1l/F1m unless a new manual exception is explicitly proven and recorded first.
- New business/runtime work must default to the accepted high-speed path while retaining the slow path only as a temporary baseline/debug/validation path.
- Legacy Dart-side Chan calculation logic must be removed or neutralized. Flutter/Dart may keep data models, parsers, rendering adapters, and validation UI only; it must not compute FX/BI/SEG/ZS/BSP.

## Runtime path terminology

- **High-speed path / 高速路**: the accepted App runtime path using App-managed Python, original `python/chan.py` / `CChan(lv_list=[...])`, raw K-line cache, compact-first step export, `compact_v1`, lazy frame parsing, lazy indicator parsing, and the existing validation diagnostics.
- **Slow path / 慢速路**: the legacy baseline/debug/validation path. It is not the default user path and must not be used as the main development path.
- High-speed path is not an algorithmic fast Chan implementation. Chan calculation authority remains original `python/chan.py`.

## Latest important commits

- `25a7bbce2d0f2d78ba625d5e591b30d8881578e3`: reuse app-managed Python backend across source/page rebuilds.
- `fbd0a979eb48c181a06b36da5e9c2a926ce6420f`: accept F1d warm backend reuse.
- `773f428864e42766c4368bb839c9e5bb70d92d3d`: accept F1e native timing decomposition.
- `5e2a6f5e525908b04bdcbacd6062555e0ce55e6a`: accept F1f raw data cache reuse.
- `4860e0ee5aa54b22da19978eb4ef2e93388f6690`: accept F1g step export decomposition.
- `31af043bd41298e9a643d036b6716d53180b7ee3`: accept F1h compact-first step export.
- `829b5c4a0e060a18cb91919678034b298518eb51`: accept F1i backend residual decomposition.
- `82f0dc610ed41012b5c8d7142917e4c77cd5f47f`: surface frontend top snapshot parse timings.
- `06db968caa093ecb10914ab0420582571beb0478`: lazily parse Easy TDX indicator payloads.
- `b07ffd859f24db2ff7c6430baa2bd6d44a540f4e`: accept F1j and F1k, then stop the performance optimization chain.
- `45aaeaa64138a7f907a84f662de2ac62ac2cbc8f`: expose runtime path diagnostics in interval signal copy gates.
- Current update: record B1a Copy Gate diagnostics progress. B1a is not accepted until the runtime path dropdown and Copy P0 diagnostics are completed.

## Current accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A active-route strict step replay: accepted.
- Batch B native `LevelRelation` targeting: accepted for DAILY->MIN30 and MIN30->MIN5.
- Batch C arbitrary BSP pair strict-step validation: accepted using real easy-tdx/original chan.py data.
- P0 Time Log instrumentation: accepted.
- F0 Copy Result Validation blocked gate: accepted.
- F1a compact-v1 transport equivalence: accepted.
- F1b post-compact performance measurement: accepted.
- F1c lazy frame parsing: accepted.
- F1d backend lifecycle diagnostics and warm backend reuse: accepted.
- F1e backend route and native-internal timing decomposition: accepted.
- F1f process-local raw K-line data-load cache reuse: accepted.
- F1g step export sub-stage timing decomposition: accepted.
- F1h compact-first step frame export: accepted.
- F1i backend residual structure-export decomposition: accepted.
- F1j frontend top snapshot parse decomposition: accepted.
- F1k lazy Easy TDX indicator parsing: accepted.
- Performance chain F1a-F1k: stopped by rule; return to business/runtime task chain.
- B1a runtime path Copy Gate diagnostics: implementation progress only, not accepted.

## Accepted runtime baseline

Accepted test request:

- symbol `600340`, market `SH`.
- levels `DAILY,MIN30,MIN5`.
- count `220`.
- max_step_frames `60`.
- start/end `2025-09-01` to `2025-10-20`.
- mode `step`.
- selected pair `DAILY->MIN30`.
- rule mode `validation_any_bsp_pair`.

Accepted optimized warm-run state after F1k:

- `frontend.total: 2461ms`.
- `frontend.http_round_trip: 2079ms`.
- `frontend.parse.top_snapshot: 144ms`.
- `frontend.parse.top_snapshot.single_level.indicators: 0ms`.
- `frontend.parse.snapshot_frames_relations_bsp: 144ms`.
- Copy Step remained strict backend step frame.
- Result Validation remained accepted:
  - `validation_status: match`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
  - `fallback_to_bridge: false`.
  - `native_cchan_lv_list: true`.

## Performance chain summary F1a-F1k

- F1a accepted compact_v1 transport equivalence.
- F1b measured the post-compact bottlenecks.
- F1c accepted lazy frame parsing.
- F1d accepted warm app-managed backend reuse.
- F1e decomposed backend route/native timings.
- F1f accepted process-local raw K-line cache only, not Chan result cache.
- F1g decomposed step export timing.
- F1h accepted compact-first step frame export.
- F1i decomposed residual backend structure export.
- F1j decomposed frontend top snapshot parse.
- F1k accepted lazy Easy TDX indicator parsing.
- The performance chain is now stopped by rule.

## Performance optimization stop rule after F1k

F1j was the final planned diagnostic pass. F1k was opened only because F1j proved a single 800ms+ frontend indicator parse bottleneck and met the exception rule.

After F1k:

- The exceptional indicator bottleneck is resolved.
- No new single frontend stage remains above `800ms-1000ms`.
- Do not continue performance work by default.
- Return to the business/runtime task chain.

## Phase B1: runtime path switch and legacy Dart Chan cleanup

Selected next task.

Goal:

- Make the accepted high-speed path the default runtime path.
- Temporarily keep the slow path in a dropdown for baseline/debug/validation only.
- Remove or neutralize legacy Dart-side Chan calculation logic so Flutter/Dart cannot compute FX/BI/SEG/ZS/BSP.
- Preserve original `python/chan.py` as the only Chan calculation authority.

### B1a: runtime path dropdown

Required UI behavior:

- Add a runtime path dropdown with exactly these user-facing choices:
  - `高速路（默认）`
  - `慢速路（原始校验/调试）`
- Default value must be `高速路（默认）`.
- Strategy mode, validation mode, and normal replay must use the high-speed path by default.
- Slow path must be manually selectable only for debugging, baseline comparison, or validation investigation.
- Slow path must not silently become the default after restart, page rebuild, exception, or fallback.

Required diagnostics in Copy Time Log and Copy P0:

- `runtime_path: high_speed | slow_path`.
- `high_speed_enabled: true | false`.
- `slow_path_enabled: true | false`.
- `runtime_path_default: high_speed`.
- `runtime_path_policy: high_speed_default_slow_path_debug_only`.
- Existing diagnostics must remain visible:
  - `validation_status`.
  - `compact_validation_status`.
  - `fallback_to_bridge`.
  - `native_cchan_lv_list`.
  - raw data cache diagnostics.
  - F1g/F1h/F1i/F1j/F1k timing fields for regression checks.

B1a progress so far:

- Commit `45aaeaa64138a7f907a84f662de2ac62ac2cbc8f` adds runtime path diagnostics to interval signal Copy Signal / Copy Time Log / Copy Result Validation.
- Current diagnostics default to `runtime_path: high_speed`, `high_speed_enabled: true`, `slow_path_enabled: false`, `runtime_path_default: high_speed`, `runtime_path_policy: high_speed_default_slow_path_debug_only`.
- B1a is not accepted yet because the main runtime path dropdown and Copy P0 diagnostics are still pending.

High-speed path must use:

- App-managed bundled Python backend.
- Original `python/chan.py` / `CChan(lv_list=[...])`.
- F1f raw K-line cache.
- compact-first step frame export.
- `compact_v1` transport.
- lazy frame parsing.
- lazy Easy TDX indicator parsing.
- Copy Time Log / Copy Step / Copy P0 / Copy Result Validation gates.

Slow path rules:

- Slow path is retained temporarily as a baseline/debug/validation reference.
- Slow path must still use original `python/chan.py` for Chan calculation.
- Slow path must not contain or call Dart-side Chan calculation.
- Slow path must not be used to hide backend fallback or validation failure.
- Slow path retirement may be considered only after high-speed path passes multiple business-chain acceptances and the manual explicitly records `slow path retired`.

B1a acceptance criteria:

- Dropdown is visible in the relevant runtime panel.
- Default selection is `高速路（默认）`.
- Copy Time Log and Copy P0 show the selected runtime path and default policy.
- High-speed path remains accepted with:
  - `validation_status: match`.
  - `compact_validation_status: match`.
  - `fallback_to_bridge: false`.
  - `native_cchan_lv_list: true`.
  - `frame_source: native_step_frame` for Copy Step.
  - `final_snapshot_rendered_as_step: false`.
- Slow path can be selected manually for debug/baseline only.

### B1b: delete or neutralize legacy Dart-side Chan calculation

Required cleanup:

- Search the Dart/Flutter codebase for any implementation that calculates Chan structures, including but not limited to:
  - FX / fractal calculation.
  - BI / stroke calculation.
  - SEG / segment calculation.
  - ZS / center calculation.
  - BSP / buy-sell point calculation.
  - include/merge K-line algorithm used as Chan calculation.
  - step replay generated from final snapshot slicing.
- Remove those Dart-side calculation implementations, or convert them into passive DTO/model/parser/rendering code only.
- Keep Dart models/parsers/renderers only if they consume backend output and do not calculate Chan structures.
- If a Dart file is kept for compatibility, add clear comments that it is a parser/model/rendering adapter and not a Chan calculation engine.
- Any old Dart Chan service/calculator class must either be deleted or made unreachable from runtime paths.

Required evidence:

- Code search summary must be pasted into the manual or task result.
- Evidence must show no active Dart-side FX/BI/SEG/ZS/BSP calculation path remains.
- Build/analysis must pass after cleanup.
- Copy Step must still show backend strict step frame.
- Copy Result Validation must remain match on the accepted baseline request.

B1b acceptance criteria:

- No active Dart-side Chan calculator remains in runtime code.
- Flutter/Dart only parses, renders, validates, and switches runtime path.
- Original `python/chan.py` remains the only calculation engine.
- App can still run high-speed path successfully.
- Slow path, if present, still calls original `python/chan.py`, not Dart Chan logic.

Forbidden in B1:

- Do not reintroduce Flutter/Dart Chan calculation under another name.
- Do not remove the accepted high-speed path.
- Do not remove slow path in this task; only make it debug/baseline and non-default.
- Do not implement algorithmic fast/极速 mode.
- Do not introduce Chan result cache.
- Do not fake step replay from final snapshot.
- Do not modify `python/chan.py` core algorithm.

## Current blockers / pending verification

- No speed/fast/turbo/极速 mode is accepted yet.
- Algorithmic fast mode remains prohibited until a stricter validation plan is written and accepted.
- Chan result cache remains prohibited.
- Full-history/paged strict step replay remains deferred.
- Performance chain F1a-F1k is stopped by rule.
- Runtime path switch and Dart Chan cleanup B1 is now the selected next task.
- B1a runtime path dropdown is still pending.
- B1b Dart-side Chan cleanup/search evidence is still pending.
- Strategy mode runtime acceptance should resume after B1 unless this manual explicitly selects another business-chain item.
