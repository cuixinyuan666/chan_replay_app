# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this supervisor update: 07b83ab51ac681161a6baa3943284b1b6c3315da
Latest multi-level strict-step UI commit: 763d6219e7aaa5732f7d62aca1474c5a0c4b9303
Latest single-level strict replay page commit: bb5f9faeeea18bffdd12afd4f5d4b3d0d3790d70
Latest replay route commit: 6de1a244db4c522796a300d06a02b85b7e5bffb5
Latest backend/data commit: 2643cb70e544940bed17701ba789529298a37ff1
Latest root default commit: 6a88fcbd67a67512775a6eed7e5541458c3c5724
Latest manual update commit: pending

## User objective

Build chan.py multi-level support and interval-nest workflow into the app.

The app should support multi-level replay, strict step replay, high-level to low-level mapping, interval-nest signals, training, statistics, scanning, scoring, trade-plan output, timeline, and reports.

## Review rule

All future checks use the latest push on `origin_vespa_tdx`.

The file named `task checklist and contact.md` is the project manual. Future task execution must follow this manual. Before finishing a task batch, update this manual and add detailed commit notes.

## Hard rules

- All Chan calculation logic must always stay centered on the original chan.py implementation.
- Do not invent or recreate Chan logic in Flutter, Dart, or custom Python code. Only call, serialize, display, and coordinate the original chan.py outputs.
- Do not use fallback logic for core Chan calculation. Failure must be surfaced as failure.
- Bridge fallback is not accepted as completion. If native CChan(lv_list) fails, the task status is failed or blocked, not passed.
- If diagnostic information is needed, add a suitable in-app one-click copy button near the relevant UI area.
- Avoid asking the user to operate in the command line when the same information can be copied from the app.
- In direct communication with the user, explicitly say which app button to click to copy the required information.

## Strict step replay hard rules

These rules apply to both single-level replay and multi-level replay.

- Strict step replay must use original chan.py step behavior or structures exported from original chan.py step output.
- Strict step replay must not use final fullSnapshot slicing as a success path.
- If `mode=step` and `frames.length=0`, the UI must show failure or blocked state.
- If `mode=step` and `frames.length=0`, the UI must not render `_sliceSnapshot(fullSnapshot, cursor)` or any final snapshot as strict step.
- `_sliceSnapshot` may only be used for non-strict preview/debug UI if clearly labelled as not strict step.
- Verification must include an in-app copy diagnostic proving frames.length, source, current frame metadata, and current-frame counts.
- Copy Step diagnostics must remain visible after Load in step mode even when frames.length is zero.

## Current accepted work

- Multi-level models exist.
- Multi-level parser and source exist.
- Independent MultiLevelReplayPage exists.
- RootPage has a multi-level entry and defaults to MultiLevelReplayPage.
- Bridge analyze_multi exists only as a historical prototype and is not accepted as success.
- Native CChan lv_list engine exists.
- Native CSV input performs effective-time sort/dedupe before chan.py loading.
- analyze_multi returns a native-failure diagnostic response instead of a bridge result when native fails.
- MIN30/MIN5 level detection is fixed to preserve intraday timestamps.
- Native once analyze_multi is verified with sane DAILY/MIN30/MIN5 counts.
- Native multi-level step frames are implemented through original chan.py `CChan(lv_list).step_load()` outputs.
- MultiLevelReplayPage renders selected native step frame when frames are returned.
- MultiLevelReplayPage has one-click `Copy P0` and `Copy Step` diagnostics.
- MultiLevelReplayPage shows `Copy Step` in step mode after Load even if frames are empty.
- Lightweight multi-level step verification passed for default count=40 / max_step_frames=24.
- MultiLevelReplayPage now fails loudly when step mode returns frames.length=0 and does not render the final snapshot as a current step frame.
- OriginReplayPageV2 is not built on startup, so replay-page default data load is temporarily stopped.
- App startup defaults to MultiLevelReplayPage instead of OriginReplayPageV2.
- RootPage Replay toolbar entry now routes to `OriginReplayStrictPage`, not `OriginReplayPageV2`.
- `OriginReplayStrictPage` uses backend returned frames only in step mode and shows blocked state when frames.length=0.
- `OriginReplayStrictPage` has one-click `Copy Step` diagnostics.

## Current blockers

- Multi-level lightweight step is verified, but full-history non-truncated step replay is not accepted yet.
- Single-level strict replay route is implemented, but user runtime verification is pending.
- Legacy `OriginReplayPageV2` still exists in the repository and still contains `_sliceSnapshot`; it is not the active Replay route now, but it should be deleted, renamed legacy, or refactored later if the project requires direct use.
- Single-level Copy Step diagnostics need user verification.
- Interval-nest rule engine is not implemented yet.

## Task organization policy: no toothpaste delivery

Task party must deliver work in dependent batches. Small commits are allowed, but acceptance is by batch, not by isolated small edits. A batch is not accepted unless its code path, UI path, diagnostics button, and user-verifiable copy output are all present.

### Batch A: Strict step replay closure, highest priority

Goal: make strict step truthful on both single-level and multi-level pages.

Required tasks:
- A1. MultiLevelReplayPage must not show final snapshot as strict step when mode=step and frames.length=0. Done in code: 763d6219e7aaa5732f7d62aca1474c5a0c4b9303.
- A2. MultiLevelReplayPage must show blocked/failure state and Copy Step diagnostics when frames.length=0. Done in code: 763d6219e7aaa5732f7d62aca1474c5a0c4b9303.
- A3. MultiLevelReplayPage Copy Step must prove native_step_frames=true, frames.length>0, current frame cursor/time, current frame level counts, and whether frames are truncated. Done and accepted for lightweight default step path.
- A4. Active single-level Replay route must not use `_sliceSnapshot(fullSnapshot, cursor)` as strict-step fallback. Done in active route by adding `OriginReplayStrictPage` and routing RootPage to it: bb5f9faeeea18bffdd12afd4f5d4b3d0d3790d70 / 6de1a244db4c522796a300d06a02b85b7e5bffb5. Legacy V2 file remains and is not active route.
- A5. Active single-level Replay route must use chan.py step frames only in strict step mode. Done in code; user verification pending.
- A6. Active single-level Replay route must fail loudly if mode=step and frames.length=0. Done in code; user verification pending.
- A7. Active single-level Replay route must add Copy Step diagnostics with source, frames.length, current frame index/time, and K/FX/BI/SEG/ZS/BSP counts. Done in code; user verification pending.
- A8. Startup auto-load must remain safe: no default freeze; if step payload is too heavy, optimize payload shape instead of only raising timeout. Lightweight startup path accepted.
- A9. If frames are truncated for safety, UI and diagnostics must clearly show native cursor range and that local frame 1 is not necessarily native cursor 0. Done for multi-level Copy Step.
- A10. Full-history or paged step replay must be planned before claiming complete strict replay over the entire selected range. Pending.

Acceptance:
- User can copy Multi-level Copy Step after Load. Accepted.
- User can copy Single-level Copy Step after Load. Pending.
- Both diagnostics show frames.length>0 for valid step cases. Multi-level accepted; single-level pending.
- Both pages fail loudly and copy diagnostic if frames.length=0. Multi-level implemented; active single-level route implemented but pending verification.
- No fullSnapshot slicing is used as a strict-step success path in active routes. Implemented for active routes; legacy V2 caveat remains.
- Truncated multi-level frames are accepted only as startup safety verification, not as full strict replay.

Do not proceed to Batch B until Batch A is accepted.

### Batch B: Multi-level relation navigation and targeting

Blocked until Batch A is accepted.

Required tasks:
- B1. Click/select DAILY K/BI/ZS/BSP and locate corresponding MIN30 range using native relations.
- B2. Click/select MIN30 K/BI/ZS/BSP and locate corresponding MIN5 range using native relations.
- B3. The relation lookup must respect current step frame when in step mode.
- B4. Add Copy Relation diagnostics: parent level/index/time, child level start/end/index/time, relation count, active frame.
- B5. No synthetic relation logic is allowed; use native chan.py parent-child relation data only.

### Batch C: Interval-nest signal engine MVP

Blocked until Batch B is accepted.

Required tasks:
- C1. Use original chan.py BSP outputs only.
- C2. Use native relation ranges to bind high-level and low-level signals.
- C3. Add signal state: candidate / confirmed / invalidated.
- C4. Add visibleAt / confirmedAt / rawIndex or equivalent timing markers to avoid future-function ambiguity.
- C5. Add Copy Signal diagnostics.

### Batch D: Trading plan and quality score

Blocked until signal semantics are stable.

### Batch E: Training, statistics, scanner, report

Blocked until signal semantics are stable.

## P0 checklist

- [x] Verify native analyze_multi runtime result.
- [x] Verify native_cchan_lv_list is true.
- [x] Verify level_relation_mode is chan_parent_child.
- [x] Verify fallback_to_bridge is not true.
- [x] Verify relations can map high level to low level.
- [x] Verify MIN30/MIN5 aligned_counts are larger than DAILY when source data exists.
- [x] Verify native_data_window.bars_per_day has DAILY=1, MIN30=8, MIN5=48.
- [x] Implement native multi-level step frames.
- [x] Verify lightweight multi-level step mode frames are not empty.
- [x] MultiLevelReplayPage fails loudly instead of showing final snapshot when mode=step and frames.length=0.
- [ ] Plan or implement full-history/paged multi-level step replay beyond truncated startup safety profile.
- [x] Active single-level Replay route avoids strict-step `_sliceSnapshot(fullSnapshot, cursor)` fallback.
- [ ] Verify single-level step mode frames are not empty and sourced from chan.py step output.
- [ ] Verify both single-level and multi-level strict step fail loudly if frames are empty.
- [x] Remove or disable bridge fallback as accepted behavior for multi-level core Chan calculation.
- [x] Add one-click copy button for P0 diagnostic fields in MultiLevelReplayPage.

## P1 checklist

- [x] Add cursor state to MultiLevelReplayPage.
- [x] Add replay controls to MultiLevelReplayPage.
- [x] Use current frame in MultiLevelReplayPage step mode when frames are present.
- [x] Use current frame in MultiLevelLayerStatusPanel when frames are present.
- [x] Add single-level Copy Step diagnostics in active Replay route.
- [ ] Verify single-level Copy Step diagnostics.
- [ ] Implement DAILY to MIN30 targeting.
- [ ] Implement MIN30 to MIN5 targeting.
- [x] Add one-click copy button for multi-level step-frame diagnostics.
- [ ] Add one-click copy button for high-to-low relation diagnostics.

## Questions for task party

1. Does analyze_multi return native_cchan_lv_list true?
2. Does analyze_multi return level_relation_mode chan_parent_child?
3. Is fallback_to_bridge absent or false?
4. What is relations.length?
5. Does step mode return frames?
6. Which in-app button should the user click to copy P0 diagnostics?
7. Which in-app button should the user click to copy step-frame diagnostics?
8. Does Copy Step show native_step_frames=true and frames.length > 0?
9. Does Copy Step include current-frame level_summary and frame cursor/current_time?
10. Does Copy Step show whether frames are truncated and what native cursor range is returned?
11. Does active single-level strict route use `OriginReplayStrictPage` instead of legacy `OriginReplayPageV2`?
12. Does active single-level Copy Step prove frames.length > 0 and source is chan.py step output?
13. Is Copy Step visible in multi-level step mode even when frames.length is zero?
14. Does app startup default to MultiLevelReplayPage and avoid building OriginReplayPageV2?
15. Does default MultiLevelReplayPage auto-load step mode with count=40 and max_step_frames=24?
16. If default step still freezes, what payload-shape optimization was made instead of simply increasing timeout?

## Task party reply template

latest commit:
completed batch:
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
- P0 remains open because strict step replay is not fully verified.

2026-06-10 native multi-level step frames implementation batch:

Backend commits:
- Commit: b074d94d7149cb193f970fb806b8ad1fde74579a
  - File: backend/app/a_multilevel_native_engine.py
  - Change: implemented native CChan(lv_list).step_load frame export.
- Commit: 0eaa5f021f806598cd51c7c217fbebdd63eee555
  - File: backend/app/a_multilevel_native_engine.py
  - Change: fixed Python metadata dict syntax in _snapshot_from_chan.
- Commit: c1a7211a837d5d49aba2014edd6f4a6fe22b5066
  - File: backend/app/a_multilevel_native_engine.py
  - Change: fixed missing config argument in the once branch after step-frame refactor.

Frontend commits:
- Commit: 9b76ca7e6d6cb9bdb58cd171046f6982726e95b4
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: step mode renders selected native frame when frames are present.
- Commit: 55fabb72756e072a6d7ffe2b2858a05560f33b5a
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: fixed Copy Step visibility in the P0 diagnostics bar.
- Commit: 763d6219e7aaa5732f7d62aca1474c5a0c4b9303
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Change: step mode with frames.length=0 now shows blocked state and does not render final snapshot as a current step frame.

Decision:
- Multi-level native step frames are implemented in code.
- Multi-level runtime verification is accepted after Copy Step diagnostics.
- Multi-level empty-frame fail-loud behavior is implemented in code.
- P0 remains open for active single-level route runtime verification and full-history/paged plan.

2026-06-10 default startup / timeout / freeze change:

User reported:
- multi-level step load failed with `TimeoutException after 0:01:00.000000: Future not completed`.
- after a long load, the app directly froze.
- User requested temporarily stopping default replay-page data loading on app startup.
- User requested default app load to be multi-level step data.

Fixes applied and verified in code:
- Commit: 6a88fcbd67a67512775a6eed7e5541458c3c5724
  - File: lib/ui/pages/root_page.dart
  - Verified: app starts on MultiLevelReplayPage; OriginReplayPageV2 is not visited/built on startup, so its initState auto-load does not run.
- Commit: c5fe666b2d82b9a1bacdf610af6abda7ef6c082a
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Verified: MultiLevelReplayPage defaults to step mode and auto-loads after first frame.
- Commit: 2643cb70e544940bed17701ba789529298a37ff1
  - File: lib/data/python_multi_level_chan_analysis_source.dart
  - Verified: step analyze_multi POST timeout is 180s and once timeout is 90s.
- Commit: bff2fb57925ba0a24f6ada38eb75888bb1797698
  - File: lib/ui/pages/multi_level_replay_page.dart
  - Verified: default startup count is 40 and max_step_frames is 24.

Decision:
- Default replay-page loading is temporarily stopped.
- Default multi-level step loading remains enabled but uses a lightweight startup safety profile.
- If default step still freezes, next fix must optimize backend frame payload shape instead of increasing timeout.

2026-06-10 user lightweight multi-level Copy Step verification:

User reported Copy Step:
- copy_step_visible: true
- step_controls_visible: true
- mode: step
- native_cchan_lv_list: true
- level_relation_mode: chan_parent_child
- fallback_to_bridge: false
- native_step_frames: true
- native_step_frames_total: 40
- native_step_frames_returned: 24
- native_step_frames_limit: 24
- native_step_frames_truncated: true
- frames.length: 24
- frame.index.local: 0
- frame.number.local: 1/24
- frame.cursor.native: 16
- frame.current_time: 2026-05-11 00:00:00
- frame.relations.length: 153
- current frame counts: DAILY K=17 BI=1, MIN30 K=136 BI=1, MIN5 K=816 BI=4
- final counts: DAILY K=40 BI=2, MIN30 K=317 BI=4, MIN5 K=1897 BI=14
- native_data_window aligned_counts: DAILY=40, MIN30=317, MIN5=1897
- bars_per_day: DAILY=1, MIN30=8, MIN5=48

Decision:
- Lightweight multi-level step runtime verification is accepted.
- Multi-level Copy Step proves frames.length > 0 and native_step_frames=true.
- Returned frames are truncated for safety: local frame 1/24 starts at native cursor 16, not native cursor 0.
- This is acceptable for startup safety and current-frame rendering verification.
- This is not yet accepted as complete full-history strict replay over the entire selected range.

2026-06-10 active single-level strict route implementation:

Commits:
- Commit: bb5f9faeeea18bffdd12afd4f5d4b3d0d3790d70
  - File: lib/ui/pages/origin_replay_strict_page.dart
  - Change: added active single-level strict replay page. It renders backend step frames only in step mode, blocks when frames.length=0, and provides Copy Step diagnostics.
- Commit: 6de1a244db4c522796a300d06a02b85b7e5bffb5
  - File: lib/ui/pages/root_page.dart
  - Change: Replay route now imports and builds OriginReplayStrictPage instead of OriginReplayPageV2.

Decision:
- Active app route for single-level replay no longer uses `_sliceSnapshot(fullSnapshot, cursor)` as strict-step success path.
- Runtime verification is still required: user must open Replay, wait/load step, click Copy Step, and paste diagnostics.
- Legacy OriginReplayPageV2 remains in repository and should not be treated as accepted strict-step implementation.

Next user operation after task party finishes:
- Pull latest.
- Run flutter analyze.
- Run flutter run.
- For multi-level: default page can still be checked with Copy Step.
- For single-level: click left-bottom `复盘`, use the new Single-level strict replay page, click `Copy Step`, and paste diagnostics.
