# task checklist and contact

Branch: origin_vespa_tdx

## Hard rules

- Original `python/chan.py` remains the only Chan calculation engine.
- Flutter/Dart must not recreate Chan FX/BI/SEG/ZS/BSP logic.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Bridge fallback is not accepted as a completed native result.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- If diagnostics are needed, expose an in-app copy button.

## Current accepted work

- Batch A strict step replay is accepted for the lightweight/runtime path.
- Single-level active replay route uses `OriginReplayStrictPage` and backend step frames.
- Multi-level lightweight step replay is accepted.
- Batch B relation targeting is accepted for DAILY->MIN30 and MIN30->MIN5 using native `LevelRelation` data.
- Multi-level page has `Copy P0`, `Copy Step`, `Copy Relation`, and `Copy Signal` diagnostics.
- Layer status, relation panel, and interval panel no longer cover chart/action buttons by default.
- Duplicate `Copy Step` button was removed from the step control bar.
- Missing `python/a_server.py` auto-start fallback was removed. The app now uses only the backend URL entered in the UI.

## Current latest commits

- `dd1f52b9e55ee45f6066bd41ef448972c5625c0b`: added `Scan Signal` workflow and guarded large step counts.
- `63e54230189d97b2c247d185d95c105d935ec462`: extended once-mode timeout for larger count scans.
- `8a1ddfa2c56741738752d14d6e631552eb912e91`: restored `_PythonMultiLevelBackendMismatch` and fixed analyzer/build errors.
- `93aaa753b1e391132439e88167677ddd7cc6fd65`: removed the nonexistent `python/a_server.py` auto-start fallback.

## Current blockers

- Full-history/paged strict step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is no longer the active route.
- Batch C interval candidate MVP is implemented but not accepted until `Copy Signal` returns an actual candidate result or enough diagnostics prove the selected window has no matching high-level BSP inputs.
- The user must run a real chan.py backend exposing `/api/chan/analyze_multi` at the backend URL shown in the UI.

## Batch C current workflow

Problem observed:

- Increasing `step` replay count to 600 caused `step_load` timeout.
- Root cause: step replay returns many frame snapshots and is not suitable for large-range candidate search.

Solution implemented:

- Keep replay in `step` mode with a small count such as 40 or 80.
- To search a larger range, enter a larger count such as 600 and click `Scan Signal`.
- `Scan Signal` uses `analyze_multi` with `mode=once`, so it does not return hundreds of step frames.
- The chart can keep displaying the lightweight replay while the interval panel scans the larger once snapshot.

Backend requirement:

- The app no longer attempts to start `python/a_server.py` because that file is not in this repository.
- Start the correct backend yourself and set the UI backend field to its URL, usually `http://127.0.0.1:8000`.
- The backend must expose `/api/chan/analyze_multi`.

Acceptance rule:

- `Copy Signal` must show source BSP indices, parent/child relation range, visible/confirmed timing fields, and `status: ok` for an actual candidate.
- If `available_signals: 0`, the diagnostics must show high/low BSP counts and native relation count.

## Next user operation

1. `git pull`
2. `flutter analyze`
3. Start the correct chan.py backend exposing `/api/chan/analyze_multi`.
4. `flutter run`
5. Keep `mode=step`, set `count` around 40, and click `Load` for chart replay.
6. To search larger history, set `count=600` and click `Scan Signal`, not `Load`.
7. After scanning, click `区间信号`, then click `Copy Signal`.
8. Paste the copied diagnostics.
