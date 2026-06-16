# hichanjzx rhythm step display fix

## Problem

In S13 step replay, `S13SingleStockReplayPage._displaySnapshot` can rewrap the active `ChanSnapshot` when BSP candidate trail is enabled. The rewrapped snapshot keeps bars, Chan structures and BSP trail, but the original rhythm overlays are not passed through. As a result, rhythm lines can disappear while stepping even though the backend frame contains `rhythm_lines` and `rhythm_hits`.

## Fix

`ChanSnapshot` now keeps a lightweight Expando cache keyed by the shared `rawBars` list object. When the JSON parser creates the original backend snapshot with non-empty `rhythmLines` / `rhythmHits`, the model caches those overlays. When UI code later rewraps the same `rawBars` list without explicitly passing rhythm overlays, the constructor restores them from the cache.

This avoids changing the large S13 page and keeps the fix local to the model boundary where the data loss occurs.

## Left-edge connector

The backend rhythm overlay now appends `rhythm_left_connector` rows into `rhythm_lines`. Each connector is a vertical line at the shared `x1` of rhythm lines that begin at the same time position. Existing Dart `DrawingObject` rendering consumes them as locked trend lines, so no additional drawing-path wiring is needed.

## Validation

- `tools/validate_s14_1382_rhythm_replay_integration.py` now checks the connector output and the snapshot cache contract.
- `test/validate_chan_snapshot_rhythm_cache.dart` documents the rewrap behavior: rewrapped snapshots with the same `rawBars` retain rhythm overlays.
