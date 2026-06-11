# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this manual: 82a376ee13d0832139bad396224296f0bfc3d86b
Manual placeholder commit: a173ae2cd0f75fdf1b2dcfa5f2c67638546b1574
Manual core commit: e978be56c8f9e173970283cdcf3d7fe3560349ad
Latest task-party code commit: c1a7211a837d5d49aba2014edd6f4a6fe22b5066
Latest task-party UI commit: 55fabb72756e072a6d7ffe2b2858a05560f33b5a
Latest observed head during supervisor verification: fa634d67689bf2212c14fefe71327c0af6df4c2e
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

Strict step replay hard rules for both single-level and multi-level pages:

- Strict step replay must use original chan.py step behavior or structures exported from original chan.py step output.
- Strict step replay must not use final fullSnapshot slicing as a success path.
- If mode=step and frames is empty, the UI must show failure or blocked state. It must not render `_sliceSnapshot(fullSnapshot, cursor)` as strict step replay.
- `_sliceSnapshot` may only be used for non-strict preview/debug UI if it is clearly labelled as not strict step.
- These rules apply to both `OriginReplayPageV2` single-level replay and `MultiLevelReplayPage` multi-level replay.
- Verification must include an in-app copy diagnostic proving frames.length > 0, current frame metadata, and current-frame level counts.
- Copy Step diagnostics must remain visible after Load in step mode even when frames.length is zero, so failures can be copied without command-line work.

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
- Native multi-level step frames are implemented through original chan.py CChan(lv_list).step_load outputs.
- MultiLevelReplayPage can render the selected native step frame when frames are returned.
- MultiLevelReplayPage has a one-click step diagnostic copy button named `Copy Step`.
- MultiLevelReplayPage now shows `Copy Step` in step mode after Load even if frames are empty.

## Current blockers

- Multi-level native step frames are implemented but not locally verified yet.
- Single-level `OriginReplayPageV2` still has `_sliceSnapshot(fullSnapshot, cursor)` fallback in step mode and is not accepted as strict step replay.
- Interval-nest rule engine is not implemented yet.

## 16 requested items

1. Multi-level linked replay: in progress.
2. Interval-nest buy and sell signal detection: not done.
3. Higher-level direction plus lower-level trigger plan: not done.
4. Multi-level layer status panel: in progress.
5. Strict step replay for single-level and multi-level: in progress.
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
- [x] Implement native multi-level step frames.
- [ ] Verify multi-level step mode frames are not empty.
- [ ] Remove strict-step `_sliceSnapshot(fullSnapshot, cursor)` fallback from single-level OriginReplayPageV2.
- [ ] Verify single-level step mode frames are not empty and sourced from chan.py step output.
- [ ] Verify both single-level and multi-level strict step fail loudly if frames are empty.
- [x] Remove or disable bridge fallback as accepted behavior for multi-level core Chan calculation.
- [x] Add one-click copy button for P0 diagnostic fields in MultiLevelReplayPage.

## P1 checklist

- [x] Add cursor state to MultiLevelReplayPage.
- [x] Add replay controls to MultiLevelReplayPage.
- [x] Use current frame in MultiLevelReplayPage step mode.
- [x] Use current frame in MultiLevelLayerStatusPanel.
- [ ] Add/verify single-level Copy Step diagnostics.
- [ ] Implement DAILY to MIN30 targeting.
- [ ] Implement MIN30 to MIN5 targeting.
- [x] Add one-click copy button for multi-level step-frame diagnostics.
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
13. Does multi-level Copy Step show native_step_frames=true and frames.length > 0?
14. Does multi-level Copy Step include current-frame level_summary and frame cursor/current_time?
15. Does single-level strict step still call `_sliceSnapshot(fullSnapshot, cursor)` when frames are empty?
16. Does single-level Copy Step prove frames.length > 0 and source is chan.py step output?
17. Is Copy Step visible in multi-level step mode even when frames.length is zero?

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
- P0 remains open only because strict step replay is not fully verified.

Fix/enhancement applied after this report:
- Commit: 0a3b7e2482b05cc23721d69e6847954afcaa8e2f
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: Copy P0 now includes status_summary and level_summary so the bottom status information is copied automatically.

2026-06-10 native multi-level step frames implementation batch:

Backend commits:
- Commit: b074d94d7149cb193f970fb806b8ad1fde74579a
  - File: backend/app/a_multilevel_native_engine.py
  - Change: implemented native CChan(lv_list).step_load frame export; each frame is exported from the yielded chan.py snapshot; frame payloads are capped by max_step_frames=120 by default to avoid huge cumulative minute payloads.
- Commit: 0eaa5f021f806598cd51c7c217fbebdd63eee555
  - File: backend/app/a_multilevel_native_engine.py
  - Change: fixed Python metadata dict syntax in _snapshot_from_chan.
- Commit: c1a7211a837d5d49aba2014edd6f4a6fe22b5066
  - File: backend/app/a_multilevel_native_engine.py
  - Change: fixed missing config argument in the once branch after step-frame refactor.

Frontend commits:
- Commit: 9b76ca7e6d6cb9bdb58cd171046f6982726e95b4
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: step mode now renders selected native frame; added frame slider, previous/next controls, current frame label, current-frame layer panel, and `Copy Step` diagnostics button.
- Commit: 55fabb72756e072a6d7ffe2b2858a05560f33b5a
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: fixed Copy Step visibility so it also appears in the P0 diagnostics bar when mode=step, even if frames are empty.

Decision:
- Multi-level native step frames are implemented in code but not accepted until user verification.
- The user must run the app, switch Multi-level to step, click Load, click `Copy Step`, and paste diagnostics.
- P0 remains open for multi-level step-frame verification and single-level strict-step fallback removal.

2026-06-10 supervisor strict-step rule update:

Checked head: fa634d67689bf2212c14fefe71327c0af6df4c2e
Actual verification:
- Multi-level backend bridge fallback is disabled as accepted behavior: analyze_multi returns native failure diagnostics instead of bridge result when native fails.
- Multi-level backend step implementation uses CChan(lv_list).step_load in code commit b074d94d7149cb193f970fb806b8ad1fde74579a, but still needs Copy Step runtime verification.
- MultiLevelReplayPage uses returned frames when available and provides Copy Step diagnostics, but if step mode returns no frames the page can still expose final snapshot in `_current`; this must fail loudly instead of looking like strict replay.
- Single-level OriginReplayPageV2 still uses `_sliceSnapshot(analysis.snapshot, cursor)` when mode=step and frames is empty.
- Single-level reset/forward/back/jump also fall back to `_sliceSnapshot(_fullSnapshot, cursor)` when frames is empty.

Decision:
- Strict step hard rule now applies to both single-level and multi-level pages.
- Any page in step mode must use chan.py step frames only.
- If frames are empty, the page must show a blocked/failure state and must not render final-snapshot slicing as strict replay.
- Single-level strict step is currently not accepted.
- Multi-level strict step is pending Copy Step verification and must also fail loudly if frames are empty.

Next user operation after task party finishes:
- For multi-level: open Multi-level replay, switch to step, click Load, click Copy Step, paste diagnostics.
- For single-level: open Replay page, switch to strict step, click Load, use the future single-level Copy Step diagnostics if added, paste diagnostics.
