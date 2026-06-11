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
- User-facing workflow must not require manually starting system Python, Conda Python, Windows Store Python, Termux Python, or any other external interpreter.

## Latest important commits

- `dd1f52b9e55ee45f6066bd41ef448972c5625c0b`: added `Scan Signal` workflow and guarded large step counts.
- `63e54230189d97b2c247d185d95c105d935ec462`: extended once-mode timeout for larger count scans.
- `8a1ddfa2c56741738752d14d6e631552eb912e91`: restored `_PythonMultiLevelBackendMismatch` and fixed analyzer/build errors.
- `93aaa753b1e391132439e88167677ddd7cc6fd65`: removed the nonexistent `python/a_server.py` fallback.
- `c30e8fba5aaf7cf54931d13e03b3bac3bbba461d`: recorded the first positive Scan Signal candidate.
- `c79e30337a302e38e4e5825d8e0ffbe77ee85549`: removed an obsolete diagnostic stub that checked old backend paths.
- `2a85cd1064e2a3505e01794ec0c86deaef5e8507`: added candidate-date step window controls and lv_list selectors.
- `9ddec3bb67811a178fb15ff640280a9cc84edf26`: added arbitrary level/BSP validation mode in Copy Signal.

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
- App-bundled Python implementation exists in latest code.
- App-bundled Python runtime is runtime-accepted by user Copy P0 diagnostics.
- Fresh multi-level `Load` works through App-managed bundled Python backend at an app-assigned localhost port.

## Runtime verification accepted: App-bundled Python / Copy P0

User reported Copy P0:

- mode: `step`
- symbol: `600340`
- market: `SH`
- levels: `DAILY,MIN30,MIN5`
- strict_step_blocked: `false`
- native_cchan_lv_list: `true`
- level_relation_mode: `chan_parent_child`
- fallback_to_bridge: `false`
- relations.length: `360`
- frames.length: `24`
- source: `origin_vespa_tdx.backend.a_multilevel_native_engine`
- backend_url: `http://127.0.0.1:13053`
- python_runtime: `app_bundled`
- backend_runtime.process_source: `app_managed`
- backend_runtime.python_runtime: `app_bundled`
- backend_runtime.python_runtime_path: `python/python.exe` inside the app directory
- backend_runtime.app_engine_path: `python/app_engine.py` inside the app directory
- backend_health.ok: `true`
- backend_health.backend: `origin_vespa_tdx`
- backend_health.engine: `chan.py`
- backend_health.research_api: `true`
- is_app_bundled: `true`
- requires_analyze_multi: `true`
- native_step_frames: `true`
- native_step_frames_total: `40`
- native_step_frames_returned: `24`
- native_step_frames_truncated: `true`

Decision:

- App-managed bundled Python runtime is accepted for the reported Windows workflow.
- The app no longer requires the user to manually start an external interpreter for the reported multi-level workflow.
- `/api/chan/analyze_multi` is available from the App-managed backend.
- Continue requiring in-app diagnostics for future runtime issues.

## Candidate-date step window controls

Implemented in `MultiLevelReplayPage`:

- `lv_list` is selected through ordered chips: `DAILY`, `MIN60`, `MIN30`, `MIN15`, `MIN5`, `MIN1`.
- The selected level order follows the fixed top-down order from those chips.
- `count` is selectable through a dropdown: `40`, `80`, `120`, `220`, `600`.
- `max_step_frames` is selectable through a dropdown: `24`, `40`, `60`, `120`.
- `start` and `end` date fields are shown in the header and are passed to `analyze_multi` for both `Load` and `Scan Signal`.
- The `候选窗口 2025-10-13` button sets mode/levels/count/window for candidate verification.
- `Copy P0` and `Copy Step` include selected lv_list, count, max_step_frames, start, and end.

## Arbitrary BSP validation mode

Implemented in `MultiLevelIntervalSignalPanel`:

- The old fixed DAILY/MIN30 MVP-only scan is replaced by a validation-oriented arbitrary BSP pair scanner.
- The panel derives selectable level pairs from native `LevelRelation` pairs in the current snapshot.
- User can choose parent-child pair such as `DAILY->MIN30` or `MIN30->MIN5` when such relation exists.
- Direction filter is selectable: `all`, `same`, `buy`, `sell`, `mixed`.
- High BSP type filter is selectable from actual high-level BSP types in the current snapshot.
- Low BSP type filter is selectable from actual low-level BSP types in the current snapshot.
- Default rule mode is `validation_any_bsp_pair`.
- Candidate rule is: parent-level BSP from original chan.py + child-level BSP from original chan.py, with low BSP raw index inside the native LevelRelation child range for the selected parent BSP.
- This validation mode is for proving the engineering chain, not for defining a final trading strategy.

Copy Signal now exports:

- `signal_rule_mode`
- `selected_pair`
- `available_pairs`
- `direction_filter`
- `high_type_filter`
- `low_type_filter`
- high/low BSP counts and type counts when no signal matches
- high/low BSP index, type, raw index, time, price, confirmed flag, BI/SEG/ZS index when matched
- parent relation range, child relation range, child union range, and low-in-child-range proof
- `strict_step_verified` and `visibleAt.frame` / `confirmedAt.frame` when mode is step
- scan-mode candidates are explicitly marked as candidate-only and not strict-step accepted

## Current blockers / pending verification

- Run `flutter analyze` on latest branch after arbitrary BSP validation changes.
- Runtime-verify arbitrary BSP validation mode with Copy Signal output.
- Batch C strict-step verification is still pending until Copy Signal in step mode returns enough evidence for a candidate.
- Full-history/paged strict step replay is not accepted yet.
- Legacy `OriginReplayPageV2` still exists and still contains `_sliceSnapshot`; it is no longer the active route.

## Batch C current state

Problem observed:

- Fixed buy-point combinations were too narrow for engineering verification.
- A step frame can have low-level BSP and native relations, but no high-level BSP; fixed combo rules cannot produce candidates in that frame.
- Engineering verification should not be blocked by one strategy combo.

Implemented solution:

- Keep strategy-style MVP combinations as a future policy layer.
- Use arbitrary BSP validation mode to prove original chan.py BSP + native LevelRelation + strict step visibility.
- The found scan candidate remains useful, but the validation panel can also prove other level/BSP combinations.

Previously positive scan candidate:

- mode: `signal_scan_once`
- symbol: `600340`
- available_signals: `1`
- direction: `buy`
- state: `confirmed`
- high_level: `DAILY`
- high_pattern: `2-buy`
- high_bsp_type: `B2s`
- high_time: `2025-10-13 23:59:00.000`
- low_level: `MIN30`
- low_trigger: `1-buy`
- low_bsp_type: `B1`
- low_time: `2025-10-13 10:00:00.000`
- relation_count_for_parent: `1`
- status: `ok`

## Next task-party operation

1. Run `git pull`.
2. Run `flutter analyze`.
3. Run the app fresh without manually starting external Python.
4. Load a candidate-date step window or any step window with available BSPs.
5. Open `区间信号`.
6. Select a native relation pair, direction filter, and BSP type filters.
7. Click `Copy Signal`.
8. Paste Copy Signal diagnostics to determine whether strict-step validation can be accepted.
