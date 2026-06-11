# task checklist and contact

Branch: origin_vespa_tdx

## Hard rules

- Original `python/chan.py` remains the only Chan calculation engine.
- Flutter/Dart must not recreate Chan FX/BI/SEG/ZS/BSP logic.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Bridge fallback is not accepted as a completed native result.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- If diagnostics are needed, expose an in-app copy button.
- Normal Windows user workflow uses App-managed bundled Python.

## Latest important commits

- `dd1f52b9e55ee45f6066bd41ef448972c5625c0b`: added `Scan Signal` workflow and guarded large step counts.
- `63e54230189d97b2c247d185d95c105d935ec462`: extended once-mode timeout for larger count scans.
- `8a1ddfa2c56741738752d14d6e631552eb912e91`: restored `_PythonMultiLevelBackendMismatch` and fixed analyzer/build errors.
- `93aaa753b1e391132439e88167677ddd7cc6fd65`: removed the nonexistent `python/a_server.py` fallback.
- `c30e8fba5aaf7cf54931d13e03b3bac3bbba461d`: recorded the first positive Scan Signal candidate.
- `c79e30337a302e38e4e5825d8e0ffbe77ee85549`: removed an obsolete diagnostic stub that checked old backend paths.

## Current verified code status

- `lib/data/python_multi_level_chan_analysis_source.dart` imports `app_bundled_python_backend.dart`.
- On Windows, multi-level analysis uses `AppBundledPythonBackend.start(requireAnalyzeMulti: true)`.
- The app-managed backend starts `python/app_engine.py` using the bundled `python/python.exe` located beside it.
- `python/app_engine.py` starts `backend/app/main.py` through uvicorn for HTTP mode.
- `backend/app/main.py` exposes `/health`, `/`, and `/api/chan/analyze_multi`.
- Backend diagnostics are merged into analysis meta after a successful response: `backend_runtime`, `backend_url`, and `python_runtime`.

## Current accepted work

- Batch A active-route strict step is accepted for lightweight/runtime paths.
- Single-level active replay route uses `OriginReplayStrictPage` and backend step frames.
- Multi-level lightweight step replay is accepted.
- Batch B relation targeting is accepted for DAILY->MIN30 and MIN30->MIN5 using native `LevelRelation` data.
- Multi-level page has `Copy P0`, `Copy Step`, `Copy Relation`, and `Copy Signal` diagnostics.
- Layer status, relation panel, and interval panel no longer cover chart/action buttons by default.
- Duplicate `Copy Step` button was removed from the step control bar.
- Large-count signal discovery uses `Scan Signal` with once-mode snapshot, not large step replay.
- App-bundled Python implementation exists in latest code and should be runtime-verified, not reimplemented.

## Current blockers / pending verification

- Run `flutter analyze` on latest branch after bundled-Python changes.
- Runtime-verify that fresh Windows app start can run Multi-level `Load` without manually starting external Python.
- Runtime-verify that `Copy P0` includes or proves `python_runtime: app_bundled` through backend meta.
- Batch C strict-step verification is still pending for the discovered scan candidate.
- Full-history/paged strict step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is no longer the active route.

## Batch C current state

Problem observed:

- Increasing `step` replay count to 600 caused `step_load` timeout.
- Root cause: step replay returns many frame snapshots and is not suitable for large-range candidate search.

Implemented solution:

- Keep replay in `step` mode with a small count such as 40 or 80.
- To search a larger range, enter a larger count such as 600 and click `Scan Signal`.
- `Scan Signal` uses `analyze_multi` with `mode=once`, so it does not return hundreds of step frames.
- The chart can keep displaying the lightweight replay while the interval panel scans the larger once snapshot.

Positive candidate found:

- mode: `signal_scan_once`
- symbol: `600340`
- available_signals: `1`
- direction: `buy`
- state: `confirmed`
- high_level: `DAILY`
- high_pattern: `2-buy`
- high_bsp_index: `4`
- high_bsp_type: `B2s`
- high_raw_index: `239`
- high_time: `2025-10-13 23:59:00.000`
- low_level: `MIN30`
- low_trigger: `1-buy`
- low_bsp_index: `16`
- low_bsp_type: `B1`
- low_raw_index: `1912`
- low_time: `2025-10-13 10:00:00.000`
- parent_relation_range: `239-239`
- child_relation_range: `1912-1919`
- child_union_range: `1912-1919`
- relation_count_for_parent: `1`
- status: `ok`

Interpretation:

- Candidate discovery works over a once-mode scan snapshot.
- Source BSP fields and native relation range are present.
- It is not yet strict-step accepted because `visibleAt.frame` and `confirmedAt.frame` are blank in scan mode.

## Next task-party operation

1. Run `flutter analyze` on latest branch.
2. Run the app fresh without starting any external Python manually.
3. In multi-level page, `mode=step`, `count=40`, click `Load`.
4. Click `Copy P0` and verify backend meta proves `python_runtime: app_bundled` or equivalent.
5. Use `Scan Signal(600)` only for candidate search.
6. Continue Batch C by mapping the found scan candidate back to strict-step frame verification.
