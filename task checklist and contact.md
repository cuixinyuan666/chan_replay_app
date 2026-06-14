# task checklist and contact

Branch: origin_vespa_tdx

## Open questions

open_questions: none

## Hard rules

- Original `python/chan.py` is the only Chan calculation engine.
- Flutter/Dart must not calculate FX/BI/SEG/ZS/BSP/segseg.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- Bridge fallback, Chan result cache, and algorithmic fast/turbo/speed mode are not accepted.
- High-speed path remains default; slow path is debug/baseline only.
- Prefer repository offline/sample data for validation when it can reproduce the task.
- New files under `python/chan.py` must be in `a_*` folders or named `a_*.py`.

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
- S12b replay evidence button, indicator default-hidden state, and explicit level-validation feedback: accepted by receiver CLI + App evidence.
- S12c step-load temporal evidence state tracking: accepted by receiver CLI + App evidence.

## Current selected task

S12d selected: interval-link marker ids for parent-child replay navigation evidence.

## Historical accepted summary

### S1-S3

- S1 accepted with `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B`.
- S2 accepted pinned fixture export: `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- S3 accepted pinned S1 fixture CLI validation with compact match, native lv_list, no bridge fallback, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, and no Chan recalculation.

### R1/R1b

- R1 accepted by App evidence. It made `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B` the S1-like defaults, kept `S1一键复制`, and de-emphasized low-level debug copy buttons.
- R1b accepted by CLI validation: `python tools/validate_r1_receiver_burden.py`.

### S4-S7

- S4 accepted: CLI strategy diagnostics validator.
- S5 accepted: CLI strategy rule matrix validation for `DAILY_2B_MIN30_1B`, `DAILY_3B_MIN30_1B`, and `DAILY_3B_MIN30_2B`.
- S6 accepted: strategy signal sample coverage, including matched-output metadata and no-output diagnostic path.
- S7 accepted: App strategy signal display loop, selected-signal callback, raw-index jump, chart marker wiring, and copy evidence.

### S8-S9

- S8 accepted: scanner / batch strategy output, local generated candidate JSON, App candidate navigation, chart marker, and traceability evidence.
- S9 accepted: local generated artifact hygiene and continuation baseline.
- Generated `test/fixtures/derived/s8_strategy_batch_candidates_v1.json` is local validation output and should not be committed by default.

## S10 accepted: analyze_multi long-history window count expansion

completed_tasks:

- Formalized long-history count expansion around request `start` and `end`, instead of estimating from wall-clock time.
- Top-level and lower-level fetch counts are expanded from the same deterministic request window basis.
- Preserved backend authority in `python/chan.py` through native `CChan(lv_list=[...])`.
- Added `tools/validate_s10_long_history_count_expansion.py` as the dedicated CLI/static validator.
- Updated the S10 validator so later-stage regressions accept both `S10 selected` and `S10 accepted` manual states.
- Preserved the S8 long-window behavior for `2022-01-01` to `2025-12-31` while avoiding bridge fallback, cache fallback, or Dart-side Chan calculation authority.

evidence_button:

- Receiver command: `python tools/validate_s10_long_history_count_expansion.py`.
- Regression chain: S8 export, S8 validation, S8 App static validation, and `flutter analyze`.

validation_result:

- accepted.
- Receiver S10 output proved deterministic expansion for the S8 long window:
  - `DAILY`: `900 -> 1908`
  - `MIN30`: `900 -> 11764`
  - `MIN5`: `900 -> 68086`
- Receiver S10 checks passed for request-window parser, request `start/end` usage, expanded helper signature using window bounds, top-level prefetch expansion, lower-level window count expansion, metadata `requested_window`, metadata `count_expansion_basis`, preserved S8 window basis, native `CChan(lv_list)` authority, no bridge fallback or wall-clock count, and no Dart-side Chan calculation authority.

remaining_risk:

- Visual App behavior remains covered by existing S8/S12 App evidence chains.

next_task:

- S10 accepted. Continue S11.

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
- Verified the App has a visible multi-level single-stock replay entry, stock code input, market input, date window input, level selection UI, high-speed runtime path default, analyze_multi backend path, native `CChan(lv_list=[...])` authority, OriginKlineChart reuse, TradingView toolbox/easy-tdx entry, strict step frame usage, relation/signal locate hooks, and no Dart-side Chan calculation authority.
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

- Full S12 was not complete at S12a. The validator still reported review-only gaps for evidence button, default-hidden indicators, invalid-level feedback, temporal states, interval-link marker ids, and marker-overlap policy.

next_task:

- Start S12b: replay evidence button, indicator default-hidden state, and explicit level-validation feedback.

## S12b accepted: replay evidence button, indicator default-hidden state, and explicit level-validation feedback

completed_tasks:

- Added `lib/ui/pages/s12_single_stock_replay_page.dart`.
- Routed the default multi-level/single-stock replay entry to `S12SingleStockReplayPage` while preserving existing S7/S8 pages and validators.
- Added visible `复制复盘证据` button.
- Added S12 evidence text with symbol, market, selected levels, normalized levels, active level, runtime path, replay mode, current step, visible window, enabled Chan overlays, enabled easy-tdx indicators, source policy, backend authority, native CChan flag, fallback flag, `dart_chan_calculation_authority: false`, and `candidate_policy: not a trading recommendation`.
- Made easy-tdx indicators hidden by default through empty `_enabledEasyTdxIndicators`, while keeping indicator toggles inside the existing OriginKlineChart / TradingView-style tool entrance.
- Added explicit selected-level validation before `analyze_multi`, including unsupported/duplicate/too-few-level feedback and normalized level reporting.
- Changed S12 default App evidence path to the S8/S11-proven once window: `600340.SH`, `DAILY,MIN30,MIN5`, `2022-01-01~2025-12-31`, `count=900`, `runtime_path=high_speed`.
- Enhanced S12 load failure status so future errors show request context instead of only a generic backend failure.
- Updated `tools/validate_s12_app_single_stock_replay_high_speed_path.py` so the evidence button, default-hidden indicator state, and invalid-level feedback are required S12b checks.
- Did not modify `python/chan.py` and did not add Dart-side Chan calculation authority.

evidence_button:

- Receiver command: `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Receiver App button: `复制复盘证据`.

validation_result:

- accepted.
- Receiver S12b validator output included `ok: true`, empty `missing_baseline_required`, empty `missing_s12b_required`, all `s12b_required_checks: true`, no forbidden Dart calculation patterns, no forbidden profit/trading wording, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver S11 regression output included `ok: true`, `required_ok: true`, `required_timeout_failure_count: 0`, `hygiene_ok: true`, and `dart_chan_calculation_authority: false`.
- Receiver analyzer output included `No issues found`.
- Receiver App evidence included `runtime_path: high_speed`, `replay_mode: once`, `enabled_easy_tdx_indicators: none`, native CChan authority, `fallback_to_bridge: false`, `dart_chan_calculation_authority: false`, and `candidate_policy: not a trading recommendation`.

remaining_risk:

- S12b App evidence uses `once` mode. Step-specific temporal evidence is intentionally deferred to S12c.

next_task:

- Start S12c: step-load temporal evidence state tracking for replay structures.

## S12c accepted: step-load temporal evidence state tracking for replay structures

completed_tasks:

- Added temporal evidence lifecycle tracking in `lib/ui/pages/s12_single_stock_replay_page.dart`.
- The App now rebuilds temporal evidence from backend-exported `analysis.frames` when frames exist, and from one snapshot only when frames are absent.
- The tracker collects backend model objects only: BSP, FX, BI, SEG, ZS, and segZs/segseg-style ZS when present.
- The tracker records `first_seen_step`, `confirmed_step`, `last_seen_step`, `temporal_source`, `temporal_state`, and `temporal_state_counts` in copied S12 evidence.
- A backend-exported structure with `is_sure/confirmed == false` is classified as `provisional` while still present in the last frame.
- A backend-exported structure with `is_sure/confirmed == true` is classified as `confirmed`; repeated sightings update the same evidence object instead of creating duplicates.
- A backend-exported provisional structure that later disappears is preserved as `historical_provisional` and is not treated as confirmed.
- Updated `tools/validate_s12_app_single_stock_replay_high_speed_path.py` so S12c temporal tracking is required, while interval-link marker ids and marker-overlap policy remain review-only.
- Removed unused temporary field after analyzer warning; temporal map remains stored inside `_TemporalSummary.evidence`.
- Did not modify `python/chan.py` and did not add Dart-side Chan calculation authority.

evidence_button:

- Receiver command: `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Receiver App button: `复制复盘证据` in step mode.

validation_result:

- accepted.
- Receiver S12c validator output included `ok: true`, all `s12c_required_checks: true`, empty `missing_baseline_required`, empty `missing_s12b_required`, empty `missing_s12c_required`, no forbidden Dart calculation patterns, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver S11 regression output included `ok: true`, `required_ok: true`, `required_timeout_failure_count: 0`, `hygiene_ok: true`, and `dart_chan_calculation_authority: false`.
- Receiver App step evidence included:
  - `replay_mode: step`
  - `current_step: 0`
  - `temporal_source: backend_step_frames`
  - `temporal_state: provisional=44 confirmed=3288 historical_provisional=122`
  - `temporal_state_counts: provisional=44 confirmed=3288 historical_provisional=122 total=3454`
  - `temporal_sample_id: SEG:DAILY:211-323:3`
  - `temporal_sample_type: SEG`
  - `temporal_sample_state: historical_provisional`
  - `first_seen_step: 0`
  - `confirmed_step: unknown`
  - `last_seen_step: 25`
  - `temporal_evidence_policy: preserve backend-exported structures across frames; do not recalculate Chan structures in Dart`
  - `native_cchan_lv_list: true`
  - `fallback_to_bridge: false`
  - `dart_chan_calculation_authority: false`
  - `candidate_policy: not a trading recommendation`

remaining_risk:

- Full S12 is still not complete. The S12c validator still reports these review-only gaps:
  - `interval_link_marker_id_exists`
  - `marker_overlap_policy_marker_exists`
- `audit_origin_kline_global_label_layout_usage.py --strict` still reports `_drawFx does not accept chartLabels`; keep this as display-layout debt unless it is selected as the next specific chart-label task.
- S12c tracks lifecycle evidence for backend-exported structures; it does not add clickable interval-link marker ids.

next_task:

- Start S12d: interval-link marker ids for parent-child replay navigation evidence.

## S12d selected: interval-link marker ids for parent-child replay navigation evidence

Goal:

- Convert parent-child relation evidence from plain text into stable interval-link marker ids that can be copied, audited, and later used for navigation/highlighting.

Scope:

- Add stable marker ids for parent-child interval links in S12 replay evidence.
- Marker id format should start with `interval_link_` and include enough deterministic data to identify parent level, child level, parent raw index, and child raw range.
- Source of relation data must remain backend-exported `MultiLevelChanSnapshot.relations`; Dart may format ids and attach evidence, but must not calculate parent-child relation logic.
- Copied S12 evidence must include at least one `parent_child_interval_link` or `interval_link_marker_ids` field when backend relation data exists.
- If relation data does not exist for the current sample, copied evidence must explicitly state `interval_link_marker_ids: none` and the reason.
- Update `tools/validate_s12_app_single_stock_replay_high_speed_path.py` so interval-link marker ids become required for S12d while marker-overlap policy remains review-only.
- Do not modify `python/chan.py` algorithms.
- Do not add Dart-side FX/BI/SEG/ZS/BSP/segseg calculation authority.
- Do not add profit prediction, trading recommendation, or automatic trading wording.

Acceptance evidence:

- Receiver command: `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Receiver App evidence should include:
  - `temporal_source: backend_step_frames` or accepted once fallback;
  - `interval_link_marker_ids:` or `parent_child_interval_link:` with an `interval_link_...` marker id when relation data exists;
  - relation source policy proving backend relations are the source;
  - `dart_chan_calculation_authority: false`.

remaining_risk:

- Marker-overlap policy remains for later S12 sub-stage unless explicitly included in S12d implementation.
- The optional `_drawFx does not accept chartLabels` display-layout debt remains separate unless the supervisor selects it as the next chart-label-layout task.

## Next task-party operation

1. Receiver pulls latest `origin_vespa_tdx`.
2. Task party implements S12d in small changes.
3. Receiver runs `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
4. Receiver runs `python tools/validate_s11_guardrail_regression.py`.
5. Receiver runs `flutter analyze`.
6. Receiver shares S12d validator output and App replay evidence for acceptance.
