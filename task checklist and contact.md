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

## S1-S3 summary

- S1 accepted with `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B`.
- S2 accepted pinned fixture export: `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- S3 accepted pinned fixture CLI validation. Receiver output included `ok: true`, levels `DAILY,MIN30,MIN5`, `frames_total: 29`, `frames_returned: 29`, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, and `chan_recalculated: false`.

remaining_risk:

- The pinned fixture is about 7.06 MB. Prefer this fixture or a smaller derived metadata sample for later checks.

## R1/R1b summary

- R1 accepted by App evidence. It made `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B` the S1-like defaults, kept `S1一键复制`, and de-emphasized low-level debug copy buttons.
- R1b accepted by CLI validation: `python tools/validate_r1_receiver_burden.py`.
- R1b output included `ok: true`, `rule_mode_default: strategy`, `strategy_rule_default: DAILY_2B_MIN30_1B`, `one_click_label: S1一键复制`, `debug_copy_tools: de_emphasized`, `evidence_status: s1_evidence_exported`, `forbidden_dart_calc_patterns: []`, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.

## S4 accepted: CLI strategy diagnostics validator

completed_tasks:

- Added `tools/validate_s4_cli_strategy_diagnostics.py` in commit `fcabcf93f077fe8275656e343039d4cfbfff7938`.
- The validator uses the pinned S1 fixture and checks strategy rule `DAILY_2B_MIN30_1B`, source policy, relation pairs, BSP availability, no-output diagnosis, strict-step frame evidence, compact validation, bridge fallback, native lv_list, and forbidden Dart-side Chan calculation markers.
- It does not launch the App, request live data, import or modify `python/chan.py`, or recalculate Chan FX/BI/SEG/ZS/BSP.

evidence_button:

- CLI command: `python tools/validate_s4_cli_strategy_diagnostics.py`.

validation_result:

- accepted.
- Receiver output included `ok: true`, `strategy_rule_name: DAILY_2B_MIN30_1B`, `source_policy: original chan.py BSP + native LevelRelation only`, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, `native_relation_count_for_pair: 29`, `available_signals: 0`, `source_bsp_identifiers: none`, no-output diagnosis, strict-step frame evidence with `frame_source: native_step_frame`, `frames_total: 29`, `frames_returned: 29`, `final_snapshot_rendered_as_step: false`, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, `forbidden_dart_calc_patterns: []`, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.

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
- It does not launch the App, request live data, import or modify `python/chan.py`, or recalculate Chan FX/BI/SEG/ZS/BSP.

evidence_button:

- CLI command: `python tools/validate_s5_cli_strategy_rule_matrix.py`.

validation_result:

- accepted.
- Receiver output included `ok: true`, `rules_checked` containing all three required strategy rules, `panel_strategy_rules_present: true`, `source_policy: original chan.py BSP + native LevelRelation only`, selected relation pair `DAILY->MIN30`, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, strict-step frame evidence, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, `forbidden_dart_calc_patterns: []`, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- Receiver output matrix contained one item for each required strategy rule. Each item included source policy, selected relation pair, levels, strategy type definitions, BSP counts, native relation count, matched signal count, no-output diagnosis, strict-step frame evidence, compact validation status, native lv_list flag, no bridge fallback, and no forbidden Dart-side Chan calculation markers.

remaining_risk:

- The pinned fixture reports `high_bsp_count: 0`, `low_bsp_count: 0`, and no matched output for all three S5 rules. This is acceptable for S5 matrix/no-output validation.
- S6 must still prove both no-output and matched-output diagnostic paths.

next_task:

- S5 accepted. Start S6 by default.

## S6 selected: strategy signal sample coverage

Goal:

- Ensure strategy diagnostics cover both no-output and matched-output conditions.

Scope:

- Reuse the pinned S1 fixture for no-output validation.
- Search the pinned S1 fixture root snapshot and strict-step frames for matched-output evidence before asking for new data.
- If matched-output evidence is missing, create the smallest acceptable backend-traceable derived fixture or metadata sample.
- Do not add another large full fixture unless this manual explicitly justifies it.
- Do not invent Chan results. Any matched-output fixture must remain traceable to accepted backend/fixture data, or be clearly marked as UI-only diagnostic data and approved before use.

S6 acceptance evidence:

- CLI report proving no-output and matched-output diagnostic paths.
- Traceability fields for matched output: source BSP identifiers, source/target levels, native relation range, strict-step visibility, state, and rule/mode name.
- Completion summary is written back to this manual.

completed_tasks:

- Added `tools/validate_s6_strategy_signal_sample_coverage.py` in commit `8c35555c7cf7d72dae9200788db80b7d628e0b73`.
- Cleaned the S6 validator in commit `40a3cf44db1e778855755e51fafd83a3fb699fd6`.
- The validator first reuses S5 matrix validation for the no-output path.
- The validator then scans the pinned fixture root snapshot and every strict-step frame for matched strategy candidates.
- The validator only accepts matched-output evidence if it can report source BSP identifiers, source/target levels, native relation range, strict-step visibility, state, and rule/mode name from fixture data.
- If no matched output is found in the pinned fixture, the validator fails with an explicit action requirement instead of inventing Chan results.

evidence_button:

- CLI command: `python tools/validate_s6_strategy_signal_sample_coverage.py`.

validation_result:

- pending receiver run.
- Accepted output requires `ok: true`, `no_output_path.ok: true`, `matched_output_path.ok: true`, matched-output traceability fields, `compact_validation_status: match`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, `forbidden_dart_calc_patterns: []`, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.
- If output is `ok: false` only because matched output is absent in the pinned fixture, S6 is not accepted yet. The next step is to create the smallest backend-traceable matched-output metadata sample.

remaining_risk:

- The current pinned fixture may still be no-output only.

next_task:

1. Receiver pulls latest `origin_vespa_tdx`.
2. Receiver runs `python tools/validate_s6_strategy_signal_sample_coverage.py`.
3. If output is `ok: true`, accept S6 and proceed to S7.
4. If output is `ok: false` due to missing matched output, create/export the smallest backend-traceable matched-output metadata sample before accepting S6.

## S7 planned: App strategy signal display loop

Goal:

- After CLI diagnostics are stable, return to App only for UI behavior that CLI cannot verify.

Scope:

- Show strategy signals in the App.
- Mark matched strategy signals on the chart.
- Allow selecting a signal and jumping to the corresponding raw index/time.
- Display source BSP, relation range, strict-step visibility, rule name, and state.
- Preserve `S1一键复制` or successor one-click evidence for receiver-run UI validation.

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
2. Run `python tools/validate_s6_strategy_signal_sample_coverage.py`.
3. Accept S6 only if the output includes `ok: true`, `no_output_path.ok: true`, `matched_output_path.ok: true`, matched-output traceability fields, compact validation match, no bridge fallback, native lv_list, and no forbidden Dart-side Chan calculation markers.
4. If S6 outputs `ok: false` only because no matched strategy output exists in the pinned fixture, do not accept S6 yet; create or export the smallest backend-traceable matched-output metadata sample.
5. Do not require App evidence unless CLI cannot cover the requirement.
6. Do not add additional large full fixtures unless the manual explicitly requires them.
7. Do not continue performance optimization by default.
8. Write every stage completion summary into this manual after evidence is accepted.
