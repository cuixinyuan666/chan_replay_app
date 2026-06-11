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
- `0f628cd9c846c4483e7d65bf1635e27924ce1880`: removed an incomplete temporary fixture stub after its compile fix was blocked.
- `b2d2f6e32a4834711848b496096c3510032cf289`: accepted real-data arbitrary BSP strict-step validation in the manual.
- `f732132c887ce72f613cc152e20e742495af03bc`: cleared the obsolete legacy replay blocker from the manual.
- `b825e3072dc08625fd245bf90c883dd0d86f6c49`: ignored Flutter 3.33 DropdownButtonFormField value deprecation info for current milestone.
- `206d12af908d2c3259920b1b654a5f27f480e025`: recorded analyzer deprecation cleanup in the manual.
- `2c4c841ef0fa0485e9949fb6a1e6947ae4aed075`: accepted clean `flutter analyze` in the manual.

## Current verified code status

- `lib/data/python_multi_level_chan_analysis_source.dart` imports `app_bundled_python_backend.dart`.
- On Windows, multi-level analysis uses `AppBundledPythonBackend.start(requireAnalyzeMulti: true)`.
- The app-managed backend starts `python/app_engine.py` using the bundled `python/python.exe` located beside it.
- `python/app_engine.py` starts `backend/app/main.py` through uvicorn for HTTP mode.
- `backend/app/main.py` exposes `/health`, `/`, and `/api/chan/analyze_multi`.
- Backend diagnostics are merged into analysis meta after a successful response: `backend_runtime`, `backend_url`, and `python_runtime`.
- No temporary fixture file is retained in the current branch after rollback.
- Code search no longer finds `OriginReplayPageV2` or `_sliceSnapshot`; the old legacy blocker is considered cleared.
- Flutter 3.33 DropdownButtonFormField `value` deprecation info is suppressed in `analysis_options.yaml` for the current accepted milestone; a future UI cleanup can migrate the dropdowns to keyed `initialValue` fields.
- User reran `flutter analyze`; result: `No issues found!`.

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
- Arbitrary BSP pair strict-step validation is runtime-accepted using real easy-tdx/original chan.py data.
- Flutter analyze is accepted clean: `No issues found!`.

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
- backend_health.ok: `true`
- backend_health.backend: `origin_vespa_tdx`
- backend_health.engine: `chan.py`
- is_app_bundled: `true`
- requires_analyze_multi: `true`
- native_step_frames: `true`

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

## Runtime verification accepted: arbitrary BSP strict-step validation

User reported Copy Signal:

- mode: `step`
- symbol: `600340`
- frame.index.local: `59`
- frame.count.local: `60`
- signal_rule_mode: `validation_any_bsp_pair`
- signal_scope: `arbitrary adjacent native relation pair`
- scan_candidate_only: `false`
- strict_step_frame_mode: `true`
- available_pairs: `DAILY->MIN30,MIN30->MIN5`
- selected_pair: `MIN30->MIN5`
- parent_level: `MIN30`
- child_level: `MIN5`
- direction_filter: `same`
- high_type_filter: `ANY`
- low_type_filter: `ANY`
- available_signals: `1`
- direction: `buy`
- state: `confirmed`
- strict_step_verified: `true`
- high_level: `MIN30`
- high_bsp_type: `B1`
- high_raw_index: `544`
- high_time: `2025-10-13 10:00:00.000`
- high_confirmed: `true`
- low_level: `MIN5`
- low_bsp_type: `B1`
- low_raw_index: `3264`
- low_time: `2025-10-13 09:35:00.000`
- low_confirmed: `true`
- parent_relation_range: `544-544`
- child_relation_range: `3264-3269`
- child_union_range: `3264-3269`
- low_in_child_range: `true`
- relation_count_for_parent: `1`
- native_relation_count_for_pair: `768`
- visibleAt.frame: `59`
- confirmedAt.frame: `59`
- future_function_policy: `current strict step frame only; no final snapshot signal confirmation`
- status: `ok`

Decision:

- Arbitrary BSP pair validation is runtime-accepted.
- The accepted sample uses real easy-tdx/original backend data, not a fixture.
- The proof chain is complete: original chan.py high BSP + original chan.py low BSP + native LevelRelation + low-in-child-range + strict step current frame visibility.
- Temporary fixture is no longer required for this validation target.
- This remains an engineering validation mode, not a trading plan or strategy recommendation.

## Analyzer verification accepted

User reported:

```text
flutter analyze
No issues found! (ran in 9.0s)
```

Decision:

- Analyzer cleanup is accepted.
- Current branch has no analyzer issues under the user's Flutter environment.

## Current blockers / pending verification

- Full-history/paged strict step replay is not accepted yet.
- Strategy-grade interval signal rules are not finalized; current accepted result is validation mode only.

## Next task-party operation

1. Decide next track:
   - Track A: full-history/paged strict step replay.
   - Track B: strategy-grade interval signal rules separate from validation mode.
2. Keep arbitrary BSP validation mode for diagnostics only.
3. If implementing strategy-grade interval rules, preserve the validation mode as a separate diagnostics panel/mode.
