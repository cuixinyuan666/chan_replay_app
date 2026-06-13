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
- If the receiver must validate in the App, preset all required defaults.
- For S1-like stages, default to `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B` unless the manual selects another rule.
- Each receiver-run stage must provide a stage-specific one-click evidence button, such as `S1一键复制` or `Copy S1 Evidence`.
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

## S1 summary

- S1 sample-data exception was accepted for this S1 request only.
- Matching offline fixture remains recommended later but is not blocking S1.
- Evidence button: `Copy S1 Evidence`; recommended receiver-facing alias `S1一键复制`.
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

## R1 pending: receiver burden code cleanup

Reason:

- Supervisor found four receiver-burden issues in the current code after S1 acceptance.
- These issues do not invalidate S1 calculation evidence, but they do not fully satisfy the receiver workload minimization rule.

completed_tasks:

- Started R1 because commit `d482d7d9b5b1efbc54d4c83f981e0ccfabd32ce6` requires R1 before larger business-chain work.
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

- pending receiver `flutter analyze`.
- pending receiver check of the one-click S1 evidence output.

R1 acceptance criteria:

- Receiver can validate S1-like stage mainly by pressing one stage-specific button.
- Default UI choices match the current stage requirements.
- One-click evidence remains complete.
- Lower-level copy tools remain available only as debugging aids.
- No Dart-side Chan calculation is introduced.
- `flutter analyze` passes.
- Task party writes completion summary with completed_tasks, evidence_button, validation_result, remaining_risk, and next_task.

evidence_button:

- Main receiver-facing button: `S1一键复制`.
- Debug-only low-level buttons: `Debug: Copy Signal`, `Debug: Copy Time Log`, `Debug: Copy Result Validation`.

remaining_risk:

- The panel was simplified while preserving diagnostic output. Receiver must run `flutter analyze` before R1 acceptance.
- If UI behavior regresses, revert only the UI simplification while keeping the four R1 requirements.

next_task:

1. Receiver pulls commit `0c52befb4ba9f46af9709c8a9232d9271558f45e`.
2. Receiver runs `flutter analyze`.
3. Receiver opens an S1-like strategy panel and presses `S1一键复制`.
4. Receiver verifies output includes `rule_mode_ui: strategy`, `strategy_rule_name: DAILY_2B_MIN30_1B`, `status: s1_evidence_exported`, full evidence sections, and debug copy tools de-emphasized.
5. If validation passes, accept R1.

## Next task-party operation

1. Wait for receiver to run `flutter analyze` after pulling R1 code.
2. Wait for receiver to paste `S1一键复制` evidence output or at least the key R1 fields.
3. Accept R1 only after static analysis and one-click evidence output pass.
4. Do not start a larger business-chain task before R1 is accepted or explicitly deferred by the supervisor.
5. Do not continue performance optimization by default.
