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
- No algorithmic fast / turbo / speed mode is accepted.
- No Chan result cache is accepted. F1f accepted only a raw K-line cache.
- Performance work is stopped after F1k unless a new manual exception is proven and recorded first.
- Runtime work must default to the accepted high-speed path. The slow path is temporary baseline/debug/validation only.

## Accepted runtime baseline

- symbol `600340`, market `SH`.
- levels `DAILY,MIN30,MIN5`.
- count `220`.
- max_step_frames `60`.
- start/end `2025-09-01` to `2025-10-20`.
- mode `step`.
- selected pair `DAILY->MIN30`.

## Accepted work summary

- P0 App-managed bundled Python backend: accepted.
- Batch A/B/C: accepted.
- F1a-F1k performance chain: accepted and stopped by rule.
- B1a runtime path dropdown and copy diagnostics: accepted.
- B1b Dart-side Chan cleanup/search evidence: accepted.
- S1 Strategy mode runtime acceptance: accepted.

## Phase S1: Strategy mode runtime acceptance

Accepted.

open_questions: none

Supervisor sample-data adjudication:

- The repository fixture is relevant but not suitable for selected S1.
- The live easy-tdx baseline exception is accepted for this S1 request only.
- A matching offline fixture is recommended later but not required before this S1 acceptance.

S1 one-click evidence implementation:

- Commit `4f9b56162f4ce6bb7d5751da0c663d1a8bfac160` adds `Copy S1 Evidence` to `MultiLevelIntervalSignalPanel`.
- The action emits one clipboard payload containing S1 header, sample exception state, runtime path policy, Time Log diagnostics, P0 summary, Step summary, Result Validation, and Signal diagnostics.
- This is diagnostics aggregation only. It introduces no Dart-side Chan calculation.

S1 accepted evidence:

- Received payload type: `manual S1 evidence diagnostics` / `button: Copy S1 Evidence`.
- `open_questions: none`.
- `sample_data_supervisor_decision: accepted_for_this_S1_request`.
- `sample_data_used: false`.
- `rule_mode_ui: strategy`.
- `signal_rule_mode: strategy_interval_nest_buy`.
- `strategy_rule_name: DAILY_2B_MIN30_1B`.
- `runtime_path: high_speed`.
- `high_speed_enabled: true`.
- `slow_path_enabled: false`.
- `runtime_path_default: high_speed`.
- `runtime_path_policy: high_speed_default_slow_path_debug_only`.
- `fallback_to_bridge: false`.
- `native_cchan_lv_list: true`.
- `frame_source: native_step_frame`.
- `final_snapshot_rendered_as_step: false`.
- Time Log proved App-managed bundled Python, `CChan(lv_list)` native path, `compact_v1`, `frames_total: 29`, `frames_returned: 29`, and no bridge fallback.
- P0 Summary proved `level_relation_mode: chan_parent_child`, `relations.length: 9`, `python_runtime: app_bundled`, and no fallback.
- Step Summary proved native step frame, no final-snapshot step, `compact_validation_status: match`, and `compact_validation_mismatch_count: 0`.
- Result Validation proved `validation_status: match`, `mismatch_count: 0`, `compact_validation_status: match`, and `compact_validation_mismatch_count: 0`.
- Signal diagnostics proved no-output strategy state for frame 0:
  - `available_signals: 0`.
  - `source_bsp_identifiers: none`.
  - `source_levels: DAILY,MIN30`.
  - `target_levels: DAILY->MIN30`.
  - `strict_step_frame_mode: true`.
  - `native_relation_count_for_pair: 1`.
  - `candidate_rule: DAILY_2B_MIN30_1B: 2-buy at DAILY + 1-buy at MIN30; low trigger BSP must be inside native child range`.
  - `source_policy: original chan.py BSP + native LevelRelation only`.
  - `future_function_policy: current strict step frame only; no final snapshot signal confirmation`.
  - `status: no signal for current rule scope`.
- `flutter analyze` after pulling latest `origin_vespa_tdx` returned `No issues found!`.

S1 conclusion:

- Strategy mode runtime acceptance is accepted for the selected live baseline request.
- The no-output strategy diagnostic is accepted because it proves the strategy rule, source policy, selected pair, native relation scope, strict-step visibility, and absence of matching source BSPs in the current strict step frame.
- This acceptance does not accept any trading recommendation, speed mode, bridge fallback, Dart-side Chan calculation, final-snapshot fake step replay, or Chan result cache.
- The live baseline sample-data exception is accepted for this S1 request only.

## Current blockers / pending verification

- No algorithmic fast/turbo/speed mode is accepted.
- Chan result cache remains prohibited.
- Full-history/paged strict step replay remains deferred.
- Performance chain F1a-F1k is stopped by rule.
- A matching offline fixture for the selected S1 request is still recommended later, but it is not blocking S1.

## Next task-party operation

1. Do not continue performance optimization by default.
2. Preserve high-speed as default and slow path as debug/baseline only.
3. Preserve Flutter/Dart as parser/renderer/validator only.
4. Choose the next business-chain task before implementation.
