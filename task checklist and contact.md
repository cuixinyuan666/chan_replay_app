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
- Evidence button: `Copy S1 Evidence`; recommended receiver-facing alias: `S1一键复制`.
- Default validation target: `rule mode = strategy`, `strategy rule = DAILY_2B_MIN30_1B`.
- S1 evidence proved high-speed path, native `CChan(lv_list)`, native step frame, no bridge fallback, no final-snapshot step, result validation match, compact validation match, and clean `flutter analyze`.
- S1 validation_result: accepted.

## S2 summary

completed_tasks:

- Selected S2 as the next business-chain task because S1 was accepted with a live-data exception and the manual recommended creating a matching offline fixture.
- Added `tools/export_pinned_s1_fixture.py` in commit `0da70c70fdc53621ce727b3ab44aeab1cde4583a`.
- Receiver ran `python tools/export_pinned_s1_fixture.py` from the repository root.
- Exporter generated `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- Receiver checked file size: `Length: 7407250` bytes, about 7.06 MB.
- Receiver committed and pushed the pinned fixture in commit `8bde365` with message `test(fixtures): add pinned S1 multi-level fixture`.
- Remote fixture blob is present at the pinned fixture path.

exporter validation_result:

- `ok: true`.
- `frames_total: 29`.
- `frames_returned: 29`.
- `compact_validation_status: match`.
- `compact_validation_mismatch_count: 0`.
- `native_cchan_lv_list: true`.
- `fallback_to_bridge: false`.
- `elapsed_ms: 7760`.

validation_result:

- accepted.
- The pinned fixture now covers the accepted S1 baseline request and can be used for later offline validation.
- S2 acceptance does not accept any new Chan calculation path, Dart-side Chan calculation, bridge fallback, Chan result cache, final-snapshot fake step, or performance optimization phase.

evidence_button:

- CLI evidence/export command: `python tools/export_pinned_s1_fixture.py`.
- Generated fixture evidence: committed pinned JSON fixture under `test/fixtures/pinned/`.

remaining_risk:

- The pinned fixture is about 7.06 MB. It is acceptable as a single baseline fixture, but similar full fixtures should not be added repeatedly without manual justification.
- If future tests require many fixtures, prefer smaller derived fixtures or fixture metadata indexes.

next_task:

1. Use the pinned S1 fixture for subsequent validation stages when compatible.
2. Do not continue performance optimization by default.
3. Preserve high-speed path as default and slow path as debug/baseline only.
4. Choose the next business-chain task before implementation.

## S3 summary

completed_tasks:

- Selected S3 as the next business-chain task because S2 accepted a pinned fixture and future S1-compatible checks should prefer offline validation.
- Added `tools/validate_pinned_s1_fixture.py` in commit `1e50666911c6d4cc15790b056e380440860d971b`.
- The validator is read-only. It loads the pinned JSON fixture and checks metadata, compact transport status, native lv_list flag, no fallback, frame count, level availability, relation pairs, and first-frame level payloads.
- The validator does not request live data, does not import or modify `python/chan.py`, and does not recalculate Chan structures.
- Receiver ran `python tools/validate_pinned_s1_fixture.py` from the repository root.

validation_result:

- accepted.
- Receiver output included:
  - `ok: true`.
  - `fixture_size_bytes: 7407250`.
  - levels: `DAILY`, `MIN30`, `MIN5`.
  - `frames_total: 29`.
  - `frames_returned: 29`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
  - `native_cchan_lv_list: true`.
  - `fallback_to_bridge: false`.
  - relation pairs: `DAILY->MIN30`, `MIN30->MIN5`.
  - level counts: DAILY raw 29 / BI 2 / BSP 0; MIN30 raw 232 / BI 5 / SEG 2 / BSP 0; MIN5 raw 1392 / BI 15 / SEG 4 / ZS 1 / BSP 2.
  - `validator: tools/validate_pinned_s1_fixture.py`.
  - `chan_recalculated: false`.
- S3 acceptance does not accept any new Chan calculation path, Dart-side Chan calculation, bridge fallback, Chan result cache, final-snapshot fake step, or performance optimization phase.

evidence_button:

- CLI validation command: `python tools/validate_pinned_s1_fixture.py`.

remaining_risk:

- The pinned fixture remains a 7.06 MB baseline file. Avoid adding many similar full fixtures without manual justification.
- For future repeated checks, prefer this pinned fixture or a smaller derived fixture.

next_task:

1. Use `tools/validate_pinned_s1_fixture.py` before S1-compatible offline validations.
2. Use the pinned fixture as default offline evidence for compatible strategy diagnostics.
3. Do not continue performance optimization by default.
4. Choose the next business-chain task before implementation.

## Next task-party operation

1. Use `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json` as preferred offline fixture for S1-compatible checks.
2. Use `python tools/validate_pinned_s1_fixture.py` for fixture sanity checks.
3. Do not add additional large full fixtures unless the manual explicitly requires them.
4. Do not continue performance optimization by default.
5. Choose the next business-chain task before implementation.
