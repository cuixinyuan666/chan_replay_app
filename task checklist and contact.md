# task checklist and contact

Branch: origin_vespa_tdx

## Manual update protocol

- Highest priority: answer open questions before changing this manual.
- Use explicit labels: `Question to task party: ...` and `Question to supervising party: ...`.
- If a question blocks acceptance, keep the task pending.
- If no question is open, record `open_questions: none`.
- For large manual updates, prefer a compact form: hard rules, accepted status, current task, sample/offline data rule, blockers, and next operation.
- If a large write is blocked, reduce scope and update only the smallest useful section.
- Task party must summarize similar tooling/manual/code problems with: problem, failed approach, reduced-scope approach, final resolution, and future recommendation.

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

In progress.

open_questions: none

Resolved supervisor question:

- Question to supervising party: `test/fixtures/research_pipeline_contract_valid.json` is a relevant offline research pipeline contract fixture, but it cannot reproduce the selected S1 request (`600340`, `SH`, `DAILY,MIN30,MIN5`, `2025-09-01~2025-10-20`) because it uses synthetic `TEST.LOCAL` data from `2024-01-01~2024-01-12` and single-level analysis JSON. `build/real_analysis.json` is referenced by README but is not present in the repository. May S1 proceed using the live accepted easy-tdx baseline plus Copy Time Log / Copy P0 / Copy Step / Copy Result Validation / strategy diagnostics, or must a matching offline fixture be added first?
- Answer from supervising party: S1 may proceed using the live accepted easy-tdx baseline because the only checked offline fixture is relevant but not suitable for the selected S1 runtime acceptance. The exception is accepted only for this S1 request. S1 still requires high-speed runtime diagnostics, Copy Time Log, Copy P0, Copy Step, Copy Result Validation, and strategy diagnostics proving source BSP identifiers, source/target levels, native relation range, strict-step visibility, state, and rule/mode name. A matching offline fixture is recommended later but is not required before this S1 can proceed.

S1 explicit answers before closure:

- Offline data answer: the repository fixture is relevant but not suitable for the selected S1 request, and the supervisor has accepted a live baseline exception only for this S1. Therefore S1 may proceed with live easy-tdx baseline evidence; no matching offline fixture is required before implementation or runtime validation, but a matching fixture remains recommended later.
- One-click copy answer: S1 must not be closed until a consolidated evidence-copy action is completed. The accepted target is a `Copy S1 Evidence` / one-click equivalent that copies, in one payload, Time Log, P0, Step, Result Validation, and Signal diagnostics for the selected live high-speed request. The current separate Copy buttons are useful but not sufficient to close S1 because they increase the chance of missing one required diagnostic.

Goal:

- Resume business-chain work after B1.
- Validate strategy mode on the accepted high-speed path.
- Prove strategy mode does not bypass validation gates.
- Prove every accepted strategy output is traceable to backend BSPs, native relation range, strict-step visibility, and rule state.

Required runtime path:

- Default path must be high-speed: `runtime_path: high_speed`.
- Slow path is debug/baseline only and must not be the accepted strategy runtime path.
- S1 must not start F1l/F1m or any new performance phase.

S1 sample/offline data report:

- `sample_data_available: true` for a relevant research pipeline fixture, but not usable for selected S1 runtime acceptance.
- searched paths or patterns:
  - commit search: `600340`, `600340.SH`, `SH600340`, `csv`, `sample`, `fixture`, `fixtures`, `offline`, `test data`, `sample data csv`, `tdx data`.
  - README references: `test/fixtures/research_pipeline_contract_valid.json`, `build/real_analysis.json`, `tools/validate_research_pipeline_contract.py`.
- matching files:
  - `test/fixtures/research_pipeline_contract_valid.json`.
  - `tools/validate_research_pipeline_contract.py`.
- relevant because:
  - the fixture is a chan.py-style analysis JSON with bars, BI, SEG, ZS, BSP, indicators, and meta `engine: chan.py`.
  - the validator explicitly consumes an exported chan.py analysis JSON and runs `extract_bsp_features -> score_bsp_features -> run_bsp_backtest` without importing or modifying `chan.py`.
- cannot be used for selected S1 acceptance because:
  - fixture symbol is `TEST.LOCAL`, not `600340.SH`.
  - fixture dates are `2024-01-01~2024-01-12`, not `2025-09-01~2025-10-20`.
  - fixture is single-level top-level analysis JSON, not selected multi-level `DAILY,MIN30,MIN5` with native LevelRelation range.
  - fixture has `frames: []`, so it cannot prove strict-step native frame visibility.
  - README-referenced `build/real_analysis.json` is not present in the repository.
- proposed alternative verification:
  - use live accepted easy-tdx baseline request already defined in this manual;
  - require high-speed runtime path diagnostics;
  - require Copy Time Log, Copy P0, Copy Step, Copy Result Validation;
  - require strategy diagnostics proving source BSP identifiers, source/target levels, native relation range, strict-step visibility, state, and rule/mode name.
- `sample_data_used: false`.
- `sample_data_supervisor_decision: accepted_for_this_S1_request`.

S1 strategy wiring audit:

- Existing `MultiLevelIntervalSignalPanel` already exposes strategy mode through `rule mode = strategy` and the strategy rule dropdown.
- Strategy rules currently supported:
  - `DAILY_2B_MIN30_1B`.
  - `DAILY_3B_MIN30_1B`.
  - `DAILY_3B_MIN30_2B`.
- Strategy mode locks the selected pair to `DAILY->MIN30` and uses backend-exported BSPs plus native `LevelRelation` only.
- `Copy Signal` selected-signal diagnostics already include:
  - high/low BSP index, type, raw index, time, price, confirmed flag, BI/SEG/ZS references;
  - high/low source levels and strategy type/trigger type;
  - parent relation range, child relation range, child union range, relation count;
  - `strict_step_verified`, `visibleAt.frame`, `confirmedAt.frame`, `state`, and `signal_state`;
  - `signal_rule_mode`, `rule_mode_ui`, `strategy_rule_name`, `candidate_rule`, `source_policy`, `future_function_policy`, and warnings.
- `Copy Signal` no-output diagnostics include BSP counts, type counts, relation count, candidate rule, source policy, future policy, and diagnosis.
- `Copy Time Log` from the signal panel includes runtime path diagnostics, `native_cchan_lv_list`, `fallback_to_bridge`, compact step-frame transport fields, request context, and strategy rule fields.
- `Copy Result Validation` from the signal panel includes validation status, compact validation status, runtime path diagnostics, selected pair, rule mode, strategy rule name, baseline level counts, sample BSP, and sample relation.
- The remaining S1 UX/diagnostic task is the one-click evidence-copy action described above; S1 cannot be accepted until this is completed or an equivalent single-copy payload is proven.

S1 required evidence:

- sample/offline data search/use report;
- Copy Time Log;
- Copy P0;
- Copy Step;
- Copy Result Validation;
- Copy Signal;
- consolidated one-click S1 evidence output.

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
- Sample/offline data exception is accepted for this S1 request only.
- Accepted strategy output must include source BSP identifiers, source/target levels, native relation range, strict-step visibility, state, and rule/mode name.
- One-click S1 evidence copy is completed and includes Time Log, P0, Step, Result Validation, and Signal diagnostics.

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
- S1 Strategy mode runtime acceptance is in progress.
- S1 sample/offline data exception is adjudicated and no longer blocks implementation.
- S1 one-click evidence copy action must be completed before S1 closure.
- S1 live high-speed runtime evidence is still required before acceptance.

## Next task-party operation

1. Implement or wire a consolidated `Copy S1 Evidence` action that emits Time Log, P0, Step, Result Validation, and Signal diagnostics in one clipboard payload.
2. Run the accepted live easy-tdx baseline request in the App on the default high-speed path.
3. In the interval signal panel, set `rule mode` to `strategy` and select a strategy rule.
4. Copy and paste: the consolidated S1 evidence output, plus individual diagnostics if needed for debugging.
5. Keep runtime path dropdown unchanged: high-speed default, slow path debug/baseline only.
6. Keep Dart/Flutter as parser/renderer/validator only.
7. Add a short experience note if the task encounters complex tooling/manual/code problems.
8. Accept S1 only if high-speed path, validation, strict backend step, accepted sample/offline exception, one-click evidence copy, and traceability requirements all pass.
