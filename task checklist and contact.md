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
- If repository offline/sample data can reproduce a task, use it for validation. If it cannot be used, document why and wait for supervisor adjudication.

## Receiver workload minimization rule

- Merge compatible checks into one stage when safe.
- Avoid unnecessary task rounds.
- Prefer command-line validation over App validation when a command can verify the same requirement with less receiver work.
- If a pinned/offline validator exists for the current stage, the preferred receiver path is: `git pull` then run the documented validator command.
- For S1-compatible offline checks, highest-priority receiver path is currently `python tools/validate_pinned_s1_fixture.py` after pulling the latest branch.
- Use App validation only when command-line validation cannot verify the UI-specific requirement or when the manual explicitly requires App evidence.
- If the receiver must validate in the App, preset all required defaults.
- For S1-like stages, default to `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B` unless the manual selects another rule.
- Each receiver-run App stage must provide a stage-specific one-click evidence button, such as `S1一键复制` or `Copy S1 Evidence`.
- The one-click payload must include all required evidence for that stage.
- Hide or de-emphasize duplicate copy buttons when one-click evidence covers them.
- Keep low-level copy buttons only for debugging.
- After each small stage, task party must write a completion summary into this manual.

Required completion summary fields:

- completed_tasks
- evidence_button
- validation_result
- remaining_risk
- next_task

## Offline data provision rule

- When matching offline data is missing, task party should first try to export or generate it and upload it to `test/fixtures/pinned/`.
- If task party cannot create the fixture, it must ask supervisor or receiver for help.
- If receiver must run the App to produce data, task party must provide a one-click export/copy flow.
- Receiver should not be asked to perform repeated configuration when defaults can be preset.

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

## S1 summary

- S1 sample-data exception was accepted for this S1 request only.
- Matching offline fixture remains recommended later but is not blocking S1.
- Evidence button originally `Copy S1 Evidence`; receiver-facing alias `S1一键复制` is now implemented by R1.
- Default validation target: `rule mode = strategy`, `strategy rule = DAILY_2B_MIN30_1B`.
- S1 evidence proved high-speed path, native `CChan(lv_list)`, native step frame, no bridge fallback, no final-snapshot step, result validation match, compact validation match, and clean `flutter analyze`.
- S1 validation_result: accepted.

## S2 summary

completed_tasks:

- Selected S2 because S1 was accepted with a live-data exception and the manual recommended creating a matching offline fixture.
- Added `tools/export_pinned_s1_fixture.py` in commit `0da70c70fdc53621ce727b3ab44aeab1cde4583a`.
- Receiver ran `python tools/export_pinned_s1_fixture.py`.
- Exporter generated `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- Receiver committed and pushed the pinned fixture in commit `8bde365`.

validation_result:

- accepted.
- The pinned fixture now covers the accepted S1 baseline request and can be used for later compatible offline validation.

remaining_risk:

- The pinned fixture is about 7.06 MB. Avoid adding many similar full fixtures without manual justification.

## S3 summary

completed_tasks:

- Selected S3 because S2 accepted a pinned fixture and future S1-compatible checks should prefer offline validation.
- Added `tools/validate_pinned_s1_fixture.py` in commit `1e50666911c6d4cc15790b056e380440860d971b`.
- The validator is read-only and checks metadata, compact status, native lv_list flag, no fallback, frame count, levels, relations, and first-frame payloads.
- Receiver ran `python tools/validate_pinned_s1_fixture.py`.

validation_result:

- accepted.
- Receiver output included `ok: true`, fixture size `7407250`, levels `DAILY,MIN30,MIN5`, `frames_total: 29`, `frames_returned: 29`, `compact_validation_status: match`, `compact_validation_mismatch_count: 0`, `native_cchan_lv_list: true`, `fallback_to_bridge: false`, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, and `chan_recalculated: false`.

remaining_risk:

- The pinned fixture remains a 7.06 MB baseline file. For repeated checks, prefer this pinned fixture or a smaller derived fixture.

## R1 summary

completed_tasks:

- Started R1 because commit `d482d7d9b5b1efbc54d4c83f981e0ccfabd32ce6` required receiver burden cleanup before larger business-chain work.
- Updated `lib/ui/widgets/multi_level_interval_signal_panel.dart` in commit `0c52befb4ba9f46af9709c8a9232d9271558f45e`.
- Changed S1-like default `rule mode` from `validation` to `strategy`.
- Kept default strategy rule as `DAILY_2B_MIN30_1B`.
- Preferred receiver-facing one-click button label `S1一键复制`.
- De-emphasized lower-level copy actions by labeling them `Debug: Copy Signal`, `Debug: Copy Time Log`, and `Debug: Copy Result Validation` with debug styling.
- Changed S1 evidence payload status from `pending_runtime_acceptance` to `s1_evidence_exported`.
- Preserved one-click evidence sections: Time Log, P0 Summary, Step Summary, Result Validation, and Signal.
- No `python/chan.py` changes were made.
- No Dart-side FX/BI/SEG/ZS/BSP calculation authority was introduced; the panel still consumes backend snapshot BSPs and native LevelRelation only.

validation_result:

- accepted by App evidence.
- Receiver ran `flutter analyze`: `No issues found! (ran in 12.2s)`.
- Receiver pressed `S1一键复制` and output included `button: S1一键复制`, `rule_mode_ui: strategy`, `signal_rule_mode: strategy_interval_nest_buy`, `strategy_rule_name: DAILY_2B_MIN30_1B`, `debug_copy_tools: de_emphasized`, and `status: s1_evidence_exported`.
- One-click evidence output kept all required sections: `Copy Time Log`, `Copy P0 Summary`, `Copy Step Summary`, `Copy Result Validation`, and `Copy Signal`.
- Lower-level copy sections are marked as debug, including `button: Debug: Copy Time Log`, `button: Debug: Copy Result Validation`, and `button: Debug: Copy Signal`.

evidence_button:

- Main receiver-facing button: `S1一键复制`.
- Debug-only low-level buttons: `Debug: Copy Signal`, `Debug: Copy Time Log`, `Debug: Copy Result Validation`.

remaining_risk:

- App-based validation is heavier than command-line validation when an equivalent CLI validator is available.
- R1b adds CLI validation to reduce receiver burden and answer the prior open question.

## R1b summary

Answer to prior open question:

- Yes, a lighter receiver validation method exists than App one-click evidence for static receiver-burden requirements.
- The lighter path is CLI validation: `git pull`, then `python tools/validate_r1_receiver_burden.py`.
- App evidence remains useful only when UI runtime behavior must be inspected visually or when the manual explicitly requires App evidence.

completed_tasks:

- Added `tools/validate_r1_receiver_burden.py` in commit `70d87b1bda05da2d8691774a3608949f57f154d2`.
- The script statically checks `lib/ui/widgets/multi_level_interval_signal_panel.dart` for strategy default, `DAILY_2B_MIN30_1B` default strategy rule, `S1一键复制` label, debug copy de-emphasis, required evidence sections, `s1_evidence_exported`, absence of `pending_runtime_acceptance`, and absence of known Dart-side Chan calculation markers.
- The script does not run the App, does not request live data, does not import or modify `python/chan.py`, and does not recalculate Chan structures.
- Receiver pulled the script and ran `python tools/validate_r1_receiver_burden.py`.

validation_result:

- accepted.
- Receiver output included `ok: true`, `rule_mode_default: strategy`, `strategy_rule_default: DAILY_2B_MIN30_1B`, `one_click_label: S1一键复制`, debug copy buttons, required evidence sections, `debug_copy_tools: de_emphasized`, `evidence_status: s1_evidence_exported`, `missing: []`, `forbidden: []`, `forbidden_dart_calc_patterns: []`, `chan_recalculated: false`, and `dart_chan_calculation_authority: false`.

next_task:

1. Treat CLI validation as the preferred burden-reduction path for similar static UI-requirement checks.
2. App evidence is only required when the manual asks for UI runtime behavior or visual confirmation.
3. R1b no longer blocks larger business-chain work.

## S4 selected: CLI strategy diagnostics validator

Goal:

- Continue business-chain work using the lowest-burden receiver path.
- Use the pinned S1 fixture as the input.
- Add or reuse a CLI validator that checks strategy diagnostics against the pinned fixture without launching the App.
- Prove the strategy diagnostic path can be validated from command line when the requirement is not visual UI behavior.

completed_tasks:

- Added `tools/validate_s4_cli_strategy_diagnostics.py` in commit `fcabcf93f077fe8275656e343039d4cfbfff7938`.
- The validator defaults to `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- It checks strategy rule `DAILY_2B_MIN30_1B`, source policy, relation pair availability, high/low BSP availability, no-output diagnosis, strict-step frame evidence, compact validation status, bridge fallback, native lv_list flag, and forbidden Dart-side Chan calculation markers.
- It does not launch the App, does not request live data, does not import or modify `python/chan.py`, and does not recalculate Chan FX/BI/SEG/ZS/BSP.

validation_result:

- pending receiver run.
- Preferred command after `git pull`: `python tools/validate_s4_cli_strategy_diagnostics.py`.
- Expected fields:
  - `ok: true`.
  - `strategy_rule_name: DAILY_2B_MIN30_1B`.
  - `source_policy: original chan.py BSP + native LevelRelation only`.
  - relation pairs include `DAILY->MIN30` and `MIN30->MIN5`.
  - `available_signals: 0` for the pinned first-frame/no-output condition.
  - `source_bsp_identifiers: none`.
  - `no_output_diagnosis` explains no candidate matched the current strategy rule.
  - strict-step frame evidence shows `frame_source: native_step_frame` and `final_snapshot_rendered_as_step: false`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
  - `native_cchan_lv_list: true`.
  - `fallback_to_bridge: false`.
  - `forbidden_dart_calc_patterns: []`.
  - `chan_recalculated: false`.
  - `dart_chan_calculation_authority: false`.

S4 acceptance evidence:

- command used;
- validator output;
- `ok: true`;
- completion summary with completed_tasks, evidence_button or command, validation_result, remaining_risk, and next_task.

## Next task-party operation

1. Receiver pulls commit `fcabcf93f077fe8275656e343039d4cfbfff7938`.
2. Receiver runs `python tools/validate_s4_cli_strategy_diagnostics.py`.
3. Accept S4 only if the CLI output passes.
4. Do not require App evidence unless the task party proves CLI cannot cover the requirement.
5. Do not add additional large full fixtures unless the manual explicitly requires them.
6. Do not continue performance optimization by default.
7. Write the S4 completion summary into this manual after evidence is accepted.
