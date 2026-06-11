# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this supervisor update: d39d57353af3a3ae51bec11022e5c6193a46e8ff
Latest multi-level strict-step UI commit: 763d6219e7aaa5732f7d62aca1474c5a0c4b9303
Latest multi-level compile-fix commit: 62767e6d7134e2512901ef876514a61f39a8f1af
Latest single-level strict replay page commit: bb5f9faeeea18bffdd12afd4f5d4b3d0d3790d70
Latest replay route commit: 6de1a244db4c522796a300d06a02b85b7e5bffb5
Latest backend/data commit: 2643cb70e544940bed17701ba789529298a37ff1
Latest root default commit: 6a88fcbd67a67512775a6eed7e5541458c3c5724
Latest relation panel commit: 5e1266269edbe78637bd6f03661ede27401b0403
Latest relation locate type fix commit: 6f8fd5d9f07003c69215609c46d41ef87c59309a
Latest relation page wiring commit: a6f7d34463aeff1b753457ca6b4dff6577d888bf
Latest interval signal panel commit: ee21e713745e2219b3bdda9c46f03d3d21fd7d63
Latest interval signal page wiring commit: b1afcae8891837e1cd615be2d6d3803f2564739f
Latest layer status minimize support commit: 622d45043c6c28ee1b122ae5ba838b6ab55e624d
Latest layer status default-minimized wiring commit: 2cba9fc38e3ed7842036965665ef83e6ce8026f4
Latest analyzer cleanup commit: b9d0994286f4f070f771f34af11dd7ef593e1444
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
- MultiLevelReplayPage has `Copy P0`, `Copy Step`, `Copy Relation`, and `Copy Signal` diagnostics.
- MultiLevelReplayPage fails loudly when step frames are empty.
- Multi-level layer status no longer covers action buttons on initial load; it is minimized by default and restored by the bottom-right `图层状态` button.
- `OriginReplayStrictPage` uses backend returned frames only in step mode and has one-click `Copy Step` diagnostics.
- Batch B relation targeting implementation has been supervisor-verified in code and runtime-accepted by Copy Relation diagnostics.

## Current blockers

- Multi-level lightweight step is verified, but full-history non-truncated or paged step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is not the active Replay route now, but should be deleted, renamed legacy, or refactored later if direct use is needed.
- Batch C signal MVP is implemented in code but not runtime-verified by Copy Signal yet.

## Batch A: Strict step replay closure

Status:
- Multi-level lightweight strict step: accepted.
- Active single-level strict step: accepted.
- Active routes no longer use final snapshot slicing as strict-step success path.
- Full-history/paged step replay remains a separate planning item.

## Batch B: Multi-level relation navigation and targeting

Status: accepted for runtime on the lightweight multi-level step path.

Implementation status:
- DAILY to MIN30 relation targeting implemented and runtime accepted.
- MIN30 to MIN5 relation targeting implemented and runtime accepted.
- Relation lookup is current-frame-aware because the panel receives `_current` snapshot in step mode, not final snapshot.
- `Copy Relation` diagnostics accepted.
- No synthetic relation logic: panel uses `MultiLevelChanSnapshot.relations` and `LevelRelation` only.

## Batch C: Interval-nest signal engine MVP

Status: implemented in code; runtime Copy Signal verification pending.

Implemented scope:
- Added `MultiLevelIntervalSignalPanel`.
- Wired `MultiLevelIntervalSignalPanel` into `MultiLevelReplayPage` after Relation targeting.
- The panel receives current-frame `MultiLevelChanSnapshot` in step mode, not the final snapshot.
- The MVP scans current-frame DAILY->MIN30 only.
- Signal sources are original chan.py BSP points from the high and low levels plus native `LevelRelation` ranges.
- Implemented initial signal pairs:
  - DAILY 2-buy + MIN30 1-buy
  - DAILY 3-buy + MIN30 1-buy
  - DAILY 3-buy + MIN30 2-buy
- Added signal state as candidate/confirmed based on BSP confirmation flags.
- Added visibleAt/confirmedAt frame fields.
- Added `Copy Signal` diagnostics.
- No synthetic Chan structures are allowed or added.

Implementation commits:
- `ee21e713745e2219b3bdda9c46f03d3d21fd7d63`: added `lib/ui/widgets/multi_level_interval_signal_panel.dart`.
- `b1afcae8891837e1cd615be2d6d3803f2564739f`: wired the signal panel into `MultiLevelReplayPage`.

UI obstruction fix:
- `622d45043c6c28ee1b122ae5ba838b6ab55e624d`: added optional minimize action to `MultiLevelLayerStatusPanel`.
- `2cba9fc38e3ed7842036965665ef83e6ce8026f4`: changed `MultiLevelReplayPage` so layer status is minimized by default and restored by the bottom-right `图层状态` button.
- `b9d0994286f4f070f771f34af11dd7ef593e1444`: cleared strict replay final-field analyzer hints.

Copy Signal expected fields:
- `signal_source: original chan.py BSP + native LevelRelation`
- `signal_scope: DAILY/MIN30 MVP`
- `available_signals`
- `direction`
- `state`
- `high_level`, `high_pattern`, `high_bsp_index`, `high_bsp_type`, `high_raw_index`, `high_time`
- `low_level`, `low_trigger`, `low_bsp_index`, `low_bsp_type`, `low_raw_index`, `low_time`
- `parent_relation_range`
- `child_relation_range`
- `visibleAt.frame`
- `confirmedAt.frame`
- `future_function_policy`
- `status`

Batch C acceptance rule:
- Batch C is not accepted until the user pastes Copy Signal diagnostics.
- Copy Signal must show source BSP ids/indices, parent relation range, child relation range, visibleAt/confirmedAt, and candidate/confirmed/invalidated state.
- No synthetic Chan structures are allowed.

## Next user operation

- Pull latest.
- Run `flutter analyze` and `flutter run`.
- Confirm the layer status starts minimized as the bottom-right `图层状态` button.
- Click `图层状态` to restore the floating window, then click the minus icon to minimize again.
- Wait for Multi-level default step load.
- Use the Interval signal MVP panel.
- Click `Copy Signal`.
- Paste Copy Signal diagnostics for at least one DAILY/MIN30 signal.
