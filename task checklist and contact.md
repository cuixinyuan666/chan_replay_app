# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this supervisor update: 81733997a3d975e194642bcc3b1412b7062adbd8
Latest multi-level strict-step UI commit: 763d6219e7aaa5732f7d62aca1474c5a0c4b9303
Latest multi-level compile-fix commit: 62767e6d7134e2512901ef876514a61f39a8f1af
Latest single-level strict replay page commit: bb5f9faeeea18bffdd12afd4f5d4b3d0d3790d70
Latest replay route commit: 6de1a244db4c522796a300d06a02b85b7e5bffb5
Latest backend/data commit: 2643cb70e544940bed17701ba789529298a37ff1
Latest root default commit: 6a88fcbd67a67512775a6eed7e5541458c3c5724
Latest relation panel commit: 5e1266269edbe78637bd6f03661ede27401b0403
Latest relation locate type fix commit: 6f8fd5d9f07003c69215609c46d41ef87c59309a
Latest relation page wiring commit: a6f7d34463aeff1b753457ca6b4dff6577d888bf
Latest manual update commit: Batch B accepted; marker finalized in this commit

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

## Current accepted work

- Batch A active-route strict step is accepted for lightweight/runtime paths.
- Multi-level lightweight strict step is accepted.
- Active single-level strict step is accepted.
- App startup defaults to MultiLevelReplayPage.
- RootPage Replay toolbar entry routes to `OriginReplayStrictPage`, not legacy `OriginReplayPageV2`.
- Native multi-level step frames are implemented through original chan.py `CChan(lv_list).step_load()` outputs.
- MultiLevelReplayPage has `Copy P0`, `Copy Step`, and `Copy Relation` diagnostics.
- MultiLevelReplayPage fails loudly when step frames are empty.
- `OriginReplayStrictPage` uses backend returned frames only in step mode and has one-click `Copy Step` diagnostics.
- Batch B relation targeting implementation has been supervisor-verified in code and runtime-accepted by Copy Relation diagnostics.

## Current blockers

- Multi-level lightweight step is verified, but full-history non-truncated or paged step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is not the active Replay route now, but should be deleted, renamed legacy, or refactored later if direct use is needed.
- Interval-nest rule engine is not implemented yet.

## Batch A: Strict step replay closure

Status:
- Multi-level lightweight strict step: accepted.
- Active single-level strict step: accepted.
- Active routes no longer use final snapshot slicing as strict-step success path.
- Full-history/paged step replay remains a separate planning item.

## Batch B: Multi-level relation navigation and targeting

Status: accepted for runtime on the lightweight multi-level step path.

Goal: turn native chan_parent_child relations into usable chart navigation.

Implementation status:
- B1. DAILY to MIN30 relation targeting implemented in code through `MultiLevelRelationPanel`.
- B2. MIN30 to MIN5 relation targeting implemented in code through `MultiLevelRelationPanel`.
- B3. Relation lookup is current-frame-aware because the panel receives `_current` snapshot in step mode, not final snapshot.
- B4. `Copy Relation` diagnostics implemented.
- B5. No synthetic relation logic: panel uses `MultiLevelChanSnapshot.relations` and `LevelRelation` only.

Implementation commits:
- `5e1266269edbe78637bd6f03661ede27401b0403`: added `lib/ui/widgets/multi_level_relation_panel.dart`.
- `6f8fd5d9f07003c69215609c46d41ef87c59309a`: exposed `RelationLocateRequest` for page wiring.
- `a6f7d34463aeff1b753457ca6b4dff6577d888bf`: wired relation panel into `MultiLevelReplayPage`.

Supervisor code verification:
- Verified `MultiLevelRelationPanel` exists and displays pair selection, structure selection, native relation source, target count, parent range, child range, Locate Parent, Locate Child, and `Copy Relation`.
- Verified target construction uses `widget.snapshot.relationsForParentRange(...)`, which filters existing `LevelRelation` data by parentLevel, childLevel, and parent raw-index range.
- Verified `MultiLevelReplayPage` imports and renders `MultiLevelRelationPanel` only when the current snapshot exists and current snapshot relations are non-empty.
- Verified `MultiLevelReplayPage` passes `snapshot: current`, so relation targeting is frame-aware in step mode when frames are present.
- Verified `Copy Relation` includes relation_source, level_relation_mode, native_cchan_lv_list, pair, parent_structure, available_targets, parent_raw_range, child_raw_range, relation_count_for_target, snapshot.relations.length, and status.

Runtime verification accepted:
- `DAILY->MIN30` Copy Relation:
  - relation_source: native chan_parent_child LevelRelation
  - level_relation_mode: chan_parent_child
  - native_cchan_lv_list: true
  - parent_structure: K
  - available_targets: 17
  - parent_raw_range: 0-0
  - child_raw_range: 0-7
  - relation_count_for_target: 1
  - snapshot.relations.length: 153
  - status: ok
- `MIN30->MIN5` Copy Relation:
  - relation_source: native chan_parent_child LevelRelation
  - level_relation_mode: chan_parent_child
  - native_cchan_lv_list: true
  - parent_structure: K
  - available_targets: 136
  - parent_raw_range: 0-0
  - child_raw_range: 0-5
  - relation_count_for_target: 1
  - snapshot.relations.length: 153
  - status: ok

Acceptance:
- Batch B relation targeting is accepted for the tested current lightweight step frame.
- The acceptance proves native relation lookup is usable for DAILY->MIN30 and MIN30->MIN5 on current-frame data.
- Full-history/paged step replay remains a separate planning item and is not implied by this acceptance.

## Batch C: Interval-nest signal engine MVP

Status: unlocked. Next implementable batch.

Required tasks:
- Use original chan.py BSP outputs only.
- Use native relation ranges to bind high-level and low-level signals.
- Add signal state: candidate / confirmed / invalidated.
- Add visibleAt / confirmedAt / rawIndex timing markers to avoid future-function ambiguity.
- Add Copy Signal diagnostics.

Initial signal scope:
- DAILY 2-buy + MIN30 1-buy.
- DAILY 3-buy + MIN30 1-buy.
- DAILY 3-buy + MIN30 2-buy.
- Optional MIN30 to MIN5 trigger only after the DAILY/MIN30 signal path is verifiable.

Batch C acceptance rule:
- No signal is accepted without Copy Signal diagnostics.
- Copy Signal must show source BSP ids/indices, parent relation range, child relation range, visibleAt/confirmedAt, and whether the signal is candidate/confirmed/invalidated.
- No synthetic Chan structures are allowed.

## Next user operation

- Wait for task party to implement Batch C.
- After implementation, use the future `Copy Signal` button.
- Paste Copy Signal diagnostics for at least one DAILY/MIN30 signal.
