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
- Speed optimization must not replace chan.py calculation semantics. Any fast path must either call original chan.py or prove byte/structure-equivalent output against the original chan.py baseline.
- No "fast" or "turbo" mode may be accepted without a result validation panel proving no meaningful deviation from the original result.

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

## New P0 before next functional task: Time Log instrumentation

User requirement:

- Before starting the next functional task, add a Time Log system.
- The goal is to record the elapsed time of every major stage, method, and function involved in data loading, backend analysis, parsing, relation construction, signal discovery, rendering preparation, and UI display.
- The app must provide a one-click copy button so the user can paste the time log for supervisor review.
- The supervisor will use the pasted Time Log to plan a later "极速" mode.
- The "极速" mode must keep using original chan.py as the calculation authority and must preserve final presentation equivalence with the original result while greatly reducing load time.
- A result validation panel must be added before any speed mode can be accepted, to prevent deviation from the original chan.py output.

Required Time Log scope:

Backend/app-managed runtime:

- App backend startup time.
- bundled Python process launch time.
- backend `/health` check time.
- request receive time for `/api/chan/analyze_multi`.
- input validation time.
- data source fetch time per level.
- easy-tdx / CSV / cache read time per level if applicable.
- raw data normalization time per level.
- alignment/sort/dedupe time per level.
- `CChan(lv_list)` construction time.
- original chan.py `load` / `step_load` / iteration time.
- per-level snapshot serialization time.
- parent-child `LevelRelation` construction/serialization time.
- BSP extraction/serialization time.
- signal scan / strategy scan time.
- response JSON encoding time.
- total backend elapsed time.

Flutter / UI side:

- request build time.
- HTTP request round-trip time.
- JSON decode time.
- snapshot parse time.
- frames parse time.
- relations parse time.
- BSP/signal parse time.
- chart model build time.
- layer/status panel build time.
- relation panel build time.
- signal panel build time.
- render preparation time if measurable.
- total user-action elapsed time from button click to visible chart/signal panel.

Required Copy Time Log output:

- Add a visible button: `Copy Time Log`.
- It must be available near `Copy P0` / `Copy Step` / `Copy Signal` on the multi-level page.
- It must copy a plain-text diagnostic block.
- It must include:
  - mode: `step|once|signal_scan_once|strategy`.
  - symbol / market / levels / count / max_step_frames / start / end.
  - backend_url.
  - python_runtime and process_source when available.
  - request id or trace id.
  - total elapsed time.
  - backend total time.
  - frontend total time.
  - per-stage timing table.
  - slowest top 10 stages sorted descending.
  - error stage and error message if failed.
  - whether the response used app-bundled Python.
  - whether native `CChan(lv_list)` and original chan.py were used.
  - fallback_to_bridge.

Suggested copy format:

```text
time log diagnostics
button: Copy Time Log
trace_id: ...
mode: step
symbol: 600340
market: SH
levels: DAILY,MIN30,MIN5
count: 220
max_step_frames: 60
start: 2025-09-01
end: 2025-10-20
backend_url: http://127.0.0.1:xxxxx
python_runtime: app_bundled
process_source: app_managed
native_cchan_lv_list: true
fallback_to_bridge: false
total_elapsed_ms: ...
backend_elapsed_ms: ...
frontend_elapsed_ms: ...
slowest_stages:
1. backend.fetch.MIN5: ...ms
2. backend.chan.step_load: ...ms
...
stages:
backend.startup: ...ms
backend.health: ...ms
backend.fetch.DAILY: ...ms
backend.fetch.MIN30: ...ms
backend.fetch.MIN5: ...ms
backend.align: ...ms
backend.cchan.construct: ...ms
backend.cchan.step_load: ...ms
backend.relations: ...ms
backend.serialize: ...ms
frontend.http: ...ms
frontend.json_decode: ...ms
frontend.parse.snapshot: ...ms
frontend.parse.frames: ...ms
frontend.chart_model: ...ms
frontend.total: ...ms
status: ok
```

Acceptance for Time Log:

- Runtime Copy Time Log must be provided for at least:
  1. normal `Load` in step mode.
  2. `Scan Signal` / once mode.
  3. strategy mode Copy Signal path if strategy mode is tested.
- Time values must be non-empty numeric milliseconds.
- The output must identify the slowest stages.
- The output must identify whether bundled Python and original chan.py were used.
- No optimization work may be accepted before Time Log is accepted.

## Future track after Time Log: 极速 mode planning

Important:

- Do not implement "极速" mode before Time Log diagnostics are accepted and reviewed.
- The supervisor will design the optimization plan from the pasted Time Log, not from guesses.
- The optimization goal is large speedup while preserving final display equivalence with original chan.py output.

Allowed optimization directions only after Time Log review:

- data cache keyed by symbol, market, level, adjust, start/end, data source version.
- local app-managed cache for raw bars after first fetch.
- avoid repeated JSON serialization of unchanged structures.
- reuse already computed `CChan` results when request parameters are identical.
- incremental load/append where original chan.py semantics remain unchanged.
- reduce frontend parsing/render preparation duplication.
- paging or lazy materialization of step frames where strict-step semantics are preserved.
- optional prefetch of lower-level raw data without changing final chan.py calculation.

Forbidden optimization directions:

- reimplement Chan FX/BI/SEG/ZS/BSP in Flutter/Dart.
- return approximate Chan structures.
- skip original chan.py calculation for accepted output.
- use final snapshot slicing as strict-step proof.
- hide mismatches between fast result and baseline result.
- treat faster but different output as accepted.

Required result validation panel before accepting any speed mode:

- Add a panel or copy action named `Copy Result Validation` or equivalent.
- It must compare baseline original chan.py result and fast result for the same request.
- It must report:
  - request parameters.
  - baseline mode and fast mode.
  - raw bar counts per level.
  - K/BI/FX/SEG/ZS/BSP counts per level.
  - relation count.
  - signal count by rule.
  - selected sample indices/times for BI/SEG/BSP/relation/signal.
  - exact mismatch counts.
  - first mismatch details.
  - validation status: `match|mismatch|blocked`.
- A fast mode can only be accepted if validation status is `match`, or if differences are explicitly explained and approved.

## Current blockers / pending verification

- P0 Time Log instrumentation is now required before the next functional task.
- Re-run `flutter analyze` after `a1998b519e6985b9d0365cd1b960adf39a97c2a0` and after Time Log changes.
- Runtime-test strategy mode with Copy Signal after Time Log is accepted:
  - rule mode: `strategy`
  - strategy rule: each of the three initial rules
  - selected pair should be `DAILY->MIN30`
- Acceptance requires either:
  - at least one strict-step strategy signal with complete source/relation/frame proof, or
  - no-signal diagnostics proving why a selected strategy rule did not match in the current window.
- Full-history/paged strict step replay remains not accepted and is deferred until strategy mode and performance instrumentation are verified.

## Next task-party operation

1. Run `git pull`.
2. Implement Time Log instrumentation before any further strategy or optimization task.
3. Add `Copy Time Log` in the multi-level UI.
4. Include backend and frontend stage timings as listed above.
5. Run `flutter analyze`.
6. Runtime-test and paste Copy Time Log for:
   - step `Load`.
   - `Scan Signal` / once mode.
   - strategy mode path if tested.
7. Wait for supervisor review of Time Log.
8. Do not implement "极速" mode until supervisor uses the Time Log to create the optimization plan.
9. After Time Log is accepted, continue strategy mode runtime verification.
