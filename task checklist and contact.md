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
- Validation mode and strategy mode must stay separate. Validation mode proves the engineering chain; strategy mode defines interval-nest rules.
- No strategy signal may be accepted unless Copy Signal proves source BSPs, native relation range, strict-step visibility, and signal state.

## Latest important commits

- `b2d2f6e32a4834711848b496096c3510032cf289`: accepted real-data arbitrary BSP strict-step validation in the manual.
- `f732132c887ce72f613cc152e20e742495af03bc`: cleared obsolete legacy replay blocker from the manual.
- `b825e3072dc08625fd245bf90c883dd0d86f6c49`: ignored Flutter 3.33 DropdownButtonFormField value deprecation info for current milestone.
- `4dbb8989d13c8942a2ba5d8824d6d3c326423175`: accepted clean `flutter analyze` in the manual.
- `a1998b519e6985b9d0365cd1b960adf39a97c2a0`: implemented initial `strategy_interval_nest_buy` mode with manual DAILY/MIN30 rules.
- Earlier accepted commits remain valid: bundled Python backend, native `analyze_multi`, candidate date window controls, relation navigation, Scan Signal, and arbitrary BSP validation mode.

## Current accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A active-route strict step replay: accepted for current lightweight/runtime route.
- Batch B native `LevelRelation` targeting: accepted for DAILY->MIN30 and MIN30->MIN5.
- Batch C arbitrary BSP pair strict-step validation: accepted using real easy-tdx/original chan.py data.
- Flutter analyze: accepted clean before strategy-mode patch (`No issues found!`).
- Legacy `OriginReplayPageV2` / `_sliceSnapshot` blocker: cleared by code search.

## Current verified code status

- `lib/data/python_multi_level_chan_analysis_source.dart` uses `AppBundledPythonBackend.start(requireAnalyzeMulti: true)` on Windows.
- App-managed backend starts `python/app_engine.py` using bundled `python/python.exe`.
- `backend/app/main.py` exposes `/api/chan/analyze_multi` and `/health`.
- Backend diagnostics are merged into analysis meta after successful response.
- Multi-level page exposes Copy P0, Copy Step, Copy Relation, and Copy Signal.
- `lv_list`, `count`, `max_step_frames`, `start`, and `end` are user-controllable in the multi-level page.
- No fixture code is retained; validation and strategy testing use real easy-tdx/original backend data.

## Runtime verification accepted: App-bundled Python / Copy P0

User reported Copy P0 proving:

- `python_runtime: app_bundled`
- `backend_runtime.process_source: app_managed`
- `backend_health.ok: true`
- `backend_health.backend: origin_vespa_tdx`
- `backend_health.engine: chan.py`
- `requires_analyze_multi: true`
- `native_cchan_lv_list: true`
- `level_relation_mode: chan_parent_child`
- `fallback_to_bridge: false`
- `frames.length > 0`
- `relations.length > 0`

Decision: App-managed bundled Python runtime is accepted for the reported Windows workflow.

## Runtime verification accepted: arbitrary BSP strict-step validation

User reported Copy Signal proving:

- mode: `step`
- signal_rule_mode: `validation_any_bsp_pair`
- selected_pair: `MIN30->MIN5`
- high BSP: `MIN30 B1`, `raw_index=544`, `confirmed=true`
- low BSP: `MIN5 B1`, `raw_index=3264`, `confirmed=true`
- child relation range: `3264-3269`
- `low_in_child_range: true`
- `strict_step_verified: true`
- `visibleAt.frame: 59`
- `confirmedAt.frame: 59`
- `future_function_policy: current strict step frame only; no final snapshot signal confirmation`
- status: `ok`

Decision: arbitrary BSP pair validation is accepted as engineering diagnostics only, not as a trading strategy.

## Strategy mode implementation status

Implemented in `lib/ui/widgets/multi_level_interval_signal_panel.dart`:

- Added a `rule mode` dropdown:
  - `validation`: keeps `validation_any_bsp_pair` diagnostics mode.
  - `strategy`: activates `strategy_interval_nest_buy` mode.
- Validation mode remains the default and must not be reused as strategy output.
- Strategy mode forces selected pair to `DAILY->MIN30` and hides arbitrary validation filters.
- Strategy mode adds a `strategy rule` dropdown with the three manual-required rules:
  1. `DAILY_2B_MIN30_1B`
  2. `DAILY_3B_MIN30_1B`
  3. `DAILY_3B_MIN30_2B`
- Rule matching uses only original backend BSPs and native `LevelRelation` ranges:
  - `DAILY_2B_MIN30_1B`: high type `B2/B2s`, low type `B1`.
  - `DAILY_3B_MIN30_1B`: high type `B3/B3s`, low type `B1`.
  - `DAILY_3B_MIN30_2B`: high type `B3/B3s`, low type `B2/B2s`.
- Strategy mode still requires low trigger BSP to be inside the native child range.
- Strategy mode does not add Chan calculation logic in Flutter/Dart.
- Strategy output is explicitly marked as candidate-only and not a trading recommendation.

Copy Signal strategy fields now include:

- `signal_rule_mode: strategy_interval_nest_buy`
- `rule_mode_ui: strategy`
- `strategy_rule_name`
- `strategy_high_type`
- `strategy_low_trigger_type`
- `selected_pair: DAILY->MIN30`
- high BSP index/type/raw index/time/price/confirmed fields
- low BSP index/type/raw index/time/price/confirmed fields
- native parent/child relation ranges
- `low_in_child_range`
- `signal_state`
- `visibleAt.frame`
- `confirmedAt.frame`
- `invalidatedAt.frame`
- `source_policy: original chan.py BSP + native LevelRelation only`
- `future_function_policy`
- `strategy_caveat`
- `status`

## Current blockers / pending verification

- Re-run `flutter analyze` after `a1998b519e6985b9d0365cd1b960adf39a97c2a0`.
- Runtime-test strategy mode with Copy Signal:
  - rule mode: `strategy`
  - strategy rule: each of the three initial rules
  - selected pair should be `DAILY->MIN30`
- Acceptance requires either:
  - at least one strict-step strategy signal with complete source/relation/frame proof, or
  - no-signal diagnostics proving why a selected strategy rule did not match in the current window.
- Full-history/paged strict step replay remains not accepted and is deferred until strategy mode is verified.

## Next task-party operation

1. Run `git pull`.
2. Run `flutter analyze`.
3. Open multi-level page, load a step window with `DAILY,MIN30,MIN5`.
4. Open `区间信号`.
5. Set `rule mode = strategy`.
6. Test each strategy rule:
   - `DAILY_2B_MIN30_1B`
   - `DAILY_3B_MIN30_1B`
   - `DAILY_3B_MIN30_2B`
7. Click `Copy Signal` for each rule and paste results.
