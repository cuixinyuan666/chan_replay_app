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

## Current selected task

S12 selected: App single-stock replay on accepted high-speed runtime path.

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

Goal:

- Provide one receiver-friendly CLI entrypoint to prove the S10 backend change still satisfies the S10/S8/guardrail chain before new feature work continues.

completed_tasks:

- Added `tools/validate_s11_guardrail_regression.py`.
- The validator runs S10 validation, S8 export, S8 output validation, S8 App static validation, global lazy-loading audit, and chan.py placement guardrail.
- Fixed `tools/audit_global_lazy_loading.py` so whitelisted root-page imports are not falsely blocked by substring matching.
- Updated S11 optional audits to review-only so non-S11 display-layout debt does not block the post-S10 guardrail bundle.
- Preserved the rule that no S11 work modifies `python/chan.py` or adds Dart-side FX/BI/SEG/ZS/BSP calculation authority.

evidence_button:

- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Optional receiver command: `python tools/validate_s11_guardrail_regression.py --include-flutter-analyze`.

validation_result:

- accepted.
- Receiver S11 output included `ok: true`, `required_ok: true`, `flutter_ok: true`, `hygiene_ok: true`, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Required S11 chain passed:
  - `python tools/validate_s10_long_history_count_expansion.py`
  - `python tools/export_s8_strategy_batch_candidates.py`
  - `python tools/validate_s8_strategy_batch_candidates.py`
  - `python tools/validate_s8_app_batch_navigation.py`
  - `python tools/audit_global_lazy_loading.py --strict`
  - `python tools/check_chanpy_guardrails.py`
- Receiver `flutter analyze` output included `No issues found`.
- Optional review-only audit still reported `audit_origin_kline_global_label_layout_usage.py --strict` failure: `_drawFx does not accept chartLabels`. This is not a blocker for S11 and remains display-layout debt for a later chart-label-layout task.

remaining_risk:

- The S8 exporter intentionally regenerates `test/fixtures/derived/s8_strategy_batch_candidates_v1.json` locally. Receivers should not commit that derived JSON by default.
- `audit_origin_kline_global_label_layout_usage.py --strict` still identifies an optional display-layout issue: FX labels are not yet migrated through the shared `ChartLabelLayout` path.

next_task:

- Start S12: App single-stock replay on accepted high-speed runtime path.

## S12 selected: App single-stock replay on accepted high-speed runtime path

Goal:

- Build the next App feature stage on the already accepted `runtime_path=high_speed` path.
- Provide a complete single-stock replay workflow with stock-code input, arbitrary supported multi-level selection, backend Chan structure display, easy-tdx indicator controls through the existing TradingView-style tool entrance, step_load temporal evidence preservation, interval-nesting link markers, marker overlap control, and one-click replay evidence copy.
- This is App integration only. It must not modify `python/chan.py` Chan algorithms and must not add Dart-side Chan calculation.

Dependency:

- S12 starts after S11 guardrail regression acceptance.
- S12 must inherit all hard rules from this manual.
- S12 must keep high-speed path as the default runtime path and slow path as debug/baseline only.

High-speed path basis:

- `runtime_path=high_speed` is already implemented through `RuntimePath.highSpeed`, `RuntimePathController.current`, `PythonMultiLevelChanAnalysisSource.analyzeMulti`, and the `/api/chan/analyze_multi` backend route.
- The high-speed path is a UI/runtime routing and diagnostics policy. It must not become a Dart-side or cache-side Chan calculation authority.
- The backend calculation source remains `python/chan.py` through native `CChan(lv_list=[...])`.
- Bridge fallback, cache-as-authority, and algorithmic fast/turbo/speed modes remain forbidden.

Scope:

1. Single-stock replay entry

- Provide a visible App entry for single-stock replay.
- Provide stock-code input.
- Support market auto-inference and manual market override when needed.
- The user should be able to load one stock into replay without opening scanner or batch candidate pages.
- The default workflow should be replay, not recommendation, scanner, backtest, or trading execution.

2. Arbitrary multi-level selection

- Provide dropdown controls for all backend-supported levels.
- UI may allow arbitrary level combinations.
- Before calling analyze_multi, validate that the selected level combination satisfies `chan.py` multi-level input requirements.
- Validation should check backend-supported level names, duplicate or empty selection, ordering normalization, and `CChan(lv_list=[...])` submit eligibility.
- Invalid combinations must produce visible UI feedback.
- Do not silently change user-selected levels unless the UI reports the normalized result.

3. Backend authority and no new algorithm

- Continue to use the existing high-speed analyze_multi chain.
- Keep `python/chan.py` and native `CChan(lv_list=[...])` as the only Chan calculation authority.
- S12 must not modify `python/chan.py` Chan algorithms.
- S12 must not add Dart-side FX/BI/SEG/ZS/BSP/segseg calculation.
- App and Dart code may only parse, display, route, mark, and copy evidence from backend-exported structures.

4. easy-tdx indicator display

- easy-tdx indicators must use the same TradingView-style tool entrance as the replay chart.
- Do not add a second independent indicator control system.
- Main-chart and sub-chart indicators must be hidden by default.
- Users may manually enable supported indicators such as MA, BOLL, VOL, MACD, and other backend-supported easy-tdx indicators.
- Indicator display is UI-only and must not become the source of Chan structures or BSP calculation.

5. Chan structure display

- Reuse the existing replay chart implementation where possible.
- Display backend-exported Chan structures:
  - original K-lines
  - merged K-lines
  - FX
  - BI
  - SEG
  - segseg / 二级线段 / 2段
  - ZS
  - BI BSP
  - SEG BSP
  - segseg BSP if provided by the backend
- UI may display segseg as `2段`.
- Manual text and code comments should preserve all three names: `segseg`, `二级线段`, and `2段`.

6. step_load temporal evidence preservation

- The App must preserve structures and BSPs produced by backend step_load as temporal evidence.
- A structure or BSP that appeared in a previous step must not be silently removed only because later steps no longer expose it in the current frame/snapshot.
- `is_sure == false` must be displayed in a light/provisional style.
- `is_sure == true` must be displayed in a dark/confirmed style.
- This rule applies to BSP, FX, BI, SEG, and segseg / 二级线段 / 2段.
- If the same structure later changes from provisional to confirmed, update the existing visual object instead of creating a duplicate.
- If a provisional structure later disappears, keep it visible as `historical_provisional`.
- `historical_provisional` must not be treated as confirmed.
- Copied evidence must distinguish `provisional`, `confirmed`, and `historical_provisional`.

7. Interval-nesting link markers

- Add interval-nesting link markers between parent-level and child-level evidence.
- A parent marker should identify the high-level structure or BSP.
- A child marker should identify the low-level trigger or confirmation point.
- Clicking a parent marker should jump to the child level and locate the child raw index.
- Clicking a child marker should show or jump back to parent evidence when applicable.
- Link marker ids must be stable and traceable, for example:
  - `interval_link_{symbol}_{parentLevel}_{parentRawIndex}_{childLevel}_{childRawIndex}_{rule}`

8. Marker and UI overlap control

- Marker labels must not fully overlap.
- BSP, FX, BI, SEG, segseg, interval-link markers, and manual drawing labels should share a unified layout policy.
- Same-raw-index markers must be vertically staggered.
- Buy-side markers should prefer below-K-line placement.
- Sell-side markers should prefer above-K-line placement.
- Interval-link markers should use lightweight icons or labels and must not cover candle bodies unnecessarily.
- Toolbar, dropdowns, evidence panel, crosshair, price axis, and time axis must not block each other.
- On small screens, controls should be collapsible or moved into drawers or panels.
- The chart area has priority over diagnostics panels.

9. One-click replay evidence copy

- Provide a visible one-click evidence copy button.
- Suggested button label: `复制复盘证据`.
- Copied evidence should include:
  - `s12_phase: app_single_stock_replay_high_speed_path`
  - symbol
  - market
  - selected levels
  - normalized levels if different
  - active level
  - runtime_path
  - replay mode
  - current step
  - visible window
  - enabled Chan overlays
  - enabled easy-tdx indicators
  - selected marker id
  - selected marker type
  - is_sure
  - temporal state: provisional / confirmed / historical_provisional
  - first_seen_step
  - confirmed_step
  - parent/child interval-link evidence when applicable
  - source policy
  - backend authority
  - `dart_chan_calculation_authority: false`
  - `candidate_policy: not a trading recommendation`

10. UI reference

- Use OpenFlutter/k_chart only as UI interaction reference for K-line chart ergonomics:
  - drag
  - scale
  - long press
  - fling
  - main/sub indicator state
  - chart padding
  - trendline-like interaction
- Do not replace the current `OriginKlineChart`, TradingView drawing tool, or marker/evidence chain with k_chart.
- Do not introduce k_chart as a dependency in S12 unless separately approved.
- Any borrowed UI idea must be adapted into the existing App architecture and validator chain.

Out of scope:

- No profit prediction.
- No trading recommendation.
- No automatic trading.
- No Dart-side FX/BI/SEG/ZS/BSP/segseg calculation.
- No silent modification of `python/chan.py` Chan algorithms.
- No cache-as-authority design.
- No bridge fallback.
- No large fixture unless explicitly approved.

Acceptance evidence:

- Add `tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
- The validator must prove:
  - high-speed runtime path remains default;
  - slow path remains debug/baseline only;
  - single-stock replay entry exists;
  - stock-code input exists;
  - level dropdown controls exist;
  - arbitrary level selections are validated before analyze_multi;
  - invalid level combinations show explicit UI feedback;
  - analyze_multi backend path is used;
  - native `CChan(lv_list=[...])` backend authority remains the source;
  - easy-tdx indicators use the same TradingView-style tool entrance;
  - main/sub indicators are hidden by default;
  - Chan structures are parsed from backend output only;
  - step_load temporal evidence is preserved;
  - provisional, confirmed, and historical_provisional states are distinguishable;
  - interval-nesting link markers are stable and clickable;
  - marker overlap policy exists;
  - one-click replay evidence copy exists;
  - no Dart-side Chan calculation authority exists;
  - no profit prediction or automatic trading wording exists.
- Receiver should run:
  - `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`
  - `python tools/validate_s11_guardrail_regression.py`
  - `flutter analyze`
- Receiver App evidence should include:
  - one stock code;
  - selected arbitrary multi-level combination;
  - normalized/validated level result;
  - runtime path evidence showing `high_speed`;
  - one provisional object if available;
  - one confirmed object if available;
  - one historical_provisional object if available;
  - one interval-link marker if available;
  - copied replay evidence text.

## Next task-party operation

1. Receiver pulls latest `origin_vespa_tdx`.
2. Task party implements S12 in small stages, starting with a CLI/static validator and single-stock replay entry.
3. Receiver runs `python tools/validate_s12_app_single_stock_replay_high_speed_path.py`.
4. Receiver runs `python tools/validate_s11_guardrail_regression.py`.
5. Receiver runs `flutter analyze`.
6. Receiver shares S12 validator output and App replay evidence for acceptance.
