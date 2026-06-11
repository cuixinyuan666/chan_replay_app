# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this manual: 82a376ee13d0832139bad396224296f0bfc3d86b
Manual placeholder commit: a173ae2cd0f75fdf1b2dcfa5f2c67638546b1574
Manual core commit: e978be56c8f9e173970283cdcf3d7fe3560349ad
Latest task-party code commit: 0a3b7e2482b05cc23721d69e6847954afcaa8e2f
Latest observed head during supervisor verification: 2ef9e055687b9e7ef009821d8e387ad0d2f34bd3
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
- Bridge analyze_multi exists only as a historical prototype and is not accepted as success.
- Native CChan lv_list engine exists.
- MultiLevelReplayPage displays manual P0 diagnostics after Load.
- MultiLevelReplayPage has a one-click P0 diagnostics copy button named `Copy P0`.
- Native CSV input now performs effective-time sort/dedupe before chan.py loading.
- analyze_multi now returns a native-failure diagnostic response instead of a bridge result when native fails.
- MIN30/MIN5 level detection is fixed to preserve intraday timestamps.
- Native once analyze_multi is verified with sane DAILY/MIN30/MIN5 counts.
- Copy P0 now includes status_summary and level_summary.

## Current blockers

- Native step frames are not implemented yet.
- Interval-nest rule engine is not implemented yet.

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

- [x] Verify native analyze_multi runtime result.
- [x] Verify native_cchan_lv_list is true.
- [x] Verify level_relation_mode is chan_parent_child.
- [x] Verify fallback_to_bridge is not true.
- [x] Verify relations can map high level to low level.
- [x] Verify MIN30/MIN5 aligned_counts are larger than DAILY when source data exists.
- [x] Verify native_data_window.bars_per_day has DAILY=1, MIN30=8, MIN5=48.
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
8. Does the native parent-level CSV contain duplicate datetime rows after time normalization?
9. If duplicate rows exist, which level and original rows produce `2026/04/21 23:59` twice?
10. Does native_data_window.bars_per_day show MIN30=8 and MIN5=48?
11. Are MIN30/MIN5 aligned_counts larger than DAILY when source data is available?
12. Does Copy P0 include status_summary and level_summary?

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

2026-06-10 native once accepted:

User reported Copy P0:
- native_cchan_lv_list: true
- level_relation_mode: chan_parent_child
- fallback_to_bridge: false
- native_failure: empty
- relations.length: 4451
- frames.length: 0
- status summary: DAILY K=495 BI=26, MIN30 K=3956 BI=74, MIN5 K=23736 BI=223
- native_data_window.bars_per_day: DAILY=1, MIN30=8, MIN5=48
- aligned_counts: DAILY=495, MIN30=3956, MIN5=23736
- duplicates_removed: DAILY=0, MIN30=0, MIN5=0

Decision:
- Native once CChan(lv_list) is accepted for P0.
- High-to-low native relations exist and count is non-zero.
- MIN30/MIN5 intraday preservation is accepted.
- P0 remains open only because native step frames are not implemented.

Fix/enhancement applied after this report:
- Commit: 0a3b7e2482b05cc23721d69e6847954afcaa8e2f
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: Copy P0 now includes status_summary and level_summary so the bottom status information is copied automatically.

Required next task:
- Implement native step frames.
- Add one-click copy button for step-frame diagnostics before asking for next verification.

2026-06-10 supervisor verification after native once success:

Checked head: 2ef9e055687b9e7ef009821d8e387ad0d2f34bd3
Actual checks:
- Verified commit 0a3b7e2482b05cc23721d69e6847954afcaa8e2f exists.
- Verified it only changes MultiLevelReplayPage Copy P0 diagnostics.
- Verified it adds status_summary to Copy P0.
- Verified it adds level_summary to Copy P0, including K/BI/FX/SEG/ZS/BSP counts per level.
- Verified no backend behavior and no chan.py files were changed in that commit.
Decision:
- The manual's native once P0 acceptance is consistent with the user's Copy P0 data.
- The Copy P0 enhancement claim is true.
- Strict native step frames remain the next blocker and must still be implemented using original chan.py behavior or original chan.py outputs only.
Next user operation after task party implements step:
- Open Multi-level replay, switch to step mode, click Load, then click the future Copy Step diagnostics button and paste the copied result.
