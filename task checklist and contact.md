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

## S1-S3 summary

- S1 accepted with `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B`.
- S2 accepted pinned fixture export: `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- S3 accepted pinned fixture CLI validation with compact match, native lv_list, no bridge fallback, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, and no Chan recalculation.

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

## S7 selected: App strategy signal display loop

Goal:

- Show validated strategy signals in the App and verify UI-only behavior that CLI cannot cover.

Scope:

- Show strategy signals in the App.
- Mark matched strategy signals on the chart.
- Allow selecting a signal and jumping to the corresponding raw index/time.
- Display source BSP, relation range, strict-step visibility, rule name, and state.
- Preserve one-click evidence for receiver-run UI validation.

S7 acceptance evidence:

- App evidence only for UI-specific behavior.
- CLI/static validators still cover non-visual requirements where possible.
- No Dart-side Chan calculation authority is introduced.
- Completion summary is written back to this manual.

## S8 planned: scanner / batch strategy output

Goal:

- Extend the validated strategy diagnostic/display chain to scanner or batch outputs.

Scope:

- Support multiple symbols and/or multiple strategy rules.
- Output candidate strategy results with traceability fields.
- Clicking a candidate should navigate to the corresponding replay position when App evidence is required.
- Use CLI validation first for static/batch correctness.

S8 acceptance evidence:

- CLI batch validation where possible.
- App evidence only for navigation/display behavior.
- Completion summary is written back to this manual.

## Next task-party operation

1. Pull the latest `origin_vespa_tdx`.
2. Run `python tools/validate_s6_strategy_signal_sample_coverage.py` if S6 acceptance needs to be rechecked.
3. Start S7 by inspecting the App strategy signal display path.
4. Prefer CLI/static validation for non-visual S7 requirements.
5. Require App evidence only for chart display, signal marking, selection, and jump behavior.
6. Do not add additional large full fixtures unless the manual explicitly requires them.
7. Do not continue performance optimization by default.
8. Write every stage completion summary into this manual after evidence is accepted.
