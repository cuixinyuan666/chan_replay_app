# task checklist and contact

Branch: origin_vespa_tdx

This file is the project manual for the multi-level and interval-nest work.

## Current review baseline

Latest observed head before this supervisor update: 4bbd955ab3d9c9f833b26d8d75b7bf6fb58983b1
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
Latest no-signal diagnostic enhancement commit: 1653fd995e3ffe9c8a2d0e6f067463e29713a025
Latest duplicate Copy Step cleanup commit: 6ebe90c626d673122dab45f3db41a833eca45f8e
Latest collapsed tool panels commit: 0bceb90f210dec4e62faf4b7ed7952a46f12fd34
Latest once-scan timeout policy commit: 63e54230189d97b2c247d185d95c105d935ec462
Latest Scan Signal UI commit: dd1f52b9e55ee45f6066bd41ef448972c5625c0b
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
- Relation targeting and Interval signal panels no longer consume chart height by default; they are collapsed behind the `工具面板` strip and can be expanded only when needed.
- The duplicate Copy Step button in the step-control bar was removed; Copy Step remains in the diagnostics/P0 bar.
- Step replay now guards against count values above 120 to prevent large step_load timeout; users should use Scan Signal for large-count signal searches.
- `OriginReplayStrictPage` uses backend returned frames only in step mode and has one-click `Copy Step` diagnostics.
- Batch B relation targeting implementation has been supervisor-verified in code and runtime-accepted by Copy Relation diagnostics.

## Current blockers

- Multi-level lightweight step is verified, but full-history non-truncated or paged step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is not the active Replay route now, but should be deleted, renamed legacy, or refactored later if direct use is needed.
- Batch C signal MVP is implemented in code but not runtime-accepted yet because copied current frames have no DAILY/MIN30 MVP signal.

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

Status: implemented in code; runtime Copy Signal acceptance pending.

Implemented scope:
- Added `MultiLevelIntervalSignalPanel`.
- Wired `MultiLevelIntervalSignalPanel` into `MultiLevelReplayPage`.
- The panel receives current-frame `MultiLevelChanSnapshot` in step mode, not the final snapshot.
- The MVP scans current-frame DAILY->MIN30 only for strict step verification.
- Signal sources are original chan.py BSP points from the high and low levels plus native `LevelRelation` ranges.
- Implemented initial signal pairs:
  - DAILY 2-buy + MIN30 1-buy
  - DAILY 3-buy + MIN30 1-buy
  - DAILY 3-buy + MIN30 2-buy
- Added signal state as candidate/confirmed based on BSP confirmation flags.
- Added visibleAt/confirmedAt frame fields.
- Added `Copy Signal` diagnostics.
- Enhanced no-signal Copy Signal diagnostics to include high/low BSP counts, type-specific buy counts, native relation count, and future-function policy.
- Added `Scan Signal` workflow for large-count candidate discovery.
- No synthetic Chan structures are allowed or added.

Implementation commits:
- `ee21e713745e2219b3bdda9c46f03d3d21fd7d63`: added `lib/ui/widgets/multi_level_interval_signal_panel.dart`.
- `b1afcae8891837e1cd615be2d6d3803f2564739f`: wired the signal panel into `MultiLevelReplayPage`.
- `1653fd995e3ffe9c8a2d0e6f067463e29713a025`: enriched no-signal Copy Signal diagnostics.
- `63e54230189d97b2c247d185d95c105d935ec462`: extended once-mode timeout for larger count scans.
- `dd1f52b9e55ee45f6066bd41ef448972c5625c0b`: added `Scan Signal` action and large-count step guard.

UI obstruction and duplication fixes:
- `622d45043c6c28ee1b122ae5ba838b6ab55e624d`: added optional minimize action to `MultiLevelLayerStatusPanel`.
- `2cba9fc38e3ed7842036965665ef83e6ce8026f4`: changed `MultiLevelReplayPage` so layer status is minimized by default and restored by the bottom-right `图层状态` button.
- `b9d0994286f4f070f771f34af11dd7ef593e1444`: cleared strict replay final-field analyzer hints.
- `6ebe90c626d673122dab45f3db41a833eca45f8e`: removed duplicate Copy Step button from the step-control bar.
- `0bceb90f210dec4e62faf4b7ed7952a46f12fd34`: collapsed Relation targeting and Interval signal panels by default so the K-line chart retains vertical space.

Large-count signal-search solution:
- Do not increase step replay count to 600.
- Step replay is for visual replay and remains lightweight.
- `Scan Signal` uses analyze_multi `mode=once` with the entered count, so it does not return hundreds of step frames.
- The chart can continue showing the lightweight step frame while the interval signal panel scans the larger once snapshot.
- Scan results are candidate discovery only. A selected signal still needs strict step verification before final Batch C acceptance.
- A diagnostic wording update attempt for `signal_scan_once` was blocked by platform safety checks; the functional scan path still exists.

User Copy Signal results:
- First copied frame showed `available_signals: 0` for symbol 600340 at frame 0/24.
- Second copied frame showed symbol 000001 at frame 23/24:
  - signal_source: original chan.py BSP + native LevelRelation
  - signal_scope: DAILY/MIN30 MVP
  - available_signals: 0
  - high_level: DAILY
  - low_level: MIN30
  - high_bsp_count: 0
  - high_buy_type2_count: 0
  - high_buy_type3_count: 0
  - low_bsp_count: 15
  - low_buy_type1_count: 2
  - low_buy_type2_count: 3
  - native_relation_count: 100
  - future_function_policy: current frame only; no final snapshot signal confirmation
  - status: no signal for DAILY/MIN30 MVP scope

Interpretation:
- For the second copied frame, MIN30 has BSP and native relations, but DAILY has no BSP in the current frame.
- Therefore the current frame cannot produce DAILY/MIN30 MVP interval-nest signals under the defined rules.
- Batch C is still not accepted because no actual signal instance has been copied yet.

Copy Signal expected fields for an accepted signal:
- `signal_source: original chan.py BSP + native LevelRelation`
- `signal_scope: DAILY/MIN30 MVP`
- `available_signals: >0`
- `direction`
- `state`
- `high_level`, `high_pattern`, `high_bsp_index`, `high_bsp_type`, `high_raw_index`, `high_time`
- `low_level`, `low_trigger`, `low_bsp_index`, `low_bsp_type`, `low_raw_index`, `low_time`
- `parent_relation_range`
- `child_relation_range`
- `visibleAt.frame`
- `confirmedAt.frame`
- `future_function_policy`
- `status: ok`

Batch C acceptance rule:
- Batch C is not accepted until the user pastes Copy Signal diagnostics with at least one actual signal.
- Copy Signal for an actual signal must show source BSP ids/indices, parent relation range, child relation range, visibleAt/confirmedAt, and candidate/confirmed/invalidated state.
- No synthetic Chan structures are allowed.

## Next user operation

- Pull latest.
- Run `flutter analyze` and `flutter run`.
- Keep mode as step and count around 40 for replay.
- To scan larger history, enter count 600 and click `Scan Signal` instead of `Load`.
- After scan finishes, click `区间信号`, then `Copy Signal`.
- Paste Copy Signal diagnostics with `available_signals > 0` if one is found.
