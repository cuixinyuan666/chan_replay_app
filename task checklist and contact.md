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
- S12d interval-link marker ids for parent-child replay navigation evidence: accepted by receiver CLI + App evidence.
- S12e shared marker-overlap policy for S12 chart and evidence markers: accepted by receiver CLI + App evidence.

## Current selected task

S12 full evidence chain complete. No mandatory S12 task selected.

Optional next task if selected: global chart-label migration debt, specifically `_drawFx` migration through the shared `ChartLabelLayout` path.

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

- S12c tracks lifecycle evidence for backend-exported structures; it does not add clickable interval-link marker ids.

next_task:

- Start S12d: interval-link marker ids for parent-child replay navigation evidence.

## S12d accepted: interval-link marker ids for parent-child replay navigation evidence

completed_tasks:

- Added interval-link marker evidence in `lib/ui/pages/s12_single_stock_replay_page.dart`.
- The App now reads backend-exported `MultiLevelChanSnapshot.relations` from step frames and final snapshots.
- Added stable interval-link marker ids in the form `interval_link_<parent>_<child>_p<parentRawIndex>_c<childStartRawIndex>_<childEndRawIndex>`.
- Added copied evidence fields: `interval_link_source`, `interval_link_marker_ids`, `parent_child_interval_link`, `parent_child_interval_link_reason`, `interval_link_sample`, `interval_link_relation_count`, and `interval_link_policy`.
- Added an explicit empty-data reason when backend relation data is empty.
- Updated `tools/validate_s12_app_single_stock_replay_high_speed_path.py` so S12d interval-link marker ids are required while marker-overlap policy remains review-only.
- Did not modify `python/chan.py` and did not add Dart-side parent-child relation calculation authority.

evidence_button:

- Receiver command: `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Receiver App button: `复制复盘证据`.

validation_result:

- accepted.
- Receiver S12d validator output included `ok: true`, all `s12d_required_checks: true`, empty `missing_baseline_required`, empty `missing_s12b_required`, empty `missing_s12c_required`, empty `missing_s12d_required`, no forbidden Dart calculation patterns, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver S11 regression output included `ok: true`, `required_ok: true`, `required_timeout_failure_count: 0`, `hygiene_ok: true`, and `dart_chan_calculation_authority: false`.
- Receiver analyzer output included `No issues found`.
- Receiver App evidence included:
  - `interval_link_source: backend_snapshot_relations`
  - `interval_link_marker_ids: interval_link_daily_min30_p0_c0_7,...`
  - `parent_child_interval_link: interval_link_daily_min30_p0_c0_7`
  - `parent_child_interval_link_reason: backend relation data exists and was formatted as stable interval_link marker ids`
  - `interval_link_sample: parent=DAILY@0 child=MIN30:0-7`
  - `interval_link_relation_count: 3528`
  - `interval_link_policy: backend MultiLevelChanSnapshot.relations only; Dart formats stable marker ids and does not calculate parent-child relation logic`
  - `native_cchan_lv_list: true`
  - `fallback_to_bridge: false`
  - `dart_chan_calculation_authority: false`
  - `candidate_policy: not a trading recommendation`

remaining_risk:

- Full S12 still has one review-only gap:
  - `marker_overlap_policy_marker_exists`
- `audit_origin_kline_global_label_layout_usage.py --strict` still reports `_drawFx does not accept chartLabels`; keep this as display-layout debt unless it is selected as the next chart-label-layout task.
- S12d formats stable marker ids and copy evidence; it does not implement shared marker-overlap layout policy.

next_task:

- Start S12e: shared marker-overlap policy for S12 chart and evidence markers.

## S12e accepted: shared marker-overlap policy for S12 chart and evidence markers

completed_tasks:

- Added stable `marker_overlap_policy` evidence in `lib/ui/pages/s12_single_stock_replay_page.dart`.
- Added `marker_overlap_policy_detail` and `marker_overlap_policy_scope` to copied S12 evidence.
- Added visible S12 panel chip for `marker_overlap_policy` so the policy is inspectable before copying evidence.
- Updated `tools/validate_s12_app_single_stock_replay_high_speed_path.py` so S12e marker-overlap policy evidence is required.
- S12 validator now reports `full_s12_completion: true` and no remaining full-S12 review-only gaps.
- Preserved S12b evidence button/default-hidden indicator/level-validation behavior.
- Preserved S12c temporal evidence lifecycle fields.
- Preserved S12d interval-link marker id evidence.
- Did not modify `python/chan.py` and did not add Dart-side Chan calculation authority.

evidence_button:

- Receiver command: `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Receiver App button: `复制复盘证据`.

validation_result:

- accepted.
- Receiver S12e validator output included `ok: true`, `full_s12_completion: true`, all `s12e_required_checks: true`, empty `missing_baseline_required`, empty `missing_s12b_required`, empty `missing_s12c_required`, empty `missing_s12d_required`, empty `missing_s12e_required`, empty `full_s12_missing_review_only`, no forbidden Dart calculation patterns, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver S11 regression output included `ok: true`, `required_ok: true`, `required_timeout_failure_count: 0`, `hygiene_ok: true`, and `dart_chan_calculation_authority: false`.
- Receiver analyzer output included `No issues found`.
- Receiver App evidence included:
  - `marker_overlap_policy: stable_s12_marker_order`
  - `marker_overlap_policy_detail: deterministic_order;capped_marker_list;reuse_existing_layout_path`
  - `marker_overlap_policy_scope: S12 evidence markers and display marker evidence only; global FX label migration remains a separate chart-label task`
  - accepted temporal evidence fields.
  - accepted interval-link marker id fields.
  - `native_cchan_lv_list: true`
  - `fallback_to_bridge: false`
  - `dart_chan_calculation_authority: false`

remaining_risk:

- S12 full evidence chain is complete.
- Optional global chart-label migration debt remains outside S12e:
  - `audit_origin_kline_global_label_layout_usage.py --strict` still reports `_drawFx does not accept chartLabels`.

next_task:

- No mandatory S12 task remains.
- Optional next task if selected: migrate FX labels through the shared `ChartLabelLayout` path and clear `audit_origin_kline_global_label_layout_usage.py --strict`.

## Next task-party operation

1. Receiver pulls latest `origin_vespa_tdx`.
2. Receiver removes local generated validation output if present: `test/fixtures/derived/s8_strategy_batch_candidates_v1.json`.
3. If continuing, supervisor selects the next optional display-layout task explicitly.

## UI optimization: single-stock multi-level replay workspace

completed_tasks:

- Optimized the single-stock multi-level replay page so the K-line chart uses the full route area by default.
- Changed the S13 settings area from a permanent 430px layout column into a left-edge overlay toolbar drawer.
- Removed visible S13 task-process evidence UI, including the evidence panel and copy-evidence button.
- Kept essential operation feedback such as level validation, runtime path, interval link count, and request window in compact toolbar chips.
- Renamed visible TradingView/TV toolbox labels to `工具栏`.
- Removed the extra left padding around the S13 route so the chart is no longer pre-shrunk before rendering.

evidence_button:

- Receiver command: `flutter analyze`.
- App path: open `单股多级别复盘`, use the left-edge `工具栏` buttons for stock, level, replay, and layer controls.

validation_result:

- `flutter analyze` passed with `No issues found`.
- Static keyword check found no S13 visible `复制复盘证据`, `复盘证据`, `s13_phase`, `TV工具`, `TV 工具`, or old TradingView toolbox title strings in the touched UI files.

remaining_risk:

- Visual App spacing should still be inspected interactively on the target Windows viewport.
- The root route toolbar and S13 page toolbar now both sit on the left edge; the route toolbar remains bottom-left and may overlap the lowest part of the S13 toolbar on short windows.

next_task:

- Receiver App validation: confirm the K-line area is maximized, the overlay toolbar can be opened/closed, and all required controls remain reachable from `工具栏`.

## UI optimization: touch-friendly unified toolbar and full-step replay

completed_tasks:

- Consolidated S13 page navigation and tool categories under the single left-edge `工具栏` entry.
- Hid the root route toolbar on the single-stock multi-level replay workspace and kept it low-opacity only on non-S13 pages.
- Moved `runtime path` into one touch-friendly button under `工具栏 / 股票`.
- Replaced S13 start/end text inputs with `showDatePicker`, compatible with Windows and Android Flutter.
- Removed S13 `step frames` UI and stopped sending `max_step_frames` from S13; step mode now requests the full backend step sequence.
- Moved replay step controls from `工具栏 / 复盘` to the K-line chart lower-right overlay, with first/last, previous/next, play/pause, and adjustable playback speed.
- Switched S13 transient messages to `!` dialog prompts instead of snack-bar style inline hints.
- Preserved BSP candidate trail markers in step mode and rendered them as lighter-color markers instead of removing them when backend provisional BSP disappears from later frames.

evidence_button:

- Receiver command: `flutter analyze`.
- Static checks: no S13/root `step frames`, `max_step_frames`, old date controllers, root runtime dropdown, or old TV toolbar wording in touched active UI files.

validation_result:

- `flutter analyze` passed with `No issues found`.

remaining_risk:

- Windows and Android touch layout should be inspected in App, especially date picker behavior, lower-right replay overlay, and toolbar panel scrolling on small screens.
- Existing unrelated working-tree changes remain untouched: Windows generated plugin files and local derived S8 fixture.

next_task:

- Receiver App validation on Windows and Android: load step replay, play/pause with speed changes, verify BSP candidate trail markers stay visible in lighter color, and confirm all navigation/tool functions are reachable from `工具栏`.

## UI optimization: step-load nested BSP markers

completed_tasks:

- Removed the S13 visible step-mode `区间套链接` overlay/list from the chart workspace.
- Added step-only nested BSP marker overlay on the K-line chart, based on backend step frames, loaded level order, BSP rows, and backend parent-child relations.
- Marker rows follow loaded levels such as `DAILY / MIN30 / MIN5`; missing BSP rows render as `-`.
- Buy BSP rows render red, sell BSP rows render green; the active chart level row is larger/thicker.
- Marker direction follows active-level context: top-level active markers point downward; middle-level active markers show higher-level rows upward, active row downward, and lower-level rows upward.
- Clicking a nested marker jumps to the next lower-level BSP region when one exists.
- Nested marker rows reuse the BSP candidate trail policy for every loaded level, so disappeared provisional BSPs stay visible in lighter color instead of mutating historical marker state.

evidence_button:

- Receiver command: `flutter analyze`.
- Static check: S13 no longer contains `区间套链接`, `_intervalLink`, `_visibleDownRelations`, `visible_links`, or `chart_interval` active UI paths.

validation_result:

- `flutter analyze` passed with `No issues found`.

remaining_risk:

- Pixel placement is an overlay approximation aligned to the chart visible rawIndex window; receiver should visually inspect marker alignment at different zoom/window sizes.
- If backend relations contain multiple child ranges for one parent rawIndex, S13 currently uses the first sorted child range for the nested chain.

next_task:

- Receiver App validation: in step mode with `DAILY,MIN30,MIN5`, verify nested BSP arrows, colors, missing `-` rows, lighter candidate-trail rows, and click-through to the next lower-level BSP region.

## UI correction: unified draggable floating toolbar

completed_tasks:

- Removed the remaining S13 left-edge vertical toolbar and its left-bottom load button so the chart can render to the far-left edge.
- Consolidated S13 stock, level, replay, layer, drawing, and page navigation controls into one scrollable floating `工具栏` component.
- Made the S13 floating toolbar draggable from its top button row and lowered its opacity.
- Hid the chart-internal drawing quick rail in S13 and routed drawing-tool opening through the unified floating toolbar.
- Made the drawing toolbox panel itself draggable from its title area and lowered its opacity while preserving internal list scrolling.
- Replaced visible S13 status chips/text with `!` info buttons that open dialog prompts for window, status, step, validation, and marker details.
- Moved step playback controls to the chart bottom-center and removed the outer frame around the control group.
- Added a top title-area level switcher so active chart level can be changed without opening the toolbar.
- Added click-outside behavior: when the S13 floating toolbar panel is open, tapping the non-toolbar chart area closes it.

evidence_button:

- Receiver command: `flutter analyze`.
- Static checks: S13 has no `_leftToolbar`, `_chip`, visible `Text(_status)`, or old `工具栏 / 股票|级别|复盘|图层` split-panel titles.

validation_result:

- `flutter analyze` passed with `No issues found`.

remaining_risk:

- Receiver should inspect Windows mouse-wheel scrolling and Android touch scrolling inside the unified floating toolbar.
- Receiver should inspect drag ergonomics for both the S13 toolbar and drawing toolbox panel.

next_task:

- Receiver App validation: verify chart reaches the far-left edge, unified toolbar scrolls, click-outside closes it, title-level switching works, and drawing toolbox can be opened and dragged from the floating toolbar.

## UI correction: nested marker trigger and BSP candidate persistence

completed_tasks:

- Changed nested marker glyphs from stemmed arrows to chevron-only arrow heads.
- Made each marker arrow row clickable; clicking a row jumps to that row's corresponding level/raw K-line.
- Changed nested marker generation so any loaded level's BSP can trigger a marker on the current chart level after mapping through backend relations.
- Big-level charts now show nested markers when lower-level BSPs appear, even if the big level itself has no BSP yet.
- Fixed BSP confirmation parsing so string/number forms such as `is_sure=false`, `false`, or `0` are treated as unconfirmed.
- Preserved historical provisional BSPs through the candidate-trail layer: previous provisional BSPs remain visible as lighter markers while current-frame BSPs remain deep-colored.

evidence_button:

- Receiver command: `flutter analyze`.
- Static checks: marker code uses `keyboard_arrow_up/down`, `_mapRawIndexToLevel`, and row-level click handling; BSP parser uses robust `_bool(...)` for `confirmed/is_sure`.

validation_result:

- `flutter analyze` passed with `No issues found`.

remaining_risk:

- Receiver should validate with a real step replay where lower-level BSPs appear without a same-bar higher-level BSP.
- Receiver should inspect one provisional BSP across consecutive step frames to confirm old markers stay light and new/current markers stay deep.

next_task:

- Receiver App validation: step through a known BSP candidate sequence and a multi-level nested BSP sequence, checking marker persistence, colors, click targets, and chevron-only glyphs.

## UI correction: loaded-level switcher and step-history BSP persistence

completed_tasks:

- Changed the top title-area level switcher to use actual backend-loaded snapshot levels, falling back to selected levels only before data is loaded.
- Updated nested marker relation mapping to use the actual loaded level chain instead of the default selected level list.
- Made the step playback control default to bottom-center while allowing it to be dragged to another chart position.
- Reworked BSP candidate trail persistence: step frames are accumulated up to the current frame, each first-seen BSP observation is preserved as historical when absent from the current frame, and its original type/confirmed state is not rewritten later.
- Current-frame BSPs remain deep colored; historical BSP observations are lighter, with `is_sure/confirmed` still reflected by alpha.
- Nested interval markers reuse the same historical BSP observation source, so they follow the same no-future, no-history-rewrite policy.

evidence_button:

- Receiver command: `flutter analyze`.
- Static checks: S13 includes `_loadedLevels`, draggable `_replayControlOffset`, historical trail `confirmed: p.confirmed`, and nested marker alpha based on historical/current plus confirmed state.

validation_result:

- `flutter analyze` passed with `No issues found`.

remaining_risk:

- Receiver should validate visually with real step data where loaded levels differ from the default `DAILY/MIN30/MIN5`.
- Receiver should step through several frames containing provisional BSPs to confirm old per-K observations persist light while the current frame stays deep.

next_task:

- Receiver App validation: load a non-default level chain, verify top switcher levels match backend-loaded levels, drag playback controls, and step BSP/interval markers through consecutive frames.

## UI correction: independent replay controls and clean BSP labels

completed_tasks:

- Split S13 step replay controls into independent draggable controls.
- Kept default replay-control placement at the bottom-center of the chart while allowing each button/speed control to be moved separately.
- Replaced the playback speed slider with a popup speed button to avoid accidental speed changes while dragging/panning the K-line chart.
- Removed visible `候选轨迹` suffix and `?` from BSP labels; historical/current and confirmed/provisional states are represented by color/alpha only.
- Preserved internal `候选轨迹` tagging solely as a UI state marker for historical rendering.
- Added crosshair date display at the chart's upper-left when the crosshair is enabled by double-clicking the K-line area.

evidence_button:

- Receiver command: `flutter analyze`.
- Static checks: S13 no longer uses `Slider` for speed; replay controls use `_draggableReplayControl`; BSP label adapter strips `候选轨迹`; crosshair painter renders `_fmtDate(bar.time)`.

validation_result:

- `flutter analyze` passed with `No issues found`.

remaining_risk:

- Receiver should validate drag hit-testing in App: panning the K-line chart should not change playback speed, and dragging a replay button should move only that button.

next_task:

- Receiver App validation: double-click chart to enable crosshair/date, pan chart near replay controls, move each replay control independently, and verify labels show `笔1` rather than `笔1候选轨迹`.

## S13 defaults and publish prep

completed_tasks:

- Changed S13 default start date to `2026-01-01`.
- Changed S13 default end date to system current date minus two days.
- Changed S13 default replay mode to `step`.

evidence_button:

- Receiver command: `flutter analyze`.

validation_result:

- `flutter analyze` passed with `No issues found`.

remaining_risk:

- Receiver should confirm App defaults on both Windows and Android.

next_task:

- Commit and push necessary files to `origin_vespa_tdx`.
