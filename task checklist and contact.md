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
- `7ee8d60148756c175c0c095c28da9400dce2be2a`: add shared runtime path policy model/controller.
- `3c3ead9e8724d29091b10323b9e60f2c8c01fce3`: add visible global runtime path dropdown.
- `982ab7dc66e57a3ea3cd7a97d257e2fa00d2541b`: attach selected runtime path to analyze_multi Time Log and meta.
- `b85aef4fafd3b5d644fc3f533e1fb483f009da72`: wire selected runtime path into Copy P0 and Copy Step.
- `3085d9390d0dc70e8c59e2abd7da975326d57287`: move runtime path dropdown away from header to avoid overlap with Load/request controls.
- `077a1d11c8228a45cb14b1d3b360ccdf3214a51c`: remove Dart-side dummy merged-bar synthesis from Chan snapshot parser.
- `d839c0c6b4963b933cf94e1f9fa7c842caeea343`: route single-level source parsing through passive Chan snapshot parser and remove duplicate Dart-side structure parser.
- Current update: record B1b single-level source cleanup. B1b is still pending broader Dart-side search evidence, build analysis, and runtime validation.

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
- B1a runtime path dropdown and copy diagnostics: accepted.
- B1b Dart-side Chan cleanup/search evidence: in progress, not accepted.

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

Selected task chain.

Goal:

- Make the accepted high-speed path the default runtime path.
- Temporarily keep the slow path in a dropdown for baseline/debug/validation only.
- Remove or neutralize legacy Dart-side Chan calculation logic so Flutter/Dart cannot compute FX/BI/SEG/ZS/BSP.
- Preserve original `python/chan.py` as the only Chan calculation authority.

### B1a: runtime path dropdown

Accepted.

Implemented:

- Runtime path dropdown with exactly these user-facing choices:
  - `高速路（默认）`.
  - `慢速路（原始校验/调试）`.
- Default value is `高速路（默认）`.
- Dropdown was moved away from the top-right header area and placed in the bottom-left area beside the route toolbar to avoid overlap with `Load`, mode chips, and request controls.
- Runtime path diagnostics are attached to:
  - Copy Time Log.
  - Copy P0.
  - Copy Step.
  - Copy Result Validation via interval-signal panel.
- The selected runtime path is attached to frontend request context, response meta, and time_log.
- Runtime path is a routing/diagnostic policy only; it does not implement Dart Chan calculation.

Accepted high-speed validation output:

- Copy Time Log included:
  - `runtime_path: high_speed`.
  - `high_speed_enabled: true`.
  - `slow_path_enabled: false`.
  - `runtime_path_default: high_speed`.
  - `runtime_path_policy: high_speed_default_slow_path_debug_only`.
  - `native_cchan_lv_list: true`.
  - `fallback_to_bridge: false`.
  - `step_frame_format: compact_v1`.
  - `frames_total: 29`.
  - `frames_returned: 29`.
  - `include_bars_in_frames: false`.
  - `include_indicators_in_frames: false`.
  - `lazy_frame_parsing: true`.
  - `status: ok`.
- Copy P0 included:
  - `runtime_path: high_speed`.
  - `high_speed_enabled: true`.
  - `slow_path_enabled: false`.
  - `runtime_path_default: high_speed`.
  - `runtime_path_policy: high_speed_default_slow_path_debug_only`.
  - `strict_step_blocked: false`.
  - `native_cchan_lv_list: true`.
  - `level_relation_mode: chan_parent_child`.
  - `fallback_to_bridge: false`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
- Copy Step included:
  - `runtime_path: high_speed`.
  - `high_speed_enabled: true`.
  - `slow_path_enabled: false`.
  - `frame_source: native_step_frame`.
  - `final_snapshot_rendered_as_step: false`.
  - `native_cchan_lv_list: true`.
  - `fallback_to_bridge: false`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
- Copy Result Validation included:
  - `validation_status: match`.
  - `mismatch_count: 0`.
  - `runtime_path: high_speed`.
  - `high_speed_enabled: true`.
  - `slow_path_enabled: false`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
  - `status: ok`.

Accepted slow-path debug validation output:

- Manual switch to `慢速路（原始校验/调试）` was reflected in Copy Time Log and Copy P0.
- Copy Time Log included:
  - `runtime_path: slow_path`.
  - `high_speed_enabled: false`.
  - `slow_path_enabled: true`.
  - `runtime_path_default: high_speed`.
  - `runtime_path_policy: high_speed_default_slow_path_debug_only`.
  - `backend_last_request_reused: true`.
  - `native_cchan_lv_list: true`.
  - `fallback_to_bridge: false`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
  - `status: ok`.
- Copy P0 included:
  - `runtime_path: slow_path`.
  - `high_speed_enabled: false`.
  - `slow_path_enabled: true`.
  - `runtime_path_default: high_speed`.
  - `runtime_path_policy: high_speed_default_slow_path_debug_only`.
  - `strict_step_blocked: false`.
  - `native_cchan_lv_list: true`.
  - `fallback_to_bridge: false`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.

B1a conclusion:

- Dropdown visibility and default behavior are accepted.
- Runtime path diagnostics are accepted in Copy Time Log, Copy P0, Copy Step, and Copy Result Validation.
- High-speed path remains the default.
- Slow path is manually selectable only and retains `runtime_path_default: high_speed`.
- B1a is accepted.

### B1b: delete or neutralize legacy Dart-side Chan calculation

In progress.

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

Implementation progress:

- Commit `077a1d11c8228a45cb14b1d3b360ccdf3214a51c` updates `lib/data/chan_snapshot_json_parser.dart`.
- `ChanSnapshotJsonParser` is now explicitly documented as a passive backend JSON -> Dart DTO adapter.
- The parser now states that it must not synthesize or calculate Chan structures and that `python/chan.py` remains the sole Chan calculation authority.
- Removed the old `_dummyMergedBar` fallback that synthesized one Dart `MergedBar` per raw bar when backend `merged_bars` was absent.
- `structuralMergedBars` now uses only backend-exported `merged_bars`.
- This removes the first identified Dart-side Chan structure synthesis path.
- Commit `d839c0c6b4963b933cf94e1f9fa7c842caeea343` updates `lib/data/python_chan_analysis_source.dart`.
- `PythonChanAnalysisSource` no longer maintains a duplicate single-level Dart parser for FX/BI/SEG/ZS/BSP DTO construction.
- Single-level backend JSON parsing now routes through the passive `ChanSnapshotJsonParser.parse()` adapter.
- This removes the remaining known active single-level `_dummyMergedBar` fallback and reduces parser drift.

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
- Runtime path switch and Dart Chan cleanup B1 is now the selected task chain.
- B1a runtime path dropdown/copy diagnostics is accepted.
- B1b parser cleanup has started; broader Dart-side search evidence, build analysis, and runtime validation are still pending.
- Strategy mode runtime acceptance should resume after B1 unless this manual explicitly selects another business-chain item.
