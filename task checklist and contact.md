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
- Step-frame compact export must not change chan.py core output semantics. It may only change App adapter export, transport, and Flutter parsing/display behavior.

## Latest important commits

- `a1998b519e6985b9d0365cd1b960adf39a97c2a0`: implemented initial `strategy_interval_nest_buy` mode with manual DAILY/MIN30 rules.
- `3b8d1eb571204cbb551c64656612b19ea9125a1b`: added frontend `analyze_multi` timing metadata into `analysis.meta.time_log`.
- `40a694d222aad49002a66d514b11f8cce9ab0e82`: propagated `time_log` into final snapshot and step frame metadata.
- `218b6ae8ec2612bf75e699ce09f2b9697d290185`: added `Copy Time Log` button next to `Copy Signal` in interval signal panel.
- `6264c1e47bde70aa230f2a557d385ffc393a5e3b`: accepted user-provided step and once Time Logs in the manual.
- `b2db4aa399133477606a58fe93643ce0489dfdf6`: added interval rule context fields to copied Time Logs.
- `0ae7c864bba799093d7c94c8eda29c0131ae692a`: added `Copy Result Validation` F0 gate to interval signal panel.
- Current update: accepted user-provided F0 `Copy Result Validation` output with `validation_status: blocked`; F1a compact_v1 is now the current implementation priority.
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
- F0 Copy Result Validation blocked gate: runtime accepted.

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
- Strategy acceptance remains behind performance work priority unless user explicitly changes track.

## P0 Time Log instrumentation

Implemented and accepted:

- Metadata path implemented in `lib/data/python_multi_level_chan_analysis_source.dart`.
- `Copy Time Log` implemented in `lib/ui/widgets/multi_level_interval_signal_panel.dart`.
- Runtime step Load Time Log accepted.
- Runtime Scan Signal / once Time Log accepted.
- Runtime strategy context Time Log with explicit rule fields accepted.
- P0 Time Log fully accepted.

## F0 Result Validation foundation

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

Runtime accepted F0 blocked output:

- request.mode: `step`
- request.symbol: `600340`
- request.market: `SH`
- request.levels: `DAILY,MIN30,MIN5`
- request.count: `220`
- request.max_step_frames: `60`
- request.start/end: `2025-09-01` to `2025-10-20`
- rule_mode_ui: `validation`
- signal_rule_mode: `validation_any_bsp_pair`
- selected_pair: `DAILY->MIN30`
- frame.index.local: `0`
- frame.count.local: `29`
- baseline.main_level: `DAILY`
- baseline.level_count: `3`
- baseline.relation_count.total: `9`
- baseline.relation_count.selected_pair: `1`
- baseline.signal_count.current_rule: `0`
- baseline.level_counts:
  - DAILY: `raw=1,k=1,fx=0,bi=0,seg=0,zs=0,bsp=0`
  - MIN30: `raw=8,k=4,fx=1,bi=0,seg=0,zs=0,bsp=0`
  - MIN5: `raw=48,k=4,fx=2,bi=0,seg=0,zs=0,bsp=0`
- baseline.sample_relation: `DAILY->MIN30:parent=0:child=0-7`
- validation_status: `blocked`
- status: `blocked`

F0 acceptance status:

- UI/action implemented.
- Runtime Copy Result Validation output accepted.
- `validation_status: blocked` is expected because no fast candidate exists.
- `极速` mode remains not accepted and not implemented.
- F1a compact_v1 work may start.

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

## Phase F1a: step frames compact_v1 export and indicator de-duplication

Current priority after F0 acceptance.

Goal:

- Optimize App backend step / multi-level step export format without modifying original `chan.py` FX/BI/SEG/ZS/BSP calculation logic.
- Continue using original step semantics, especially `CChanConfig(trigger_step=True)` and `CChan.step_load()` or equivalent original chan.py step output.
- Reduce repeated JSON, repeated K-line arrays, repeated indicator arrays, and unnecessary frontend parsing.
- Preserve final chart and diagnostic equivalence with the pre-optimization baseline.

Required compact format and behavior:

- Top-level result keeps full bars once.
- Frame object must not include `bars` by default.
- Frame object must include `cursor` and `visible_count`.
- Frame structures remain current-frame structures exported from original chan.py.
- Step mode should compute top-level indicators once for top-level bars.
- Frame object must not include full indicators by default.
- Request/config fields must support:
  - `frame_policy`
  - `frame_stride`
  - `frame_start`
  - `frame_end`
  - `max_return_frames`
  - `include_bars_in_frames`
  - `include_indicators_in_frames`
- Backend meta must include:
  - `step_frame_format: compact_v1`
  - `frame_policy`
  - `frame_stride`
  - `frames_total`
  - `frames_returned`
  - `frames_truncated`
  - `include_bars_in_frames`
  - `include_indicators_in_frames`
- Copy diagnostics must include compact meta and payload/parse timings.
- Copy Result Validation must compare compact result against baseline before compact output can be accepted as a fast path.

Forbidden for F1a:

- Modify `chan.py` core FX/BI/SEG/ZS/BSP logic.
- Recalculate Chan structures in Flutter/Dart.
- Drop `is_sure=false` structures for speed unless explicitly part of an accepted UI filter that does not affect diagnostics.
- Drop BSP types for speed.
- Pretend `stride` replay is full strict step replay.
- Continue writing `bars[:i+1]` into every frame by default.
- Continue writing full indicators into every frame by default.
- Hide mismatch between compact output and baseline output.

## Current blockers / pending verification

- Re-run `flutter analyze` after `0ae7c864bba799093d7c94c8eda29c0131ae692a` and after F1a changes.
- F1a compact_v1 implementation is now the current performance priority.
- Strategy mode acceptance is paused while F1a remains the current priority.
- Full-history/paged strict step replay remains deferred, but F1a/F4 are the planned path toward scalable strict replay.
- `极速` mode implementation must follow F0 then F1a; no speed mode is accepted yet.

## Next task-party operation

1. Inspect backend `analyze_multi` response construction.
2. Identify where step frames include repeated bars and indicators.
3. Add compact_v1 backend meta fields without modifying chan.py core.
4. Add `include_bars_in_frames=false` and `include_indicators_in_frames=false` default behavior at App adapter/export layer.
5. Add Flutter parser compatibility for compact frames plus old full-frame fallback.
6. Re-run `flutter analyze`.
7. Provide Copy P0 / Copy Step / Copy Time Log / Copy Result Validation outputs for compact_v1.
