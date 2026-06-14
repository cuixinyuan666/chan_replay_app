# task checklist and contact

Branch: origin_vespa_tdx

## Open questions

open_questions: none

## Hard rules

- Original `python/chan.py` is the only Chan calculation engine.
- Flutter/Dart must not calculate FX/BI/SEG/ZS/BSP.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- Bridge fallback, Chan result cache, and algorithmic fast/turbo/speed mode are not accepted.
- High-speed path remains default; slow path is debug/baseline only.
- Prefer repository offline/sample data for validation when it can reproduce the task.

## Receiver workload minimization rule

- Prefer command-line validation over App validation when a command can verify the same requirement with less receiver work.
- If a pinned/offline validator exists for the current stage, the preferred receiver path is: `git pull` then run the documented validator command.
- Use App validation only when command-line validation cannot verify UI-specific behavior.
- After each small stage, task party must write a completion summary into this manual.

Required completion summary fields:

- completed_tasks
- evidence_button
- validation_result
- remaining_risk
- next_task

## Accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A/B/C: accepted.
- F1a-F1k performance chain: accepted and stopped by rule.
- B1a runtime path dropdown and copy diagnostics: accepted.
- B1b Dart-side Chan cleanup/search evidence: accepted.
- S1 Strategy mode runtime acceptance: accepted.
- S2 pinned offline fixture export for accepted S1 baseline: accepted.
- S3 pinned S1 fixture offline validator: accepted.
- R1 receiver burden code cleanup: accepted by App evidence.
- R1b CLI receiver-burden validation: accepted.
- S4 CLI strategy diagnostics validator: accepted.
- S5 CLI strategy rule matrix validation: accepted.
- S6 strategy signal sample coverage: accepted.
- S7 App strategy signal display loop: accepted.
- S8a CLI scanner / batch candidate output: accepted.
- S8b App scanner / batch candidate navigation: accepted.
- S8 scanner / batch strategy output: accepted.
- S9 local generated artifact hygiene and continuation baseline: accepted.
- S10 analyze_multi long-history window count expansion: accepted by receiver CLI evidence.
- S11 post-S10 guardrail regression bundle: accepted by receiver CLI evidence.
- S12a App single-stock replay high-speed baseline static validation: accepted by receiver CLI evidence.

## Current selected task

S12b selected: replay evidence button, indicator default-hidden state, and explicit level-validation feedback.

## S1-S3 summary

- S1 accepted with `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B`.
- S2 accepted pinned fixture export: `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- S3 accepted pinned S1 fixture CLI validation with compact match, native lv_list, no bridge fallback, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, and no Chan recalculation.

remaining_risk:

- The pinned fixture is about 7.06 MB. Prefer this fixture or a smaller derived metadata sample for later checks.

## R1/R1b summary

- R1 accepted by App evidence. It made `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B` the S1-like defaults, kept `S1一键复制`, and de-emphasized low-level debug copy buttons.
- R1b accepted by CLI validation: `python tools/validate_r1_receiver_burden.py`.

## S4 accepted: CLI strategy diagnostics validator

completed_tasks:

- Added `tools/validate_s4_cli_strategy_diagnostics.py`.
- Validated the pinned S1 fixture, source policy, relation pairs, BSP availability/no-output diagnosis, strict-step frame evidence, compact validation, bridge fallback absence, native lv_list, and forbidden Dart-side Chan calculation markers.

evidence_button:

- CLI command: `python tools/validate_s4_cli_strategy_diagnostics.py`.

validation_result:

- accepted.
- Receiver output included `ok: true`, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, strict-step evidence, compact match, native lv_list, no fallback, no forbidden Dart-side markers, and no Chan recalculation.

remaining_risk:

- None for S4 CLI acceptance.

next_task:

- S4 accepted. Continue S5 and S6.

## S5 accepted: CLI strategy rule matrix validation

completed_tasks:

- Added `tools/validate_s5_cli_strategy_rule_matrix.py`.
- Validated `DAILY_2B_MIN30_1B`, `DAILY_3B_MIN30_1B`, and `DAILY_3B_MIN30_2B`.

evidence_button:

- CLI command: `python tools/validate_s5_cli_strategy_rule_matrix.py`.

validation_result:

- accepted.
- Receiver output included `ok: true`, all three required strategy rules, strict-step evidence, compact match, native lv_list, no fallback, no forbidden Dart-side markers, and no Chan recalculation.

remaining_risk:

- The pinned fixture reports no matched output for all three S5 rules. This is acceptable for S5 matrix/no-output validation.
- S6 must prove both no-output and matched-output diagnostic paths.

next_task:

- S5 accepted. Start S6 by default.

## S6 accepted: strategy signal sample coverage

completed_tasks:

- Added `tools/export_s6_strategy_matched_sample.py` and `tools/validate_s6_strategy_signal_sample_coverage.py`.
- Added/validated `test/fixtures/derived/s6_strategy_matched_sample_v1.json` as backend-traceable matched-output metadata.

evidence_button:

- Export command: `python tools/export_s6_strategy_matched_sample.py`.
- Validation command: `python tools/validate_s6_strategy_signal_sample_coverage.py`.

validation_result:

- accepted.
- Receiver export output included `ok: true`, matched rule `DAILY_2B_MIN30_1B`, source BSP identifiers `DAILY#4:raw=334:type=B2s;MIN30#21:raw=2672:type=B1`, relation range `parent=334:child=2672-2679`, compact match, native lv_list, and no fallback.
- Receiver validation output included `ok: true`, no-output path, matched-output path, traceability fields, no forbidden Dart-side markers, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.

remaining_risk:

- S6 validates diagnostic coverage, not chart display behavior. S7 must verify App display, marking, selection, and navigation behavior.

next_task:

- Start S7 App strategy signal display loop.

## S7 accepted: App strategy signal display loop

completed_tasks:

- Added `tools/validate_s7_app_strategy_signal_display_loop.py`.
- Wired selected strategy signal, chart marker objects, raw-index/time jump, and App copy evidence around the Interval strategy panel.
- Changed multi-level replay toward a chart-first layout with collapsible/floating controls.

evidence_button:

- CLI/static command: `python tools/validate_s7_app_strategy_signal_display_loop.py`.
- Analyzer command: `flutter analyze`.
- App evidence button: `S1一键复制` in the `Interval strategy` panel.

validation_result:

- accepted.
- Receiver static validator output included `ok: true`, selected-signal callback, Jump callback, page signal reception, raw-index jump, chart marker wiring, chart overlay markers, no forbidden Dart-side Chan calculation markers, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver App evidence included `s7_phase: app_strategy_signal_display_loop`, `available_signals: 2`, rule `DAILY_2B_MIN30_1B`, target levels `DAILY->MIN30`, native relation range, strict-step visibility, state `confirmed`, raw/time/price fields, and chart marker id.

remaining_risk:

- Visual confirmation of marker rendering and Jump positioning remains receiver-side observational evidence.
- Exact visual comfort depends on screen size and DPI.

next_task:

- Start S8 scanner / batch strategy output.

## S8 accepted: scanner / batch strategy output

completed_tasks:

- Added `tools/export_s8_strategy_batch_candidates.py`.
- Added `tools/validate_s8_strategy_batch_candidates.py`.
- Added `lib/ui/pages/s8_strategy_batch_page.dart` and the `S8批量候选` route.
- Added `tools/validate_s8_app_batch_navigation.py`.
- The App page reads the locally generated S8 candidate JSON, displays candidates, opens the clicked candidate through the existing multi-level backend path, jumps to the candidate `jump_target`, marks the chart with `s8_batch_candidate_marker`, and copies traceability evidence.

evidence_button:

- Export command: `python tools/export_s8_strategy_batch_candidates.py`.
- Validation command: `python tools/validate_s8_strategy_batch_candidates.py`.
- CLI/static command: `python tools/validate_s8_app_batch_navigation.py`.
- Analyzer command: `flutter analyze`.
- App evidence button: `复制S8证据` in the `S8 traceability evidence` panel.

validation_result:

- accepted.
- S8a accepted by CLI exporter and validator.
- S8b accepted by static App validator and receiver App evidence.
- Receiver outputs included `ok: true`, `candidate_count: 20`, `attempt_count: 2`, sample `600340.SH`, rule `DAILY_2B_MIN30_1B`, source BSP identifiers `DAILY#4:raw=334:type=B2s;MIN30#21:raw=2672:type=B1`, native relation range `parent=334:child=2672-2679`, jump target `MIN30 raw_index=2672`, no native violations, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.

remaining_risk:

- Generated batch output is intentionally local and not committed; rerun the exporter when local backend/data changes.
- Visual marker comfort depends on screen size and chart zoom.

next_task:

- Start S9 local generated artifact hygiene and continuation baseline.

## S9 accepted: local generated artifact hygiene and continuation baseline

completed_tasks:

- Deleted local generated/backup files from the receiver working tree.
- Restored Windows generated files and accidental manual edit.
- Classified `backend/app/a_multilevel_native_engine.py` as a real backend functionality patch, not cleanup noise.

evidence_button:

- Receiver commands: `git status --short`, `git diff -- backend/app/a_multilevel_native_engine.py`, `git diff --stat`, and targeted `git restore` commands.

validation_result:

- accepted.
- Local generated files were deleted and Windows generated files were restored.

remaining_risk:

- `backend/app/a_multilevel_native_engine.py` remained modified by design and was promoted to S10.

next_task:

- Start S10: formalize analyze_multi long-history window count expansion.

## S10 accepted: analyze_multi long-history window count expansion

completed_tasks:

- Formalized long-history count expansion around request `start` and `end`, instead of estimating from wall-clock time.
- Top-level and lower-level fetch counts are expanded from the same deterministic request window basis.
- Preserved backend authority in `python/chan.py` through native `CChan(lv_list=[...])`.
- Added `tools/validate_s10_long_history_count_expansion.py` as the dedicated CLI/static validator.
- Updated the S10 validator so later-stage regressions accept both `S10 selected` and `S10 accepted` manual states.
- Preserved the S8 long-window behavior for `2022-01-01` to `2025-12-31` while avoiding bridge fallback, cache fallback, or Dart-side Chan calculation authority.

evidence_button:

- S10 validation command: `python tools/validate_s10_long_history_count_expansion.py`.
- S8 export command: `python tools/export_s8_strategy_batch_candidates.py`.
- S8 validation command: `python tools/validate_s8_strategy_batch_candidates.py`.
- S8 App static command: `python tools/validate_s8_app_batch_navigation.py`.
- Analyzer command: `flutter analyze`.

validation_result:

- accepted.
- Receiver S10 output proved deterministic expansion for the S8 long window:
  - `DAILY`: `900 -> 1908`
  - `MIN30`: `900 -> 11764`
  - `MIN5`: `900 -> 68086`
- Receiver S10 checks passed for request-window parser, request `start/end` usage, expanded helper signature using window bounds, top-level prefetch expansion, lower-level window count expansion, metadata `requested_window`, metadata `count_expansion_basis`, preserved S8 window basis, native `CChan(lv_list)` authority, no bridge fallback or wall-clock count, and no Dart-side Chan calculation authority.
- Receiver S8 regression outputs included `ok: true` and no Dart-side Chan calculation authority.
- Receiver analyzer output included `No issues found!`.

remaining_risk:

- S10 validation is CLI/static evidence plus S8 regression evidence; visual App behavior remains covered by the existing S8 App static/App evidence chain.

next_task:

- Continue S11: post-S10 guardrail regression bundle.

## S11 accepted: post-S10 guardrail regression bundle

completed_tasks:

- Added `tools/validate_s11_guardrail_regression.py`.
- The validator runs S10 validation, S8 export, S8 output validation, S8 App static validation, global lazy-loading audit, and chan.py placement guardrail.
- Fixed `tools/audit_global_lazy_loading.py` so whitelisted root-page imports are not falsely blocked by substring matching.
- Updated S11 optional audits to review-only so non-S11 display-layout debt does not block the post-S10 guardrail bundle.
- Hardened S11 command execution: default per-command timeout is now 300 seconds, and timeout failures are captured as structured JSON instead of traceback.
- Preserved the rule that no S11 work modifies `python/chan.py` or adds Dart-side FX/BI/SEG/ZS/BSP calculation authority.

evidence_button:

- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Optional receiver command: `python tools/validate_s11_guardrail_regression.py --include-flutter-analyze`.

validation_result:

- accepted.
- Receiver S11 output included `ok: true`, `required_ok: true`, `flutter_ok: true`, `hygiene_ok: true`, `required_timeout_failure_count: 0`, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Required S11 chain passed:
  - `python tools/validate_s10_long_history_count_expansion.py`
  - `python tools/export_s8_strategy_batch_candidates.py`
  - `python tools/validate_s8_strategy_batch_candidates.py`
  - `python tools/validate_s8_app_batch_navigation.py`
  - `python tools/audit_global_lazy_loading.py --strict`
  - `python tools/check_chanpy_guardrails.py`
- Optional review-only audit still reported `audit_origin_kline_global_label_layout_usage.py --strict` failure: `_drawFx does not accept chartLabels`. This is not a blocker for S11 and remains display-layout debt for a later chart-label-layout task.

remaining_risk:

- The S8 exporter intentionally regenerates `test/fixtures/derived/s8_strategy_batch_candidates_v1.json` locally. Receivers should not commit that derived JSON by default.
- `audit_origin_kline_global_label_layout_usage.py --strict` still identifies an optional display-layout issue: FX labels are not yet migrated through the shared `ChartLabelLayout` path.

next_task:

- Start S12: App single-stock replay on accepted high-speed runtime path.

## S12a accepted: App single-stock replay high-speed baseline static validation

completed_tasks:

- Added `tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- Established a static baseline for single-stock replay on the accepted high-speed runtime path.
- Verified the existing App already has a visible multi-level single-stock replay entry, stock code input, market input, date window input, level selection UI, high-speed runtime path default, analyze_multi backend path, native `CChan(lv_list=[...])` authority, existing OriginKlineChart reuse, TradingView toolbox/easy-tdx entry, strict step frame usage, relation/signal locate hooks, and no Dart-side Chan calculation authority.
- Kept full S12 completion items as review-only instead of pretending the full S12 UI workflow is complete.

evidence_button:

- Receiver command: `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.

validation_result:

- accepted for S12a baseline only.
- Receiver S12a output included `ok: true`, `full_s12_completion: false`, empty `missing_baseline_required`, `chan_recalculated: false`, `dart_chan_calculation_authority: false`, and no forbidden profit/trading wording.
- Receiver S11 regression output after timeout hardening included `ok: true`, all required commands passed, no required timeout failures, no bridge/cache/Dart Chan authority regression, and `hygiene_ok: true`.
- Receiver analyzer output included `No issues found`.

remaining_risk:

- Full S12 is not complete. The S12a validator still reports these review-only gaps:
  - `explicit_s12_evidence_button_exists`
  - `indicator_display_hidden_by_default`
  - `invalid_level_combination_feedback_exists`
  - `temporal_state_provisional_confirmed_historical_exists`
  - `interval_link_marker_id_exists`
  - `marker_overlap_policy_marker_exists`
- `audit_origin_kline_global_label_layout_usage.py --strict` still reports `_drawFx does not accept chartLabels`; keep this as display-layout debt unless it is selected as the next specific chart-label task.

next_task:

- Start S12b: replay evidence button, indicator default-hidden state, and explicit level-validation feedback.

## S12b selected: replay evidence button, indicator default-hidden state, and explicit level-validation feedback

Goal:

- Convert the first three S12a review-only gaps into required behavior while preserving the high-speed single-stock replay baseline.

Scope:

- Add a visible `复制复盘证据` button in the single-stock replay workflow.
- Copied evidence must include at least `s12_phase: app_single_stock_replay_high_speed_path`, symbol, market, selected levels, normalized levels when different, active level, runtime path, mode, current step/frame, visible window, enabled Chan overlays, enabled easy-tdx indicators, source policy, backend authority, `dart_chan_calculation_authority: false`, and `candidate_policy: not a trading recommendation`.
- Make easy-tdx indicators hidden by default in the single-stock replay page. Users may enable indicators manually through the existing TradingView-style toolbox/indicator entrance only.
- Add explicit UI feedback for invalid or unsupported level combinations before `analyze_multi` is called.
- Report normalized level result when the App normalizes selected levels.
- Update `tools/validate_s12_app_single_stock_replay_high_speed_path.py` so the evidence button, default-hidden indicator state, and invalid-level feedback become required S12b checks.
- Do not modify `python/chan.py` Chan algorithms.
- Do not add Dart-side FX/BI/SEG/ZS/BSP/segseg calculation authority.
- Do not add profit prediction, trading recommendation, or automatic trading wording.

Acceptance evidence:

- Receiver command: `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Receiver App evidence: use one stock, one valid multi-level combination, one invalid combination attempt, then click `复制复盘证据` and paste the copied evidence.

remaining_risk:

- Temporal evidence state tracking, interval-link marker ids, and marker-overlap policy remain for later S12 sub-stages unless explicitly included in S12b implementation.
- The optional `_drawFx does not accept chartLabels` display-layout debt remains separate unless the supervisor selects it as the next chart-label-layout task.

## Next task-party operation

1. Receiver pulls latest `origin_vespa_tdx`.
2. Task party implements S12b in small changes.
3. Receiver runs `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
4. Receiver runs `python tools/validate_s11_guardrail_regression.py`.
5. Receiver runs `flutter analyze`.
6. Receiver shares S12b validator output and App replay evidence for acceptance.
