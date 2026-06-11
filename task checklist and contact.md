# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this manual: 82a376ee13d0832139bad396224296f0bfc3d86b
Manual placeholder commit: a173ae2cd0f75fdf1b2dcfa5f2c67638546b1574
Manual core commit: e978be56c8f9e173970283cdcf3d7fe3560349ad
Latest task-party code commit: 1cc0b53211d5a3fa895d8259b3f54f1edf5fb0af
Latest observed head during supervisor verification: 3bf4cb4775057cc1d8d1af21bd68adfa52551373
Latest manual update commit: pending

## User objective

Build chan.py multi-level support and interval-nest workflow into the app.

The app should support multi-level replay, strict step replay, high-level to low-level mapping, interval-nest signals, training, statistics, scanning, scoring, trade-plan output, timeline, and reports.

## Review rule

All future checks use the latest push on origin_vespa_tdx.

The file named `task checklist and contact.md` is the project manual. Future task execution must follow this manual. Before finishing a task batch, update this manual and add detailed commit notes.

Hard rules added by user:

- All Chan calculation logic must always stay centered on the original chan.py implementation.
- Do not invent or recreate Chan logic in Flutter, Dart, or custom Python code. Only call, serialize, display, and coordinate the original chan.py outputs.
- Do not use fallback logic for core Chan calculation. Failure must be surfaced as failure.
- Bridge fallback is not accepted as completion. If native CChan(lv_list) fails, the task status is failed or blocked, not passed.
- If diagnostic information is needed, add a suitable in-app one-click copy button near the relevant UI area.
- Avoid asking the user to operate in the command line when the same information can be copied from the app.
- In direct communication with the user, explicitly say which app button to click to copy the required information.

## Current accepted work

- Multi-level models exist.
- Multi-level parser and source exist.
- Independent MultiLevelReplayPage exists.
- RootPage has a multi-level entry.
- Bridge analyze_multi exists only as a prototype/fallback and is not accepted as success.
- Native CChan lv_list engine exists.
- MultiLevelReplayPage displays manual P0 diagnostics after Load.
- MultiLevelReplayPage has a one-click P0 diagnostics copy button named `Copy P0`.

## Current blockers

- Native runtime result is not verified after parent-time fix.
- Native step frames are not implemented yet.
- Interval-nest rule engine is not implemented yet.
- Bridge fallback still exists in code and must not be counted as successful core Chan calculation.

## 16 requested items

1. Multi-level linked replay: in progress.
2. Interval-nest buy and sell signal detection: not done.
3. Higher-level direction plus lower-level trigger plan: not done.
4. Multi-level layer status panel: in progress.
5. Strict step multi-level replay: in progress.
6. Interval-nest training mode: not done.
7. Interval-nest historical statistics: not done.
8. Multi-level scanner: not done.
9. BSP quality score: not done.
10. Stop and target generation: not done.
11. Current level obeying higher level: not done.
12. Multi-level divergence detection: not done.
13. Interval-nest replay report: not done.
14. Visibility and future-data risk marking: in progress.
15. Signal replay timeline: not done.
16. TV toolbar and indicator linkage: in progress.

## P0 checklist

- [ ] Verify native analyze_multi runtime result.
- [ ] Verify native_cchan_lv_list is true.
- [ ] Verify level_relation_mode is chan_parent_child.
- [ ] Verify fallback_to_bridge is not true.
- [ ] Verify relations can map high level to low level.
- [ ] Implement native step frames.
- [ ] Verify step mode frames are not empty.
- [ ] Remove or disable bridge fallback as accepted behavior for core Chan calculation.
- [x] Add one-click copy button for P0 diagnostic fields in MultiLevelReplayPage.

## P1 checklist

- [ ] Add cursor state to MultiLevelReplayPage.
- [ ] Add replay controls to MultiLevelReplayPage.
- [ ] Use current frame in step mode.
- [ ] Use current frame in MultiLevelLayerStatusPanel.
- [ ] Implement DAILY to MIN30 targeting.
- [ ] Implement MIN30 to MIN5 targeting.
- [ ] Add one-click copy button for step-frame diagnostics.
- [ ] Add one-click copy button for high-to-low relation diagnostics.

## P2 checklist

- [ ] DAILY 2-buy plus MIN30 1-buy signal.
- [ ] DAILY 2-buy plus MIN30 2-buy signal.
- [ ] DAILY 3-buy plus MIN30 1-buy signal.
- [ ] DAILY 3-buy plus MIN30 2-buy signal.

## Questions for task party

1. Does analyze_multi return native_cchan_lv_list true?
2. Does analyze_multi return level_relation_mode chan_parent_child?
3. Is fallback_to_bridge absent or false?
4. What is relations.length?
5. Does step mode return frames?
6. Which in-app button should the user click to copy P0 diagnostics?
7. Which in-app button should the user click to copy step-frame diagnostics?

## Task party reply template

latest commit:
completed items:
modified files:
local checks:
result:
native_cchan_lv_list:
level_relation_mode:
fallback_to_bridge:
native_failure:
frames length:
relations length:
copy button added:
button name for user:
open issues:
questions:

## Supervisor decisions

2026-06-10 initial decision:

Result: partially passed.
Accepted: multi-level models, native engine file, native-first routing, independent multi-level page entry.
Not accepted: native runtime not verified, native step frames not implemented, interval-nest rule engine not implemented.
Next task: report native once meta and relations. If fallback occurs, fix native_failure first. If native succeeds, implement native step frames.

2026-06-10 task-party update:

Result: still pending local verification.
Accepted in this batch: MultiLevelReplayPage displays manual P0 diagnostics so the user can report native runtime fields without reading raw JSON.
Not accepted yet: native runtime, native step frames, interval-nest rule engine.
Required local checks:
- Run flutter analyze.
- Run flutter run.
- Open Multi-level replay.
- Click Load in once mode.
- Report visible manual P0 chips: native_cchan_lv_list, level_relation_mode, fallback_to_bridge, native_failure, frames.length, relations.length.
Next task after local result:
- If fallback_to_bridge=true, fix native_failure first.
- If fallback_to_bridge is false and native_cchan_lv_list=true, implement native step frames.

2026-06-10 user P0 result:

Reported chips:
- manual P0: needs check
- native_cchan_lv_list: false
- native_failure: sub-level K alignment failed
- level_relation_mode: time_date_bridge
- fallback_to_bridge: true
- relations.length: 235
- frames.length: 0

Decision:
- P0 failed because native CChan(lv_list) fell back to bridge.
- Per manual, next work must fix native_failure before step frames or interval-nest features.

Fix applied:
- Commit: 5e277427b35a65061abc2fd363e2dcf3906727ce
- File: backend/app/a_multilevel_native_engine.py
- Cause: DAILY / MIN30 / MIN5 all used the same count value. DAILY count=800 covers far more dates than MIN30/MIN5 count=800, so chan.py found high-level bars without sub-level bars.
- Change: lower levels now request expanded counts, all levels are then trimmed to a common date window before CSV preparation.
- Requirement: keep chan.py kl_data_check enabled; do not bypass native validation.

2026-06-10 supervisor review after latest push:

Checked head: 166a46bdfe37276158f05f76bf2602de7c690467
Result: partially passed.
Accepted: data-window fix commit was recorded in the manual. The fix keeps chan.py validation instead of bypassing it.
Not accepted: latest head is a manual-only commit; native runtime after the data-window fix is still not verified. Native step frames are still not implemented. Bridge fallback still exists and must not be counted as success for core Chan calculation.
New user rules added: original chan.py only; no invented Chan logic; no accepted fallback for core Chan calculation; add in-app one-click copy buttons for diagnostics.
Next task: task party must add or confirm an in-app one-click copy button for P0 diagnostics, then the user should click that button after Multi-level -> Load and paste the copied text. If fallback is still true, fix native_failure. If native succeeds, implement native step frames.

2026-06-10 second P0 report and fixes:

User result: native still fell back to bridge with sub-level alignment failure; flutter analyze reported four withOpacity deprecation info items.

Fixes applied:
- Commit: 11c25deffb03b85b3e5e4b62c974f67a9ab36bcc
  - File: backend/app/a_multilevel_native_engine.py
  - Cause refined: chan.py CSV_API parses non-intraday YYYY-MM-DD as 00:00, while intraday child bars are later in the same day. Native parent-child matching therefore failed to attach children to same-day parent bars.
  - Change: non-intraday parent levels are written to chan.py CSV at 23:59 only for native CSV loading. UI/output bars keep original times.
- Commit: 93a2a96a31597f8a7565fd1ed3de0893a7a39b69
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: replaced deprecated withOpacity usage.
- Commit: cfee607a3491e2d19c9ebe5e13d658306bee8d05
  - File: lib/ui/widgets/multi_level_layer_status_panel.dart
  - Change: replaced deprecated withOpacity usage.
- Commit: 1cc0b53211d5a3fa895d8259b3f54f1edf5fb0af
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: added one-click `Copy P0` diagnostics button.

Required next local check:
- Stop any old Python backend process that may still be serving old code.
- Pull latest origin_vespa_tdx.
- Run flutter analyze.
- Run flutter run.
- Open Multi-level replay.
- Click Load in once mode.
- Click `Copy P0`.
- Paste the copied diagnostics.

2026-06-10 supervisor verification of latest push:

Checked head: 3bf4cb4775057cc1d8d1af21bd68adfa52551373
Manual progress check:
- The manual claims `Copy P0` exists. Verified in actual code: MultiLevelReplayPage imports Clipboard, renders `Copy P0`, and copies `_buildP0DiagnosticText`.
- The manual claims parent-time fix exists. Verified in actual code: non-intraday parent bars are written to native CSV at 23:59 while UI/output bars keep original times.
- The manual keeps native runtime unchecked. This is correct because the latest head is manual-only and no post-fix P0 copy result from the user is present.
Actual code check:
- `Copy P0` button exists and copies native_cchan_lv_list, level_relation_mode, fallback_to_bridge, native_failure, relations.length, frames.length, source, native_data_window, and native_csv_time_policy.
- Native CChan(lv_list) still returns `frames: []` and `native_step_frames: False`; strict step is not complete.
- Bridge fallback still exists in `a_multilevel_engine.analyze_multi`; it records fallback_to_bridge and native_failure. This is useful for debugging but not acceptable as a passing core Chan path.
Result: partially passed.
Accepted in this check:
- P0 copy button is real and may stay checked.
- Parent-time CSV fix is real.
Rejected / still open:
- Native runtime after parent-time fix is still unverified.
- Strict step native frames remain unimplemented.
- Bridge fallback still exists and must not be considered success.
Next user operation:
- In the app, open `Multi-level replay`, click `Load`, then click `Copy P0`, and paste the copied diagnostics.
Next task-party operation:
- If copied diagnostics show fallback_to_bridge=true, fix native_failure immediately.
- If copied diagnostics show native_cchan_lv_list=true and level_relation_mode=chan_parent_child, implement native step frames next.
