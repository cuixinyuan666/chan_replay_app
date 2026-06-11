# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this supervisor update: e608ccfd0ef0efc641ef21e228d1ec8f0557f60b
Latest multi-level strict-step UI commit: 763d6219e7aaa5732f7d62aca1474c5a0c4b9303
Latest multi-level compile-fix commit: 62767e6d7134e2512901ef876514a61f39a8f1af
Latest single-level strict replay page commit: bb5f9faeeea18bffdd12afd4f5d4b3d0d3790d70
Latest replay route commit: 6de1a244db4c522796a300d06a02b85b7e5bffb5
Latest backend/data commit: 2643cb70e544940bed17701ba789529298a37ff1
Latest root default commit: 6a88fcbd67a67512775a6eed7e5541458c3c5724
Latest relation panel commit: 5e1266269edbe78637bd6f03661ede27401b0403
Latest relation locate type fix commit: 6f8fd5d9f07003c69215609c46d41ef87c59309a
Latest relation page wiring commit: a6f7d34463aeff1b753457ca6b4dff6577d888bf
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

## Current accepted work

- Batch A active-route strict step is accepted for lightweight/runtime paths.
- Multi-level lightweight strict step is accepted.
- Active single-level strict step is accepted.
- App startup defaults to MultiLevelReplayPage.
- RootPage Replay toolbar entry routes to `OriginReplayStrictPage`, not legacy `OriginReplayPageV2`.
- Native multi-level step frames are implemented through original chan.py `CChan(lv_list).step_load()` outputs.
- MultiLevelReplayPage has `Copy P0`, `Copy Step`, and now `Copy Relation` diagnostics.
- MultiLevelReplayPage fails loudly when step frames are empty.
- `OriginReplayStrictPage` uses backend returned frames only in step mode and has one-click `Copy Step` diagnostics.

## Current blockers

- Multi-level lightweight step is verified, but full-history non-truncated or paged step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is not the active Replay route now, but should be deleted, renamed legacy, or refactored later if direct use is needed.
- Batch B relation targeting is implemented in code but not runtime-verified by Copy Relation yet.
- Interval-nest rule engine is not implemented yet.

## Batch A: Strict step replay closure

Status:
- Multi-level lightweight strict step: accepted.
- Active single-level strict step: accepted.
- Active routes no longer use final snapshot slicing as strict-step success path.
- Full-history/paged step replay remains a separate planning item.

## Batch B: Multi-level relation navigation and targeting

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

Runtime verification required:
- User must open Multi-level page after default step load.
- Use Relation targeting panel.
- Select pair `DAILY->MIN30` and click `Copy Relation`.
- Select pair `MIN30->MIN5` and click `Copy Relation`.
- Paste both diagnostics.

Expected Copy Relation fields:
- `relation_source: native chan_parent_child LevelRelation`
- `level_relation_mode: chan_parent_child`
- `native_cchan_lv_list: true`
- `pair: DAILY->MIN30` or `pair: MIN30->MIN5`
- `parent_structure: K|BI|SEG|ZS|BSP`
- `available_targets: >0`
- `parent_raw_range`
- `child_raw_range`
- `relation_count_for_target: >0`
- `snapshot.relations.length: >0`
- `status: ok`

Acceptance:
- Batch B is not accepted until Copy Relation diagnostics are pasted and show native relation source, valid parent range, valid child range, and non-zero relation count.

## Batch C: Interval-nest signal engine MVP

Blocked until Batch B relation targeting is accepted.

Required tasks:
- Use original chan.py BSP outputs only.
- Use native relation ranges to bind high-level and low-level signals.
- Add signal state: candidate / confirmed / invalidated.
- Add visibleAt / confirmedAt / rawIndex timing markers to avoid future-function ambiguity.
- Add Copy Signal diagnostics.

## Next user operation

- Pull latest.
- Run `flutter analyze` and `flutter run`.
- Wait for Multi-level default step load.
- In the Relation targeting panel, click `Copy Relation` for `DAILY->MIN30`.
- Change pair to `MIN30->MIN5`, click `Copy Relation` again.
- Paste both outputs.
