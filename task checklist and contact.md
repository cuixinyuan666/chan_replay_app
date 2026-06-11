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
- No `fast` / `turbo` / `极速` mode may be accepted without a result validation panel proving no meaningful deviation from the original result.
- P0 Time Log instrumentation must be completed and accepted before the next functional task.

## Latest important commits

- `a1998b519e6985b9d0365cd1b960adf39a97c2a0`: implemented initial `strategy_interval_nest_buy` mode with manual DAILY/MIN30 rules.
- `3b8d1eb571204cbb551c64656612b19ea9125a1b`: added frontend `analyze_multi` timing metadata into `analysis.meta.time_log`.
- `40a694d222aad49002a66d514b11f8cce9ab0e82`: propagated `time_log` into final snapshot and step frame metadata.
- `218b6ae8ec2612bf75e699ce09f2b9697d290185`: added `Copy Time Log` button next to `Copy Signal` in interval signal panel.
- `6801eaf341e8bb4d7ebf798452436ea75140e32c`: recorded Copy Time Log implementation in the manual.
- `6264c1e47bde70aa230f2a557d385ffc393a5e3b`: accepted user-provided step and once Time Logs in the manual.
- `b2db4aa399133477606a58fe93643ce0489dfdf6`: added interval rule context fields to copied Time Logs.
- Current update: recorded the latest strategy-panel step Time Log and context-field follow-up.
- Earlier accepted commits remain valid: bundled Python backend, native `analyze_multi`, strict step, relation navigation, Scan Signal, arbitrary BSP validation mode, clean analyze before strategy/time-log patches.

## Current accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A active-route strict step replay: accepted for current lightweight/runtime route.
- Batch B native `LevelRelation` targeting: accepted for DAILY->MIN30 and MIN30->MIN5.
- Batch C arbitrary BSP pair strict-step validation: accepted using real easy-tdx/original chan.py data.
- Flutter analyze: previously accepted clean before strategy/time-log patches.
- Legacy `OriginReplayPageV2` / `_sliceSnapshot` blocker: cleared by code search.
- P0 Time Log normal step Load path: runtime accepted.
- P0 Time Log Scan Signal / once path: runtime accepted.

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

- Added `rule mode = validation / strategy`.
- `validation` keeps `validation_any_bsp_pair` diagnostics mode.
- `strategy` activates `strategy_interval_nest_buy` mode.
- Strategy mode forces `selected_pair: DAILY->MIN30`.
- Strategy mode exposes three initial rules:
  1. `DAILY_2B_MIN30_1B`
  2. `DAILY_3B_MIN30_1B`
  3. `DAILY_3B_MIN30_2B`
- Rule matching uses only original backend BSPs and native `LevelRelation` ranges.
- Strategy output is explicitly marked as candidate-only and not a trading recommendation.

User supplied strategy no-signal diagnostics for frame `0/29`:

- `DAILY_2B_MIN30_1B`: no signal; `high_bsp_count=0`, `low_bsp_count=0`, `native_relation_count_for_pair=1`.
- `DAILY_3B_MIN30_1B`: no signal; `high_bsp_count=0`, `low_bsp_count=0`, `native_relation_count_for_pair=1`.
- `DAILY_3B_MIN30_2B`: no signal; `high_bsp_count=0`, `low_bsp_count=0`, `native_relation_count_for_pair=1`.

Decision:

- Strategy mode no-signal diagnostics are structurally useful but cannot be accepted yet, because P0 Time Log supersedes further functional acceptance.
- No strategy signal acceptance may be recorded until Time Log is fully accepted.

## P0 Time Log instrumentation

User requirement:

- Before the next functional task, add a Time Log system.
- The app must provide `Copy Time Log` so the user can paste a time log for supervisor review.
- The supervisor will use Time Log to plan later `极速` mode.
- No optimization work is allowed before Time Log acceptance.

Implemented in `lib/data/python_multi_level_chan_analysis_source.dart`:

- Added `trace_id` for each `analyze_multi` request.
- Added frontend timing stages into `analysis.meta.time_log`:
  - `frontend.request_build`
  - `frontend.backend_ready`
  - `frontend.http_round_trip`
  - `frontend.body_decode`
  - `frontend.json_decode`
  - `frontend.parse.snapshot_frames_relations_bsp`
  - `frontend.total`
- Added request context into `time_log`:
  - mode
  - symbol
  - market
  - levels
  - count
  - max_step_frames
  - start
  - end
- Added runtime/backend context into `time_log` when available:
  - backend_url
  - python_runtime
  - process_source
  - used_app_bundled_python
  - native_cchan_lv_list
  - fallback_to_bridge
- Propagated `time_log` into final snapshot meta and each step frame snapshot meta, so widgets can copy the timing block from current frame or scan snapshot.
- No chan.py calculation semantics changed.

Implemented in `lib/ui/widgets/multi_level_interval_signal_panel.dart`:

- Added visible `Copy Time Log` button next to `Copy Signal`.
- The button reads `widget.snapshot.meta['time_log']`.
- The copied plain-text output includes trace/request/runtime totals, slowest top 10 stages, and full stage table.
- Follow-up patch adds UI context fields to copied logs:
  - `time_log_context: interval_signal_panel`
  - `rule_mode_ui`
  - `signal_rule_mode`
  - `strategy_rule_name`
  - `strategy_high_type`
  - `strategy_low_trigger_type`
  - `selected_pair`
  - `frame.index.local`
  - `frame.count.local`
  - `backend_request_mode`

Runtime Time Log accepted: normal step Load:

- trace_id: `ml-1781194131809617`
- mode: `step`
- symbol: `600340`
- levels: `DAILY,MIN30,MIN5`
- count: `220`
- max_step_frames: `60`
- start/end: `2025-09-01` to `2025-10-20`
- python_runtime: `app_bundled`
- process_source: `app_managed`
- used_app_bundled_python: `true`
- native_cchan_lv_list: `true`
- fallback_to_bridge: `false`
- total_elapsed_ms: `32729`
- backend_elapsed_ms: `12186`
- frontend_elapsed_ms: `32729`
- slowest stages include frontend parse, http round-trip, backend ready, JSON decode.
- status: `ok`

Runtime Time Log accepted: Scan Signal / once:

- trace_id: `ml-1781194209519646`
- mode: `once`
- symbol: `600340`
- levels: `DAILY,MIN30,MIN5`
- count: `220`
- start/end: `2025-09-01` to `2025-10-20`
- python_runtime: `app_bundled`
- process_source: `app_managed`
- used_app_bundled_python: `true`
- native_cchan_lv_list: `true`
- fallback_to_bridge: `false`
- total_elapsed_ms: `12153`
- backend_elapsed_ms: `8738`
- frontend_elapsed_ms: `12153`
- slowest stages include HTTP round-trip, backend ready, parse.
- status: `ok`

Runtime Time Log accepted as step timing from interval panel / strategy test context:

- trace_id: `ml-1781194587353914`
- mode: `step`
- symbol: `600340`
- levels: `DAILY,MIN30,MIN5`
- count: `220`
- max_step_frames: `60`
- start/end: `2025-09-01` to `2025-10-20`
- python_runtime: `app_bundled`
- process_source: `app_managed`
- used_app_bundled_python: `true`
- native_cchan_lv_list: `true`
- fallback_to_bridge: `false`
- total_elapsed_ms: `28210`
- backend_elapsed_ms: `10545`
- frontend_elapsed_ms: `28210`
- slowest stages include frontend parse, http round-trip, backend ready, JSON decode.
- status: `ok`

Strategy context Time Log:

- Latest user-provided strategy-panel Time Log is a valid step timing log, but it was copied before UI context fields were added.
- Retest after `b2db4aa399133477606a58fe93643ce0489dfdf6` should include `rule_mode_ui=strategy` and `signal_rule_mode=strategy_interval_nest_buy`.

P0 Time Log acceptance status:

- Metadata path: implemented.
- Copy Time Log UI: implemented.
- Runtime step Load Time Log: accepted.
- Runtime Scan Signal / once Time Log: accepted.
- Runtime interval-panel step Time Log: accepted.
- Runtime strategy context Time Log with explicit rule fields: pending retest after latest context-field patch.

## Future track after Time Log: 极速 mode planning

Do not implement `极速` mode before Time Log diagnostics are accepted and reviewed.

Allowed only after Time Log review:

- data cache keyed by symbol, market, level, adjust, start/end, data source version.
- app-managed cache for raw bars after first fetch.
- avoid repeated JSON serialization of unchanged structures.
- reuse already computed `CChan` results when request parameters are identical.
- incremental load/append where original chan.py semantics remain unchanged.
- reduce frontend parsing/render preparation duplication.
- paging or lazy materialization of step frames where strict-step semantics are preserved.

Forbidden:

- reimplement Chan FX/BI/SEG/ZS/BSP in Flutter/Dart.
- return approximate Chan structures.
- skip original chan.py calculation for accepted output.
- use final snapshot slicing as strict-step proof.
- hide mismatches between fast result and baseline result.

## Current blockers / pending verification

- Re-run `flutter analyze` after `b2db4aa399133477606a58fe93643ce0489dfdf6`.
- Runtime strategy context Copy Time Log must be retested after latest context-field patch.
- Strategy mode acceptance is paused until Time Log is fully accepted.
- Full-history/paged strict step replay remains deferred.

## Next task-party operation

1. Run `git pull`.
2. Run `flutter analyze`.
3. Open multi-level page and perform normal step Load.
4. Open `区间信号`, set `rule mode=strategy`, then click `Copy Time Log`; paste the result.
5. Expected new fields:
   - `time_log_context: interval_signal_panel`
   - `rule_mode_ui: strategy`
   - `signal_rule_mode: strategy_interval_nest_buy`
   - `strategy_rule_name: ...`
   - `backend_request_mode: step`
6. Once strategy context Time Log with rule fields is accepted, resume strategy-mode acceptance or full-history/paged strict step track.
