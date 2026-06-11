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
- F0 Result Validation gate must exist before any fast/极速 path can be exposed as accepted.

## Latest important commits

- `a1998b519e6985b9d0365cd1b960adf39a97c2a0`: implemented initial `strategy_interval_nest_buy` mode with manual DAILY/MIN30 rules.
- `3b8d1eb571204cbb551c64656612b19ea9125a1b`: added frontend `analyze_multi` timing metadata into `analysis.meta.time_log`.
- `40a694d222aad49002a66d514b11f8cce9ab0e82`: propagated `time_log` into final snapshot and step frame metadata.
- `218b6ae8ec2612bf75e699ce09f2b9697d290185`: added `Copy Time Log` button next to `Copy Signal` in interval signal panel.
- `6264c1e47bde70aa230f2a557d385ffc393a5e3b`: accepted user-provided step and once Time Logs in the manual.
- `b2db4aa399133477606a58fe93643ce0489dfdf6`: added interval rule context fields to copied Time Logs.
- `0ae7c864bba799093d7c94c8eda29c0131ae692a`: added `Copy Result Validation` F0 gate to interval signal panel.
- Current update: recorded F0 Result Validation implementation and pending runtime/analyze validation.
- Earlier accepted commits remain valid: bundled Python backend, native `analyze_multi`, strict step, relation navigation, Scan Signal, arbitrary BSP validation mode.

## Current accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A active-route strict step replay: accepted for current lightweight/runtime route.
- Batch B native `LevelRelation` targeting: accepted for DAILY->MIN30 and MIN30->MIN5.
- Batch C arbitrary BSP pair strict-step validation: accepted using real easy-tdx/original chan.py data.
- Flutter analyze: previously accepted clean before strategy/time-log/F0 patches.
- Legacy `OriginReplayPageV2` / `_sliceSnapshot` blocker: cleared by code search.
- P0 Time Log normal step Load path: runtime accepted.
- P0 Time Log Scan Signal / once path: runtime accepted.
- P0 Time Log interval-panel step timing path: runtime accepted.
- P0 Time Log strategy context with explicit fields: runtime accepted by user-provided log.

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

- Strategy mode no-signal diagnostics are structurally useful.
- Strategy acceptance can resume only after F0 Result Validation output is runtime-verified.

## P0 Time Log instrumentation

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
- Added request/runtime/backend context into `time_log`.
- Propagated `time_log` into final snapshot meta and each step frame snapshot meta.
- No chan.py calculation semantics changed.

Implemented in `lib/ui/widgets/multi_level_interval_signal_panel.dart`:

- Added visible `Copy Time Log` button next to `Copy Signal`.
- Added context fields to copied logs:
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
- status: `ok`

Runtime Time Log accepted: strategy context with explicit fields:

- `time_log_context: interval_signal_panel`
- `rule_mode_ui: strategy`
- `signal_rule_mode: strategy_interval_nest_buy`
- `strategy_rule_name: DAILY_2B_MIN30_1B`
- `strategy_high_type: 2-buy`
- `strategy_low_trigger_type: 1-buy`
- `selected_pair: DAILY->MIN30`
- `backend_request_mode: step`
- trace_id: `ml-1781195049889660`
- mode: `strategy`
- symbol: `600340`
- levels: `DAILY,MIN30,MIN5`
- count: `220`
- max_step_frames: `60`
- start/end: `2025-09-01` to `2025-10-20`
- python_runtime: `app_bundled`
- process_source: `app_managed`
- native_cchan_lv_list: `true`
- fallback_to_bridge: `false`
- total_elapsed_ms: `26470`
- backend_elapsed_ms: `10678`
- frontend_elapsed_ms: `26470`
- status: `ok`

P0 Time Log acceptance status:

- Metadata path: implemented.
- Copy Time Log UI: implemented.
- Runtime step Load Time Log: accepted.
- Runtime Scan Signal / once Time Log: accepted.
- Runtime interval-panel step Time Log: accepted.
- Runtime strategy context Time Log with explicit rule fields: accepted.
- P0 Time Log: fully accepted.

## Supervisor analysis from accepted Time Logs

Observed timing bottlenecks:

- Normal step Load total elapsed: `32729ms`.
- Normal step backend elapsed: `12186ms`.
- Normal step frontend/action elapsed: `32729ms`.
- Scan Signal / once total elapsed: `12153ms`.
- Scan Signal / once backend elapsed: `8738ms`.
- Strategy-context step total elapsed: `26470ms`.
- Strategy-context step backend elapsed: `10678ms`.
- Slowest reported stages repeatedly include frontend parse, HTTP round-trip, backend ready, JSON decode, and backend chan.py/data preparation work.

Interpretation:

- `step` mode is much slower than `once` because step mode returns frame data and heavier frontend parsing work.
- Backend time is significant, but the largest user-visible delay is end-to-end frontend action time, including HTTP round-trip, JSON decode, and large snapshot/frame parsing.
- The first optimization target should not be Chan algorithm replacement. It should be data/result reuse, response-size reduction, frontend parse reduction, and frame materialization control while keeping original chan.py as source of truth.

## 极速 mode optimization plan

Goal:

- Preserve final presentation equivalence with baseline original chan.py output.
- Keep original chan.py as the calculation authority.
- Reduce user-visible load time substantially, especially repeated requests for the same symbol/window/config.
- Add validation proof before accepting any fast path.

Target performance goals for the accepted test window `600340 / SH / DAILY,MIN30,MIN5 / 2025-09-01 to 2025-10-20 / count=220`:

- Cold step Load target: below `18s` initially, then below `12s` after transport/parse optimization.
- Warm repeated step Load target: below `5s` when raw data and baseline result are cached.
- Scan Signal / once warm target: below `3s`.
- UI panel interactions after data is loaded: below `500ms` where no backend recomputation is required.

## Phase F0: result validation foundation, before any speed switch is accepted

Required behavior:

- Add `Copy Result Validation` panel/action.
- Run baseline mode and fast candidate mode on the same request parameters when fast candidate exists.
- Compare structure-level results before exposing `极速` mode as accepted.
- If no fast candidate exists, validation must report `validation_status: blocked` and must not allow any speed mode acceptance.

Implemented in `lib/ui/widgets/multi_level_interval_signal_panel.dart`:

- Added visible `Copy Result Validation` button next to `Copy Signal` and `Copy Time Log`.
- Current implementation does not enable any fast candidate.
- Current output reports:
  - `validation_phase: F0`
  - `baseline_source: original chan.py analyze_multi`
  - `fast_candidate_enabled: false`
  - `validation_status: blocked`
  - `blocked_reason: no fast candidate mode/cache/compact payload configured`
  - request parameters.
  - baseline raw/K/FX/BI/SEG/ZS/BSP counts per level.
  - total relation count and selected pair relation count.
  - current rule signal count.
  - sampled BSP rows.
  - sampled relation rows.
  - acceptance policy.
- This satisfies the F0 gate requirement that speed mode cannot be accepted without validation output.

F0 acceptance status:

- UI/action implemented.
- Runtime Copy Result Validation output: pending user paste.
- Since no fast candidate exists, expected status is `validation_status: blocked`.
- `极速` mode remains not accepted and not implemented.

## Future phases after F0 runtime validation

Phase F1: raw data cache, safest first speedup.

- Cache raw bars only before chan.py calculation.
- On cache hit, still run original chan.py using cached raw bars.
- Add cache timing fields to Time Log.

Phase F2: baseline result cache for identical requests.

- Cache baseline original chan.py analysis output for identical request parameters and raw-data digest.
- On exact cache hit, return cached baseline result, clearly marked as `fast_cache_hit: true`.
- Result Validation must compare cached return against baseline at least once and report `match`.

Phase F3: response-size and frontend parse reduction.

- Avoid duplicating large unchanged structures across every step frame.
- Use shared baseline payload plus frame deltas or frame indexes only if Result Validation passes.

Phase F4: step-frame paging / lazy strict replay.

- Preserve strict-step semantics by serving original chan.py step frames in pages.
- Do not use final snapshot slicing.
- Result Validation must compare sampled frames across pages against baseline full step output.

Phase F5: strategy/signal fast reuse.

- Strategy rules may run on already parsed original chan.py BSP and native `LevelRelation` data without recomputing chan.py.
- This is only signal filtering over original chan.py output, not Chan structure calculation.

Forbidden optimization directions:

- Reimplement Chan FX/BI/SEG/ZS/BSP in Flutter/Dart.
- Return approximate Chan structures.
- Skip original chan.py calculation for accepted output unless returning an exact cached baseline result generated by original chan.py.
- Use final snapshot slicing as strict-step proof.
- Hide mismatches between fast result and baseline result.
- Treat faster but different output as accepted.

## Current blockers / pending verification

- Re-run `flutter analyze` after `0ae7c864bba799093d7c94c8eda29c0131ae692a`.
- Runtime `Copy Result Validation` output must be pasted and checked.
- Expected F0 status now: `validation_status: blocked`, because no fast candidate exists.
- Strategy mode acceptance can resume only after F0 Result Validation output is verified.
- Full-history/paged strict step replay remains deferred.
- `极速` mode implementation must follow phases F0 to F5; no speed mode is accepted yet.

## Next task-party operation

1. Run `git pull`.
2. Run `flutter analyze`.
3. Open multi-level page and perform normal step Load.
4. Open `区间信号`.
5. Click `Copy Result Validation`; paste the result.
6. Expected fields:
   - `result validation diagnostics`
   - `button: Copy Result Validation`
   - `validation_phase: F0`
   - `baseline_source: original chan.py analyze_multi`
   - `fast_candidate_enabled: false`
   - `validation_status: blocked`
   - `blocked_reason: no fast candidate mode/cache/compact payload configured`
   - baseline level counts.
   - relation counts.
   - sampled BSP/relation rows.
7. After F0 output is accepted, choose next track: strategy-mode acceptance or F1 raw-data cache design.
