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

## S1 summary

- S1 sample-data exception was accepted for this S1 request only.
- Matching offline fixture remains recommended later but is not blocking S1.
- Evidence button: `Copy S1 Evidence`; recommended receiver-facing alias: `S1一键复制`.
- Default validation target: `rule mode = strategy`, `strategy rule = DAILY_2B_MIN30_1B`.
- S1 evidence proved high-speed path, native `CChan(lv_list)`, native step frame, no bridge fallback, no final-snapshot step, result validation match, compact validation match, and clean `flutter analyze`.
- S1 validation_result: accepted.

## Phase S2: pinned offline fixture export for accepted S1 baseline

In progress.

open_questions: none

completed_tasks:

- Selected S2 as the next business-chain task because S1 was accepted with a live-data exception and the manual still recommends a matching offline fixture.
- Added `tools/export_pinned_s1_fixture.py` in commit `0da70c70fdc53621ce727b3ab44aeab1cde4583a`.
- The exporter defaults to the accepted S1 baseline request:
  - symbol `600340`, market `SH`;
  - levels `DAILY,MIN30,MIN5`;
  - count `220`;
  - max step frames `60`;
  - start/end `2025-09-01` to `2025-10-20`;
  - mode `step`.
- The exporter calls backend `analyze_multi` with original `python/chan.py` as calculation authority, then applies existing compact_v1 transport compaction.
- The exporter writes to `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json` by default.

Evidence button / receiver flow:

- CLI evidence/export command:
  - `python tools/export_pinned_s1_fixture.py`
- The command prints a JSON summary with output path, frames_total, frames_returned, compact validation status, native lv_list flag, fallback flag, and elapsed time.

validation_result:

- pending receiver run.
- Expected successful summary fields:
  - `ok: true`;
  - `compact_validation_status: match`;
  - `compact_validation_mismatch_count: 0`;
  - `native_cchan_lv_list: true`;
  - `fallback_to_bridge: false`.

remaining_risk:

- The script has been committed but has not yet been run by receiver in the App/Python environment.
- The exported JSON fixture has not yet been committed under `test/fixtures/pinned/`.
- The fixture file can be large; commit only after confirming size and validation usefulness.

next_task:

1. Pull commit `0da70c70fdc53621ce727b3ab44aeab1cde4583a`.
2. Run `python tools/export_pinned_s1_fixture.py` from the repository root using the App-bundled or project Python environment.
3. Paste the script JSON summary.
4. If successful and file size is acceptable, commit the generated fixture under `test/fixtures/pinned/`.
5. Then add a fixture validation step for S2 before accepting it.

## Next task-party operation

1. Wait for receiver to run `python tools/export_pinned_s1_fixture.py`.
2. Validate the generated fixture summary.
3. Decide whether to commit the generated pinned fixture file or add a smaller derived fixture.
4. Do not continue performance optimization by default.
