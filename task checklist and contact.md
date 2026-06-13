# task checklist and contact

Branch: origin_vespa_tdx

## Hard rules

- Original `python/chan.py` remains the only Chan calculation engine.
- Flutter/Dart must not calculate Chan FX/BI/SEG/ZS/BSP.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Bridge fallback is not accepted as a completed native result.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- Normal Windows workflow uses App-managed bundled Python.
- Validation mode and strategy mode must stay separate.
- Strategy output must be traceable to backend BSPs, native relation range, strict-step visibility, and rule state.
- No algorithmic fast / turbo / 极速 mode is accepted.
- No Chan result cache is accepted. F1f accepted only a raw K-line cache.
- Performance work is stopped after F1k. Do not continue with F1l/F1m unless a new manual exception is proven and recorded first.
- Runtime work must default to the accepted high-speed path. The slow path is temporary baseline/debug/validation only.
- If repository sample/offline data can reproduce a task, acceptance must prefer that data. If it cannot be used, the task party must document the reason and wait for supervisor adjudication.

## Runtime path terminology

- High-speed path / 高速路: App-managed Python + original `python/chan.py` + `CChan(lv_list=[...])` + raw K-line cache + compact-first step export + `compact_v1` + lazy frame parsing + lazy indicator parsing + validation diagnostics.
- Slow path / 慢速路: temporary baseline/debug/validation path only. It is not the default user path and must not become the main development path.
- High-speed path is not a new Chan algorithm. Calculation authority remains original `python/chan.py`.

## Offline sample validation rule

Before accepting any new task, the task party must check whether the repository contains sample/offline data that can reproduce the task.

If usable sample data exists:

- record `sample_data_available: true`;
- record `sample_data_paths`;
- use it for at least one validation run or comparison.

If sample data exists but cannot be used:

- record searched paths;
- record matching files;
- record why the files are relevant;
- record why they cannot be used;
- record proposed alternative verification;
- record `sample_data_supervisor_decision: pending`.

If no relevant sample data exists:

- record `sample_data_available: false`;
- record searched paths or patterns.

The supervisor decides whether a reason for not using repository sample data is acceptable.

## Accepted work summary

- P0 App-managed bundled Python backend: accepted.
- Batch A active-route strict step replay: accepted.
- Batch B native LevelRelation targeting: accepted.
- Batch C arbitrary BSP pair strict-step validation: accepted.
- P0 Time Log instrumentation: accepted.
- F0 Copy Result Validation blocked gate: accepted.
- F1a-F1k performance chain: accepted and stopped by rule.
- B1a runtime path dropdown and copy diagnostics: accepted.
- B1b Dart-side Chan cleanup/search evidence: accepted with supervisor caveat.

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
- Result Validation remained accepted with `validation_status: match`, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, `fallback_to_bridge: false`, and `native_cchan_lv_list: true`.

## B1 supervisor verification

Verified against commit `302ed08a667c0c461b1e225c1712aacee5b4f2cf`.

- B1a and B1b are accepted.
- F1a-F1k remains stopped by rule.
- No speed/fast/turbo/极速 mode is accepted.
- Chan result cache remains prohibited.
- Flutter/Dart Chan calculation remains prohibited.
- Final-snapshot fake step replay remains prohibited.
- `python/chan.py` core changes remain prohibited.
- Checked parser/source/runtime path code supports B1 acceptance.
- Future business work must not reintroduce Dart-side Chan calculators under a new name.

## Phase S1: Strategy mode runtime acceptance

Selected next task.

Goal:

- Resume business-chain work after B1.
- Validate strategy mode on the accepted high-speed path.
- Prove strategy mode does not bypass validation gates.
- Prove every accepted strategy output is traceable to backend BSPs, native relation range, strict-step visibility, and rule state.

Required runtime path:

- Default path must be high-speed: `runtime_path: high_speed`.
- Slow path is debug/baseline only and must not be the accepted strategy runtime path.
- S1 must not start F1l/F1m or any new performance phase.

S1 must include a sample/offline data report:

- `sample_data_available`.
- `sample_data_paths` when applicable.
- `sample_data_used` when applicable.
- `sample_data_unusable_reason` when applicable.
- `sample_data_supervisor_decision` when applicable.

S1 required evidence:

- sample/offline data search/use report;
- Copy Time Log;
- Copy P0;
- Copy Step;
- Copy Result Validation;
- strategy output diagnostic, or no-output diagnostic.

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
- Sample/offline data rule is satisfied or adjudicated by the supervisor.
- Accepted strategy output must include source BSP identifiers, source/target levels, native relation range, strict-step visibility, state, and rule/mode name.

Forbidden in S1:

- Do not reintroduce Dart-side Chan calculation.
- Do not calculate FX/BI/SEG/ZS/BSP in Flutter/Dart for strategy mode.
- Do not use slow path as default runtime.
- Do not accept bridge fallback as native strategy result.
- Do not use final snapshot slicing as strict step replay.
- Do not add Chan result cache.
- Do not modify `python/chan.py` core algorithm.
- Do not reopen performance optimization unless a new manual exception is proven first.
- Do not bypass sample/offline data validation when suitable repository data exists.

## Current blockers / pending verification

- No speed/fast/turbo/极速 mode is accepted yet.
- Algorithmic fast mode remains prohibited.
- Chan result cache remains prohibited.
- Full-history/paged strict step replay remains deferred.
- Performance chain F1a-F1k is stopped by rule.
- Runtime path switch and Dart Chan cleanup B1 is accepted.
- S1 Strategy mode runtime acceptance is now selected.
- Sample/offline data search/use report is required for S1 acceptance.

## Next task-party operation

1. Search the repository for sample/offline data relevant to the selected S1 test request.
2. Record sample/offline data availability, paths, and use status.
3. If relevant data can be used, run at least one S1 validation using it or compare against it.
4. If relevant data cannot be used, document the reason and wait for supervisor adjudication before claiming acceptance.
5. Implement or wire Strategy mode runtime acceptance on the high-speed path only.
6. Keep runtime path dropdown unchanged: high-speed default, slow path debug/baseline only.
7. Keep Dart/Flutter as parser/renderer/validator only.
8. Paste Copy Time Log, Copy P0, Copy Step, Copy Result Validation, and strategy diagnostics.
9. Accept S1 only if high-speed path, validation, strict backend step, sample/offline rule, and traceability requirements all pass.
