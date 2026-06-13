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

## Next task-party operation

1. Do not continue performance optimization by default.
2. Choose the next business-chain task before implementation.
3. Merge compatible checks into one stage when safe.
4. For receiver-run stages, preset defaults and provide one-click evidence.
5. After each stage, write a completion summary.
6. If matching offline data is missing, try to create/upload it to `test/fixtures/pinned/`; otherwise ask supervisor/receiver for help.
