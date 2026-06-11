# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this supervisor update: 07b83ab51ac681161a6baa3943284b1b6c3315da
Latest multi-level strict-step UI commit: 763d6219e7aaa5732f7d62aca1474c5a0c4b9303
Latest multi-level compile-fix commit: 62767e6d7134e2512901ef876514a61f39a8f1af
Latest single-level strict replay page commit: bb5f9faeeea18bffdd12afd4f5d4b3d0d3790d70
Latest replay route commit: 6de1a244db4c522796a300d06a02b85b7e5bffb5
Latest backend/data commit: 2643cb70e544940bed17701ba789529298a37ff1
Latest root default commit: 6a88fcbd67a67512775a6eed7e5541458c3c5724
Latest single-level runtime verification manual commit: pending

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

- Multi-level models, parser, source, independent page, and RootPage entry exist.
- App startup defaults to MultiLevelReplayPage.
- OriginReplayPageV2 is not built on startup; replay-page default data load is temporarily stopped.
- RootPage Replay toolbar entry routes to `OriginReplayStrictPage`, not legacy `OriginReplayPageV2`.
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
- MultiLevelReplayPage fails loudly when step mode returns frames.length=0 and does not render the final snapshot as a current step frame.
- MultiLevelReplayPage nullable Copy Step diagnostics compile after commit 62767e6d7134e2512901ef876514a61f39a8f1af.
- `OriginReplayStrictPage` uses backend returned frames only in step mode and shows blocked state when frames.length=0.
- `OriginReplayStrictPage` has one-click `Copy Step` diagnostics.
- Active single-level Copy Step runtime verification passed:
  - strict_step_blocked=false
  - frame_source=chan_step_frame
  - final_snapshot_rendered_as_step=false
  - frames.length=103
  - frame.number.local=84/103
  - frame.current_time=2026-05-15T00:00:00.000
  - current frame counts: K=84, FX=23, BI=7, SEG=1, ZS=1, BSP=1
  - final diagnostic counts: K=103, FX=28, BI=8, SEG=2, ZS=1, BSP=1

## Current blockers

- Multi-level lightweight step is verified, but full-history non-truncated or paged step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is not the active Replay route now, but should be deleted, renamed legacy, or refactored later if direct use is needed.
- Interval-nest rule engine is not implemented yet.

## Task organization policy: no toothpaste delivery

Task party must deliver work in dependent batches. Small commits are allowed, but acceptance is by batch, not by isolated small edits. A batch is not accepted unless its code path, UI path, diagnostics button, and user-verifiable copy output are all present.

### Batch A: Strict step replay closure

Goal: make strict step truthful on active single-level and multi-level pages.

Required tasks and status:
- A1. MultiLevelReplayPage must not show final snapshot as strict step when mode=step and frames.length=0. Done.
- A2. MultiLevelReplayPage must show blocked/failure state and Copy Step diagnostics when frames.length=0. Done.
- A3. MultiLevelReplayPage Copy Step must prove native_step_frames=true, frames.length>0, current frame cursor/time, current frame level counts, and whether frames are truncated. Accepted for lightweight default step path.
- A4. Active single-level Replay route must not use `_sliceSnapshot(fullSnapshot, cursor)` as strict-step fallback. Done by routing to `OriginReplayStrictPage`.
- A5. Active single-level Replay route must use chan.py step frames only in strict step mode. Runtime accepted by user Copy Step.
- A6. Active single-level Replay route must fail loudly if mode=step and frames.length=0. Implemented; empty-frame runtime test still optional.
- A7. Active single-level Replay route must add Copy Step diagnostics with source, frames.length, current frame index/time, and K/FX/BI/SEG/ZS/BSP counts. Done and runtime accepted.
- A8. Startup auto-load must remain safe. Lightweight startup path accepted.
- A9. If frames are truncated for safety, UI and diagnostics must clearly show native cursor range and that local frame 1 is not necessarily native cursor 0. Done for multi-level Copy Step.
- A10. Full-history or paged step replay must be planned before claiming complete strict replay over the entire selected range. Pending.

Acceptance:
- Multi-level lightweight strict step: accepted.
- Active single-level strict step: accepted.
- Active routes no longer use final snapshot slicing as strict-step success path.
- Batch A active-route strict step is accepted for lightweight/runtime paths.
- Full-history/paged step replay remains a separate planning item.

### Batch B: Multi-level relation navigation and targeting

Blocked only by the full-history/paged step replay planning item if full-range replay is required. Otherwise the next implementable batch is relation targeting on the accepted lightweight step path.

Required tasks:
- B1. Click/select DAILY K/BI/ZS/BSP and locate corresponding MIN30 range using native relations.
- B2. Click/select MIN30 K/BI/ZS/BSP and locate corresponding MIN5 range using native relations.
- B3. Relation lookup must respect current step frame when in step mode.
- B4. Add Copy Relation diagnostics: parent level/index/time, child level start/end/index/time, relation count, active frame.
- B5. No synthetic relation logic is allowed; use native chan.py parent-child relation data only.

### Batch C: Interval-nest signal engine MVP

Blocked until Batch B relation targeting is accepted.

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

## Next user operation

- Pull latest after this manual commit.
- Optional: run `flutter analyze` and `flutter run` once more.
- Next development batch should be either full-history/paged step planning or Batch B relation targeting.
