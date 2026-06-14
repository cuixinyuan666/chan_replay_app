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

## Current selected task

S11 selected: post-S10 guardrail regression bundle.
S12 queued next feature: App single-stock replay on accepted high-speed runtime path after S11 acceptance.

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

- Added `tools/validate_s4_cli_strategy_diagnostics.py` in commit `fcabcf93f077fe8275656e343039d4cfbfff7938`.
- The validator uses the pinned S1 fixture and checks strategy rule `DAILY_2B_MIN30_1B`, source policy, relation pairs, BSP availability, no-output diagnosis, strict-step frame evidence, compact validation, bridge fallback, native lv_list, and forbidden Dart-side Chan calculation markers.
- It does not launch the App, request live data, import or modify `python/chan.py`, or recalculate Chan structures.

evidence_button:

- CLI command: `python tools/validate_s4_cli_strategy_diagnostics.py`.

validation_result:

- accepted.
- Receiver output included `ok: true`, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, `available_signals: 0`, strict-step evidence, compact match, native lv_list, no fallback, no forbidden Dart-side markers, and no Chan recalculation.

remaining_risk:

- None for S4 CLI acceptance.

next_task:

- S4 accepted. Continue S5 and S6.

## Post-S4 roadmap

Default order after S4 acceptance: S5 -> S6 -> S7 -> S8, unless the supervisor explicitly changes priority.

## S5 accepted: CLI strategy rule matrix validation

completed_tasks:

- Added `tools/validate_s5_cli_strategy_rule_matrix.py` in commit `5430ba09004151e90bd4866536928fa2a062fdc1`.
- The validator reuses S4 fixture parsing and static checks, and defaults to the pinned S1 fixture.
- It validates `DAILY_2B_MIN30_1B`, `DAILY_3B_MIN30_1B`, and `DAILY_3B_MIN30_2B`.
- For each rule, it reports source policy, selected relation pair, high/low BSP counts and type counts, matched signal count or no-output diagnosis, source BSP identifiers when present, strict-step frame evidence, compact validation status, native lv_list flag, bridge fallback status, and forbidden Dart-side Chan calculation markers.

evidence_button:

- CLI command: `python tools/validate_s5_cli_strategy_rule_matrix.py`.

validation_result:

- accepted.
- Receiver output included `ok: true`, all three required strategy rules, one matrix item per strategy rule, `panel_strategy_rules_present: true`, strict-step evidence, compact match, native lv_list, no fallback, no forbidden Dart-side markers, and no Chan recalculation.

remaining_risk:

- The pinned fixture reports no matched output for all three S5 rules. This is acceptable for S5 matrix/no-output validation.
- S6 must prove both no-output and matched-output diagnostic paths.

next_task:

- S5 accepted. Start S6 by default.

## S6 accepted: strategy signal sample coverage

Goal:

- Ensure strategy diagnostics cover both no-output and matched-output conditions.

completed_tasks:

- Added `tools/validate_s6_strategy_signal_sample_coverage.py` in commit `8c35555c7cf7d72dae9200788db80b7d628e0b73`.
- Cleaned the S6 validator in commit `40a3cf44db1e778855755e51fafd83a3fb699fd6`.
- Added `tools/export_s6_strategy_matched_sample.py` in commit `3f098ff238ee575535cbc9f54a06bbdcbb5c69aa`.
- Updated the S6 validator in commit `c40dd172f7b86382230be1e385d95c5b8d1599ec` so it can validate the backend-traceable matched-output metadata sample at `test/fixtures/derived/s6_strategy_matched_sample_v1.json`.
- Broadened and accelerated the exporter in commit `3d2f5d77f27c16305001b6e71b1227b6386c206b`.
- Added `test/fixtures/derived/s6_strategy_matched_sample_v1.json` in commit `85a12d68577f597c67355b1f6ebe3822c274ffe0`.

evidence_button:

- Export command: `python tools/export_s6_strategy_matched_sample.py`.
- Validation command: `python tools/validate_s6_strategy_signal_sample_coverage.py`.

validation_result:

- accepted.
- Receiver export output included `ok: true`, output file `test/fixtures/derived/s6_strategy_matched_sample_v1.json`, matched rule `DAILY_2B_MIN30_1B`, source BSP identifiers `DAILY#4:raw=334:type=B2s;MIN30#21:raw=2672:type=B1`, relation range `parent=334:child=2672-2679`, root prefilter match count `2`, step matched sample count `61`, frames total/returned `391`, compact match, native lv_list, and no fallback.
- Receiver validation output included `ok: true`, `no_output_path.ok: true`, `matched_output_path.ok: true`, `traceability_fields_present: true`, compact match, native lv_list, no fallback, no forbidden Dart-side markers, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.

remaining_risk:

- S6 validates diagnostic coverage, not chart display behavior. S7 must verify App display, marking, selection, and navigation behavior.

next_task:

- Start S7 App strategy signal display loop.

## S7 accepted: App strategy signal display loop

Goal:

- Show validated strategy signals in the App and verify UI-only behavior that CLI cannot cover.

completed_tasks:

- Added `tools/validate_s7_app_strategy_signal_display_loop.py` in commit `055d586d4bfe10cb7faddda2ec9a46fdb209f933`.
- Exposed `MultiLevelStrategySignalSelection`, selected-signal callback, and Jump callback in `lib/ui/widgets/multi_level_interval_signal_panel.dart` in commit `22512bb4d99ea7c0ba83cc7f70f02a17c1d201c6`.
- Wired selected strategy signal, chart marker objects, and raw-index/time jump in `lib/ui/pages/multi_level_replay_page.dart` in commit `50cd6386d9c1496be7f36887cff80f4cf2d79d4c`.
- Cleaned analyzer findings in commit `c4850e55ffcb0e69d60aecbc6c0a597f74e12318`.
- Changed Multi-level replay to chart-first layout with collapsible/floating controls in commit `83e71600a8237b54451dff690ff593e432f571bc` so K-line area is not compressed by diagnostics and signal panels.

evidence_button:

- CLI/static command: `python tools/validate_s7_app_strategy_signal_display_loop.py`.
- Analyzer command: `flutter analyze`.
- App evidence button: `S1一键复制` in the `Interval strategy` panel.

validation_result:

- accepted.
- Receiver static validator output included `ok: true`, selected-signal callback, Jump callback, page signal reception, raw-index jump, chart marker wiring, chart overlay markers, no missing requirements, no forbidden Dart-side Chan calculation markers, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver analyzer output included `No issues found!`.
- Receiver App evidence included `s7_phase: app_strategy_signal_display_loop`, `available_signals: 2`, `rule_mode_name: DAILY_2B_MIN30_1B`, source BSP identifiers `DAILY#4:raw=334:type=B2s;MIN30#21:raw=2672:type=B1`, target levels `DAILY->MIN30`, native relation range `parent=334:child=2672-2679`, strict step visibility, state `confirmed`, raw/time/price fields, and chart marker id `s7_strategy_signal_marker_DAILY_2B_MIN30_1B_DAILY_334_MIN30_2672`.

remaining_risk:

- S7 App evidence proves signal traceability and marker id generation from the App. Visual confirmation of marker rendering and Jump positioning is still receiver-side observational evidence, not reproducible by CLI.
- The chart-first layout reduces compression, but exact visual comfort depends on screen size and DPI.

next_task:

- Start S8 scanner / batch strategy output.

## S8 accepted: scanner / batch strategy output

Goal:

- Extend the validated strategy diagnostic/display chain to scanner or batch outputs.

Scope:

- Support multiple symbols and/or multiple strategy rules.
- Output candidate strategy results with traceability fields.
- Clicking a candidate should navigate to the corresponding replay position when App evidence is required.
- Use CLI validation first for static/batch correctness.

Overall validation_result:

- accepted.
- S8a accepted by CLI exporter and validator.
- S8b accepted by static App validator and receiver App evidence.

remaining_risk:

- Generated batch output is intentionally local and not committed; rerun the exporter when local backend/data changes.
- Visual marker comfort depends on screen size and chart zoom, but S8 evidence proves marker id generation and jump target traceability.

next_task:

- Start S9 local generated artifact hygiene and continuation baseline.

## S8a accepted: CLI scanner / batch candidate output

completed_tasks:

- Added `tools/export_s8_strategy_batch_candidates.py` in commit `6530d2de03459c5dacfbd03ee8e3c6c010c527a8`.
- Added `tools/validate_s8_strategy_batch_candidates.py` in commit `448f2e5947cb50d418519ebe7c09866f4aa79c41`.
- The exporter scans multiple symbols, uses the existing backend `analyze_multi` path, reuses S6/S5 strategy matching helpers, outputs candidate strategy results with traceability fields, and derives `jump_target` from the low-level trigger BSP raw index.
- The validator checks exporter static contract, output `sample_kind`, source policy, candidate fields, jump fields, supported rule names, selected relation pair, native lv_list/no fallback diagnostics, and no Dart-side Chan calculation authority.
- The generated output file `test/fixtures/derived/s8_strategy_batch_candidates_v1.json` is intentionally not committed by default; receivers should generate it locally with the exporter to avoid untracked-file pull conflicts and stale scan data.

evidence_button:

- Export command: `python tools/export_s8_strategy_batch_candidates.py`.
- Validation command: `python tools/validate_s8_strategy_batch_candidates.py`.
- Analyzer command: `flutter analyze`.

validation_result:

- accepted.
- Receiver exporter output included `ok: true`, output file `test/fixtures/derived/s8_strategy_batch_candidates_v1.json`, `candidate_count: 20`, `attempt_count: 2`, sample code `600340.SH`, rule `DAILY_2B_MIN30_1B`, source BSP identifiers `DAILY#4:raw=334:type=B2s;MIN30#21:raw=2672:type=B1`, target levels `DAILY->MIN30`, native relation range `parent=334:child=2672-2679`, strict-step visibility, state `candidate`, and jump target `MIN30 raw_index=2672`.
- Receiver validator output included `ok: true`, exporter static `ok: true`, output validation `ok: true`, `candidate_count: 20`, `attempt_count: 2`, supported rules `DAILY_2B_MIN30_1B`, `DAILY_3B_MIN30_1B`, `DAILY_3B_MIN30_2B`, selected relation pair `DAILY->MIN30`, empty candidate errors, empty native violations, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver analyzer output included `No issues found!`.

remaining_risk:

- S8a proves batch candidate output and traceability by CLI. It does not yet add an App scanner result list or click-to-replay navigation UI.
- The exporter runs against the receiver's current local backend state; local uncommitted backend changes can affect generated candidate output.

next_task:

- Continue S8b: App scanner/batch result list with candidate click navigation into Multi-level replay, using App evidence only for the UI navigation behavior.

## S8b accepted: App scanner / batch candidate navigation

completed_tasks:

- Added `lib/ui/pages/s8_strategy_batch_page.dart` in commit `6505bf414789de6b960fbc307ca3a536628d0e0c`.
- Added the `S8批量候选` route in `lib/ui/pages/root_page.dart` in commit `74872a607b43ba16aba42f3485fe9bbcfc0b2b44`.
- Added `tools/validate_s8_app_batch_navigation.py` in commit `35a30ac46287a5d0afdc4ef4304a90f6ea6d99fc`.
- Moved the `复制S8证据` button into the visible traceability evidence panel and fixed the local S8 panel layout in commit `31022bc1deaf6fc6ecef5d51468b8499b60a2927`.
- The App page reads the locally generated S8 candidate JSON, displays candidates, opens the clicked candidate through the existing multi-level backend path, jumps to the candidate `jump_target`, marks the chart with `s8_batch_candidate_marker`, and copies traceability evidence.

evidence_button:

- CLI/static command: `python tools/validate_s8_app_batch_navigation.py`.
- Analyzer command: `flutter analyze` after UI changes.
- App evidence button: `复制S8证据` in the `S8 traceability evidence` panel.

validation_result:

- accepted.
- Receiver static validator output included `ok: true`, root route present, local exporter JSON loading, candidate list, candidate click navigation, jump target navigation, chart marker, traceability fields, copy evidence, existing backend authority, and no Dart-side Chan calculation authority.
- Receiver App evidence included `s8_phase: app_batch_candidate_navigation`, code `600340.SH`, rule `DAILY_2B_MIN30_1B`, source BSP identifiers `DAILY#4:raw=334:type=B2s;MIN30#21:raw=2672:type=B1`, target levels `DAILY->MIN30`, native relation range `parent=334:child=2672-2679`, strict-step visibility, state `candidate`, jump target `MIN30 raw_index=2672`, levels `DAILY,MIN30,MIN5`, window `2022-01-01` to `2025-12-31`, count `900`, candidate policy, source policy, no Dart Chan calculation authority, and chart marker id `s8_batch_candidate_marker_600340.SH_DAILY_2B_MIN30_1B_MIN30_2672`.

remaining_risk:

- The receiver should rerun `python tools/validate_s8_app_batch_navigation.py` and `flutter analyze` after pulling commit `31022bc1deaf6fc6ecef5d51468b8499b60a2927` to close static validation on the latest UI visibility patch.
- The S8 output JSON remains local by design.

next_task:

- Start S9 local generated artifact hygiene and continuation baseline.

## S9 accepted: local generated artifact hygiene and continuation baseline

completed_tasks:

- Deleted local generated/backup files from the receiver working tree:
  - `test/fixtures/derived/s6_strategy_matched_sample_v1.local.backup.json`
  - `test/fixtures/derived/s8_strategy_batch_candidates_v1.json`
- Restored Windows generated files after confirming they had no substantive diff in `git diff --stat`:
  - `windows/flutter/generated_plugin_registrant.cc`
  - `windows/flutter/generated_plugins.cmake`
- Inspected `task checklist and contact.md`; the only local diff was accidental leading text `e`, so it was restored.
- Inspected `backend/app/a_multilevel_native_engine.py` and classified it as a real backend functionality patch, not cleanup noise.

evidence_button:

- Receiver commands:
  - `git status --short`
  - `git diff -- backend/app/a_multilevel_native_engine.py`
  - `git diff --stat`
  - `git restore -- windows/flutter/generated_plugin_registrant.cc`
  - `git restore -- windows/flutter/generated_plugins.cmake`
  - `git restore -- "task checklist and contact.md"`

validation_result:

- accepted.
- Final receiver status after S9 cleanup contains only:
  - `M backend/app/a_multilevel_native_engine.py`
- Local generated files are deleted and can be regenerated by S6/S8 exporters.
- Windows generated files and accidental manual edit are no longer dirty.

remaining_risk:

- `backend/app/a_multilevel_native_engine.py` remains modified by design. The diff changes multi-level data loading count expansion for long historical windows and should not be silently reset.
- The current local backend patch uses `datetime.now()` to estimate history-window count from `start`; S10 should formalize this using request `end` where possible, then add validation.

next_task:

- Start S10: formalize analyze_multi long-history window count expansion.

## S10 accepted: analyze_multi long-history window count expansion

S10 selected: formalize analyze_multi long-history window count expansion

Goal:

- Formalize the receiver's local `backend/app/a_multilevel_native_engine.py` count-expansion patch into deterministic request-window logic with validation.

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

- accepted by receiver CLI evidence except for the pre-pull local manual marker check.
- Receiver S10 output proved deterministic expansion for the S8 long window:
  - `DAILY`: `900 -> 1908`
  - `MIN30`: `900 -> 11764`
  - `MIN5`: `900 -> 68086`
- Receiver S10 checks passed for request-window parser, request `start/end` usage, expanded helper signature using window bounds, top-level prefetch expansion, lower-level window count expansion, metadata `requested_window`, metadata `count_expansion_basis`, preserved S8 window basis, native `CChan(lv_list)` authority, no bridge fallback or wall-clock count, and no Dart-side Chan calculation authority.
- Receiver S8 exporter output included `ok: true`, `candidate_count: 20`, `attempt_count: 2`, sample `600340.SH`, rule `DAILY_2B_MIN30_1B`, source BSP identifiers `DAILY#4:raw=334:type=B2s;MIN30#21:raw=2672:type=B1`, native relation range `parent=334:child=2672-2679`, and jump target `MIN30 raw_index=2672`.
- Receiver S8 validator output included `ok: true`, empty candidate errors, empty native violations, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver S8 App static validator output included `ok: true`, chart marker, jump target navigation, traceability fields, existing backend authority, and no Dart-side Chan calculation authority.
- Receiver analyzer output included `No issues found!`.

remaining_risk:

- S10 validation is CLI/static evidence plus S8 regression evidence; visual App behavior remains covered by the existing S8 App static/App evidence chain.

next_task:

- Continue S11: post-S10 guardrail regression bundle.

## S11 selected: post-S10 guardrail regression bundle

Goal:

- Provide one receiver-friendly CLI entrypoint to prove the S10 backend change still satisfies the S10/S8/guardrail chain before new feature work continues.

Scope:

- Add `tools/validate_s11_guardrail_regression.py`.
- The validator must run S10 validation, S8 export, S8 output validation, S8 App static validation, global lazy-loading audit, and chan.py placement guardrail.
- The validator may run optional existing Dart algorithm/layout audits when the scripts exist.
- `flutter analyze` remains a separate acceptance command by default, with an optional `--include-flutter-analyze` flag for receivers that want one command to include it.
- Do not modify `python/chan.py`.
- Do not add Dart-side FX/BI/SEG/ZS/BSP calculation authority.

Acceptance evidence:

- Receiver command: `python tools/validate_s11_guardrail_regression.py`.
- Receiver command: `flutter analyze`.
- Optional receiver command: `python tools/validate_s11_guardrail_regression.py --include-flutter-analyze`.

remaining_risk:

- The S8 exporter intentionally regenerates `test/fixtures/derived/s8_strategy_batch_candidates_v1.json` locally. Receivers should not commit that derived JSON by default.

next_task:

- Receiver pulls the S11 validator and runs the S11 commands. If accepted, write S11 completion summary into this manual and select the next feature task.

## S12 queued: App single-stock replay on accepted high-speed runtime path

Goal:

- Build the next App feature stage on the already accepted `runtime_path=high_speed` path.
- Provide a complete single-stock replay workflow with stock-code input, arbitrary supported multi-level selection, backend Chan structure display, easy-tdx indicator controls through the existing TradingView-style tool entrance, step_load temporal evidence preservation, interval-nesting link markers, marker overlap control, and one-click replay evidence copy.
- This is App integration only. It must not modify `python/chan.py` Chan algorithms and must not add Dart-side Chan calculation.

Dependency:

- S12 should start after S11 guardrail regression is accepted.
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
2. Receiver runs `python tools/validate_s11_guardrail_regression.py`.
3. Receiver runs `flutter analyze`.
4. Receiver shares the S11 output for acceptance.
5. After S11 is accepted, continue S12: App single-stock replay on accepted high-speed runtime path.