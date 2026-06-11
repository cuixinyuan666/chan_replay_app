# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this manual: 82a376ee13d0832139bad396224296f0bfc3d86b
Manual placeholder commit: a173ae2cd0f75fdf1b2dcfa5f2c67638546b1574
Manual core commit: e978be56c8f9e173970283cdcf3d7fe3560349ad
Latest task-party code commit: 5e277427b35a65061abc2fd363e2dcf3906727ce
Latest manual update commit: pending

## User objective

Build chan.py multi-level support and interval-nest workflow into the app.

The app should support multi-level replay, strict step replay, high-level to low-level mapping, interval-nest signals, training, statistics, scanning, scoring, trade-plan output, timeline, and reports.

## Review rule

All future checks use the latest push on origin_vespa_tdx.

The file named `task checklist and contact.md` is the project manual. Future task execution must follow this manual. Before finishing a task batch, update this manual and add detailed commit notes.

## Current accepted work

- Multi-level models exist.
- Multi-level parser and source exist.
- Independent MultiLevelReplayPage exists.
- RootPage has a multi-level entry.
- Bridge analyze_multi exists as fallback.
- Native CChan lv_list engine exists.
- analyze_multi is native-first with bridge fallback.
- MultiLevelReplayPage now displays manual P0 diagnostics after Load.

## Current blockers

- Native runtime result is not verified after data-window fix.
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

- [ ] Verify native analyze_multi runtime result.
- [ ] Verify native_cchan_lv_list is true.
- [ ] Verify level_relation_mode is chan_parent_child.
- [ ] Verify fallback_to_bridge is not true.
- [ ] Verify relations can map high level to low level.
- [ ] Implement native step frames.
- [ ] Verify step mode frames are not empty.

## P1 checklist

- [ ] Add cursor state to MultiLevelReplayPage.
- [ ] Add replay controls to MultiLevelReplayPage.
- [ ] Use current frame in step mode.
- [ ] Use current frame in MultiLevelLayerStatusPanel.
- [ ] Implement DAILY to MIN30 targeting.
- [ ] Implement MIN30 to MIN5 targeting.

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

Required next local check:
- Pull latest origin_vespa_tdx.
- Run flutter analyze.
- Run flutter run.
- Open Multi-level replay.
- Click Load in once mode.
- Report manual P0 chips again.
