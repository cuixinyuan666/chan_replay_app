# task checklist and contact

Branch: origin_vespa_tdx

## Hard rules

- Original `python/chan.py` remains the only Chan calculation engine.
- Flutter/Dart must not recreate Chan FX/BI/SEG/ZS/BSP logic.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Bridge fallback is not accepted as a completed native result.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- If diagnostics are needed, expose an in-app copy button.
- App workflows must always use the App-bundled Python runtime / App-managed backend process.
- Do not require the user to start system Python, Conda Python, Windows Store Python, Termux Python, or any other external interpreter.
- Do not call `Process.start('python', ...)`, shell `python`, `python3`, or a hard-coded external interpreter for normal app workflows.
- The backend URL field may remain for diagnostics/development, but user-facing accepted workflow must start and use the App-bundled Python backend automatically.
- If the App-bundled Python backend is missing or cannot expose `/api/chan/analyze_multi`, the task is blocked, not accepted.

## Current accepted work

- Batch A active-route strict step is accepted for lightweight/runtime paths.
- Single-level active replay route uses `OriginReplayStrictPage` and backend step frames.
- Multi-level lightweight step replay is accepted.
- Batch B relation targeting is accepted for DAILY->MIN30 and MIN30->MIN5 using native `LevelRelation` data.
- Multi-level page has `Copy P0`, `Copy Step`, `Copy Relation`, and `Copy Signal` diagnostics.
- Layer status, relation panel, and interval panel no longer cover chart/action buttons by default.
- Duplicate `Copy Step` button was removed from the step control bar.
- Missing `python/a_server.py` auto-start fallback was removed. This removal is code-correct because that file does not exist, but it is not sufficient for accepted user workflow because the app must use bundled Python.

## Current latest commits verified or reviewed

- `dd1f52b9e55ee45f6066bd41ef448972c5625c0b`: added `Scan Signal` workflow and guarded large step counts.
- `63e54230189d97b2c247d185d95c105d935ec462`: extended once-mode timeout for larger count scans.
- `8a1ddfa2c56741738752d14d6e631552eb912e91`: restored `_PythonMultiLevelBackendMismatch` and fixed analyzer/build errors.
- `93aaa753b1e391132439e88167677ddd7cc6fd65`: removed the nonexistent `python/a_server.py` auto-start fallback.
- `32b993249dc7f58e22ba53080c8ad2717e5e5c89`: manual-only commit that recorded the fallback removal.
- `b2ce5a7073a885496cc0722b8e5fcc31a2c432c0`: added `AppBackendRuntime` backend runtime diagnostic foundation.

## Supervisor verification of latest task-party changes

Verified true:

- `Scan Signal` exists in MultiLevelReplayPage and uses `analyze_multi` with `mode=once` for larger count signal scanning.
- Step replay refuses very large `count` values and tells the user to use `Scan Signal` instead of large step replay.
- The interval panel can use the separate once-mode scan snapshot while the chart keeps displaying the lightweight step replay snapshot.
- `Copy Signal` exists and includes positive-signal diagnostics plus no-signal diagnostics.
- The removed `python/a_server.py` fallback no longer attempts to call `Process.start('python', ...)` from `PythonMultiLevelChanAnalysisSource`.
- `AppBackendRuntime` now exists and can produce backend runtime diagnostic text without invoking external Python.

Verified problem:

- Current multi-level source now posts only to the backend URL typed in the UI.
- On connection failure it tells the user to start a backend service manually.
- That is not accepted under the hard rule: normal app workflow must use App-bundled Python / App-managed backend, not an external manually started interpreter.
- `AppBackendRuntime` is not wired into UI yet, so P0.5 is started but not complete.
- Copy Signal scan-mode wording still says current-frame policy in the output; this is a diagnostic wording bug, not a Chan calculation issue.

## Current blockers

- App-bundled Python backend is now a P0 blocker: accepted workflow must not require manually starting an external backend.
- Full-history/paged strict step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is no longer the active route.
- Batch C interval scan candidate discovery has one positive candidate, but formal acceptance is blocked until P0 App-bundled Python runtime closure and strict-step verification.

## P0: App-bundled Python runtime closure

Goal: all user-facing workflows use the Python runtime bundled with the app, with no external interpreter requirement.

Required tasks:

- P0.1 Add or wire an App-managed backend launcher that starts the bundled Python runtime and the correct origin_vespa_tdx backend server.
- P0.2 The launcher must expose `/api/chan/analyze_multi` and any other active API endpoints used by single-level replay, multi-level replay, Scan Signal, Copy Step, Copy Relation, and Copy Signal.
- P0.3 Remove user instructions that say to manually start a backend with system Python.
- P0.4 If the bundled backend cannot start, show an in-app blocked/failure state with a one-click copy diagnostic.
- P0.5 Add a backend runtime diagnostic copy action showing backend URL, process source, Python runtime path/type, backend health, and whether it is App-bundled.
- P0.6 Normal workflow must not call `python`, `python3`, Conda, Windows Store Python, or Termux Python directly.
- P0.7 Development-only external backend override must be clearly labelled as development/debug only and cannot be the accepted default workflow.

P0 progress:

- Added `lib/data/app_backend_runtime.dart`.
- The diagnostic class checks candidate app-bundled backend paths and reports a blocked state when none exist.
- It does not call system Python, Conda Python, Windows Store Python, or shell `python`.
- Next implementation step: wire this diagnostic into MultiLevelReplayPage as `Copy Backend`.

Acceptance:

- Fresh app start can run Multi-level Load and Scan Signal without the user starting any external Python interpreter.
- Copy backend/runtime diagnostics show `python_runtime: app_bundled` or equivalent.
- Diagnostics show `/api/chan/analyze_multi` is served by the App-managed backend.
- No normal user instructions require command-line backend startup.

## Batch C current workflow

Problem observed:

- Increasing `step` replay count to 600 caused `step_load` timeout.
- Root cause: step replay returns many frame snapshots and is not suitable for large-range candidate search.

Solution implemented:

- Keep replay in `step` mode with a small count such as 40 or 80.
- To search a larger range, enter a larger count such as 600 and click `Scan Signal`.
- `Scan Signal` uses `analyze_multi` with `mode=once`, so it does not return hundreds of step frames.
- The chart can keep displaying the lightweight replay while the interval panel scans the larger once snapshot.

Positive candidate found through temporary/development backend:

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
- The candidate is not yet a formal strict-step acceptance because `visibleAt.frame` and `confirmedAt.frame` are blank in scan mode.
- Formal Batch C acceptance still requires P0 bundled backend closure and strict-step verification or a dedicated scan-to-step verification workflow.

Batch C acceptance rule:

- Batch C runtime acceptance is blocked until P0 App-bundled Python runtime closure is accepted, unless the user explicitly allows a temporary developer-backend test.
- `Copy Signal` must show source BSP indices, parent/child relation range, visible/confirmed timing fields, and `status: ok` for an actual candidate.
- If `available_signals: 0`, the diagnostics must show high/low BSP counts and native relation count.

## Next task-party operation

1. Wire `AppBackendRuntime` into MultiLevelReplayPage as `Copy Backend`.
2. Implement App-bundled Python / App-managed backend startup.
3. Remove normal user instructions that require manual backend startup.
4. Run `flutter analyze`.
5. Start the app fresh without manually starting Python.
6. Use in-app diagnostics to prove the backend is App-bundled and `/api/chan/analyze_multi` works.
7. Then continue Batch C strict-step verification for the discovered candidate.
