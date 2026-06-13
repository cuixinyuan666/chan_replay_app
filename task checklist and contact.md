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
- `5e2a6f5e525908b04bdcbacd6062555e6a`: accept F1f raw data cache reuse.
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
- `1bfeb709fa4b65155aa347b908791d848a109245`: remove unnecessary lazy frame cast so `flutter analyze` is clean.
- `302ed08a667c0c461b1e225c1712aacee5b4f2cf`: accept B1b Dart-side Chan cleanup.
- Current update: record supervisor verification of B1 and select S1 Strategy mode runtime acceptance.

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
- B1b Dart-side Chan cleanup/search evidence: accepted with the supervisor caveat below.

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

Accepted.

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
- Runtime path diagnostics are attached to Copy Time Log, Copy P0, Copy Step, and Copy Result Validation via interval-signal panel.
- The selected runtime path is attached to frontend request context, response meta, and time_log.
- Runtime path is a routing/diagnostic policy only; it does not implement Dart Chan calculation.

Accepted high-speed validation output:

- Copy Time Log included `runtime_path: high_speed`, `high_speed_enabled: true`, `slow_path_enabled: false`, `runtime_path_default: high_speed`, `runtime_path_policy: high_speed_default_slow_path_debug_only`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, `step_frame_format: compact_v1`, `frames_total: 29`, `frames_returned: 29`, `include_bars_in_frames: false`, `include_indicators_in_frames: false`, `lazy_frame_parsing: true`, and `status: ok`.
- Copy P0 included `runtime_path: high_speed`, `high_speed_enabled: true`, `slow_path_enabled: false`, `runtime_path_default: high_speed`, `runtime_path_policy: high_speed_default_slow_path_debug_only`, `strict_step_blocked: false`, `native_cchan_lv_list: true`, `level_relation_mode: chan_parent_child`, `fallback_to_bridge: false`, `compact_validation_status: match`, and `compact_validation_mismatch_count: 0`.
- Copy Step included `runtime_path: high_speed`, `high_speed_enabled: true`, `slow_path_enabled: false`, `frame_source: native_step_frame`, `final_snapshot_rendered_as_step: false`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, `compact_validation_status: match`, and `compact_validation_mismatch_count: 0`.
- Copy Result Validation included `validation_status: match`, `mismatch_count: 0`, `runtime_path: high_speed`, `high_speed_enabled: true`, `slow_path_enabled: false`, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, and `status: ok`.

Accepted slow-path debug validation output:

- Manual switch to `慢速路（原始校验/调试）` was reflected in Copy Time Log and Copy P0.
- Copy Time Log included `runtime_path: slow_path`, `high_speed_enabled: false`, `slow_path_enabled: true`, `runtime_path_default: high_speed`, `runtime_path_policy: high_speed_default_slow_path_debug_only`, `backend_last_request_reused: true`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, and `status: ok`.
- Copy P0 included `runtime_path: slow_path`, `high_speed_enabled: false`, `slow_path_enabled: true`, `runtime_path_default: high_speed`, `runtime_path_policy: high_speed_default_slow_path_debug_only`, `strict_step_blocked: false`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, `compact_validation_status: match`, and `compact_validation_mismatch_count: 0`.

B1a conclusion:

- Dropdown visibility and default behavior are accepted.
- Runtime path diagnostics are accepted in Copy Time Log, Copy P0, Copy Step, and Copy Result Validation.
- High-speed path remains the default.
- Slow path is manually selectable only and retains `runtime_path_default: high_speed`.
- B1a is accepted.

### B1b: delete or neutralize legacy Dart-side Chan calculation

Accepted.

Implementation:

- Commit `077a1d11c8228a45cb14b1d3b360ccdf3214a51c` updates `lib/data/chan_snapshot_json_parser.dart`.
- `ChanSnapshotJsonParser` is now explicitly documented as a passive backend JSON -> Dart DTO adapter.
- The parser now states that it must not synthesize or calculate Chan structures and that `python/chan.py` remains the sole Chan calculation authority.
- Removed the old `_dummyMergedBar` fallback that synthesized one Dart `MergedBar` per raw bar when backend `merged_bars` was absent.
- `structuralMergedBars` now uses only backend-exported `merged_bars`.
- Commit `d839c0c6b4963b933cf94e1f9fa7c842caeea343` updates `lib/data/python_chan_analysis_source.dart`.
- `PythonChanAnalysisSource` no longer maintains a duplicate single-level Dart parser for FX/BI/SEG/ZS/BSP DTO construction.
- Single-level backend JSON parsing now routes through the passive `ChanSnapshotJsonParser.parse()` adapter.
- Commit `1bfeb709fa4b65155aa347b908791d848a109245` removes the final `unnecessary_cast` warning in the multi-level source.

Search and code review evidence:

- `_dummyMergedBar` search returned no remaining result after cleanup.
- `OriginReplayStrictPage` uses backend `analysis.frames` for step mode and does not render final snapshot as step.
- `PythonChanAnalysisSource` now routes backend JSON snapshot/frame parsing through `ChanSnapshotJsonParser.parse()`.
- `MultiLevelChanAnalysisParser` is a compact transport / relation parser and does not calculate Chan structures.
- `OriginKlineChart` renders existing snapshot raw bars / merged bars / FX / BI / SEG / ZS / BSP and does not calculate Chan structures.
- `ResearchBacktestPage` and `ResearchBackendClient` send current analysis JSON to the Python research backend and require `engine: chan.py`.
- `MultiLevelIntervalSignalPanel` filters backend BSP + native LevelRelation into business signal candidates; it does not calculate FX/BI/SEG/ZS/BSP.

Accepted runtime evidence:

- Copy Step included `frame_source: native_step_frame`, `final_snapshot_rendered_as_step: false`, `runtime_path: high_speed`, `high_speed_enabled: true`, `slow_path_enabled: false`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, `native_step_frames: true`, `native_step_frames_total: 29`, `native_step_frames_returned: 29`, `step_frame_format: compact_v1`, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, and `status_summary.current_frame` reported `runtime_path:high_speed relations:9 frames:29`.
- Copy Result Validation included `validation_status: match`, `mismatch_count: 0`, `runtime_path: high_speed`, `high_speed_enabled: true`, `slow_path_enabled: false`, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, and `status: ok`.
- `flutter analyze` output: `No issues found!`.

B1b conclusion:

- No known active Dart-side Chan calculator remains in the checked runtime paths.
- Flutter/Dart now parses, renders, validates, switches runtime path, and performs business signal filtering only.
- Original `python/chan.py` remains the only Chan calculation authority.
- Strict step replay remains backend-native and is not final-snapshot slicing.
- B1b is accepted.

### Supervisor verification after B1

Verified against commit `302ed08a667c0c461b1e225c1712aacee5b4f2cf`.

Manual verification:

- The manual correctly records B1a and B1b as accepted.
- The manual keeps the F1a-F1k performance chain stopped by rule.
- The manual does not accept speed/fast/turbo/极速 mode.
- The manual keeps algorithmic fast mode, Chan result cache, Flutter/Dart Chan calculation, final-snapshot fake step replay, and `python/chan.py` core changes prohibited.

Code verification performed:

- `lib/data/chan_snapshot_json_parser.dart` states it is a passive backend JSON -> Dart DTO adapter and must not synthesize or calculate Chan structures.
- `ChanSnapshotJsonParser` uses backend-exported `merged_bars` only; `_dummyMergedBar` is absent.
- `PythonChanAnalysisSource` parses backend responses through `ChanSnapshotJsonParser.parse()` and no longer keeps duplicate single-level structure parsing logic.
- `PythonMultiLevelChanAnalysisSource` sends `runtime_path` in the backend request context and uses `RuntimePathController` diagnostics.
- `PythonMultiLevelChanAnalysisSource` parses top-level and lazy frame data through `MultiLevelChanAnalysisParser` plus `ChanSnapshotJsonParser.parse()`.
- `MultiLevelChanAnalysisParser` inflates compact transport payloads for display by restoring visible bars/indicators from backend base levels; it parses relations but does not calculate FX/BI/SEG/ZS/BSP.
- Repository search for `_dummyMergedBar` returned no result.

Supervisor caveat:

- The checked parser/source/runtime path code supports B1 acceptance.
- Full assurance still depends on keeping future business features from reintroducing Dart-side Chan calculators under a new name.
- Any future strategy/signal work must continue to provide Copy Signal, Copy Step, Copy P0, and Copy Result Validation evidence.

Supervisor conclusion:

- B1 progress is acceptable.
- No obvious task drift was found in the checked code paths.
- The project should now move to S1 Strategy mode runtime acceptance.

## Phase S1: Strategy mode runtime acceptance

Selected next task.

Goal:

- Resume business-chain work after B1.
- Validate strategy mode on the accepted high-speed path.
- Prove strategy mode does not bypass existing validation gates.
- Prove every accepted strategy signal is traceable to backend BSPs, native LevelRelation range, strict-step visibility, and signal state.

Required runtime path:

- Default path must be `高速路（默认）` / `runtime_path: high_speed`.
- Slow path may be used only for debug/baseline comparison and must not be the accepted strategy runtime path.
- S1 must not start F1l/F1m or any new performance phase.

S1 required evidence:

- Copy Time Log.
- Copy P0.
- Copy Step.
- Copy Result Validation.
- Copy Signal for each accepted strategy signal.
- If strategy mode produces no signal, Copy Signal or equivalent Copy Strategy Diagnostic must prove why no signal was accepted.

S1 acceptance criteria:

- `runtime_path: high_speed`.
- `high_speed_enabled: true`.
- `slow_path_enabled: false`.
- `runtime_path_default: high_speed`.
- `runtime_path_policy: high_speed_default_slow_path_debug_only`.
- `validation_status: match`.
- `compact_validation_status: match`.
- `compact_validation_mismatch_count: 0`.
- `fallback_to_bridge: false`.
- `native_cchan_lv_list: true`.
- Copy Step remains `frame_source: native_step_frame`.
- `final_snapshot_rendered_as_step: false`.
- Copy Signal must include source BSP identifiers, source/target levels, native relation range, strict-step visibility, signal state, and rule/mode name.
- No strategy signal is accepted if its source BSP or LevelRelation range cannot be traced to backend/native output.

Forbidden in S1:

- Do not reintroduce Dart-side Chan calculation.
- Do not calculate FX/BI/SEG/ZS/BSP in Flutter/Dart for strategy mode.
- Do not use slow path as default runtime.
- Do not accept bridge fallback as native strategy result.
- Do not use final snapshot slicing as strict step replay.
- Do not add Chan result cache.
- Do not modify `python/chan.py` core algorithm.
- Do not reopen performance optimization unless a new manual exception is explicitly proven first.

## Current blockers / pending verification

- No speed/fast/turbo/极速 mode is accepted yet.
- Algorithmic fast mode remains prohibited until a stricter validation plan is written and accepted.
- Chan result cache remains prohibited.
- Full-history/paged strict step replay remains deferred.
- Performance chain F1a-F1k is stopped by rule.
- Runtime path switch and Dart Chan cleanup B1 is accepted.
- S1 Strategy mode runtime acceptance is now selected.

## Next task-party operation

1. Implement or wire Strategy mode runtime acceptance on the high-speed path only.
2. Keep runtime path dropdown unchanged: high-speed default, slow path debug/baseline only.
3. Keep Dart/Flutter as parser/renderer/validator only; do not reintroduce Chan calculation.
4. Re-run the accepted baseline request or an explicitly documented strategy-mode test request.
5. Paste Copy Time Log, Copy P0, Copy Step, Copy Result Validation, and Copy Signal / Copy Strategy Diagnostic.
6. Accept S1 only if strategy mode uses high-speed path, validation remains match, strict step remains backend-native, and every accepted signal is traceable to backend BSP + native LevelRelation + strict-step visibility.
7. If S1 passes, next business-chain candidate is interval-nest buy rule acceptance or full-history/paged strict step replay, selected explicitly in this manual.
