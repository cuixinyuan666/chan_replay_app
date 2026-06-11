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
- Current update: added `compact_v1` step-frame lightweight export and indicator de-duplication task as the current performance priority.
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

## Phase F1a: step frames compact_v1 export and indicator de-duplication

Current priority:

- This is now the first implementation task after F0 runtime `Copy Result Validation` output is checked.
- This task addresses the accepted Time Log bottleneck directly: large frames payload, repeated bars, repeated indicators, JSON decode, frontend parse, and frame materialization.
- This task is part of the `极速` plan, but it is not a separate Chan calculation engine.

Goal:

- Optimize App backend step / multi-level step export format without modifying original `chan.py` FX/BI/SEG/ZS/BSP calculation logic.
- Continue using original step semantics, especially `CChanConfig(trigger_step=True)` and `CChan.step_load()` or equivalent original chan.py step output.
- Reduce repeated JSON, repeated K-line arrays, repeated indicator arrays, and unnecessary frontend parsing.
- Preserve final chart and diagnostic equivalence with the pre-optimization baseline.

Core rule:

- `chan.py` remains the only Chan calculation source.
- Every frame's FX/BI/SEG/ZS/BSP must come from the current `CChan` object returned by original chan.py step iteration.
- Flutter/Dart must not calculate FX/BI/SEG/ZS/BSP or multi-level parent-child relations.

### F1a.1 Do not return `bars[:i+1]` inside every frame

Problem:

- Old step export may put visible bars into each frame.
- For N bars, repeated `bars[:i+1]` creates approximately `N*(N+1)/2` serialized bars.
- This inflates response bytes, backend JSON serialization time, frontend JSON decode time, parse time, and memory.

Required compact format:

```json
{
  "bars": [
    {"time": "...", "open": 0, "high": 0, "low": 0, "close": 0}
  ],
  "frames": [
    {
      "cursor": 120,
      "visible_count": 121,
      "merged_bars": [],
      "fx": [],
      "bi": [],
      "seg": [],
      "zs": [],
      "bsp": []
    }
  ]
}
```

Backend requirement:

- Top-level result keeps full `bars` once.
- Frame object must not include `bars` by default.
- Frame object must include `cursor` and `visible_count`.
- Frame structures remain current-frame structures exported from original chan.py.

Flutter requirement:

- New parser path must render visible bars from top-level bars plus `visible_count`.
- Parser may temporarily support old `frame.bars` for compatibility.
- New default export must be `compact_v1` and must not include `frame.bars`.

### F1a.2 Do not recalculate or return full indicators in every frame

Problem:

- Display indicators such as VOL/MA/BOLL/MACD should not be rebuilt from scratch for each `frame_bars` prefix.
- Per-frame full indicators inflate CPU and payload size and can create future-data risks if not clipped correctly.

Backend requirement:

- Once mode: top-level bars and top-level indicators are allowed.
- Step mode: compute top-level indicators once for top-level bars.
- Frame object must not include full indicators by default.
- Remove or disable per-frame calls equivalent to `build_display_indicators(frame_bars, config)`.

Flutter requirement:

- In step replay, chart indicators must be clipped by current frame `visible_count`.
- Crosshair and tooltip must not read or display indicator values beyond `visible_count`.
- This clipping is required to avoid future-data leakage in replay.

Validation:

- Same bars must produce consistent once top-level indicators and step top-level indicators.
- Any frame must display only bars/indicators up to `visible_count`.

### F1a.3 Add frame export policy

Required request/config fields:

```json
{
  "frame_policy": "full | stride | window | latest",
  "frame_stride": 1,
  "frame_start": null,
  "frame_end": null,
  "max_return_frames": 300,
  "include_bars_in_frames": false,
  "include_indicators_in_frames": false
}
```

Policies:

- `full`: export every original chan.py step frame. Only for small/debug windows. Recommended hard limit: `count <= 300`.
- `stride`: export every Nth frame. UI must label this as fast/skip-frame replay, not strict full replay.
- `window`: export only frames in `[frame_start, frame_end]`. Use for local strict replay around a time region.
- `latest`: export only the final step frame. Use only when a step-final state is required; for normal final charts prefer once mode.

Recommended defaults:

- Normal step request:

```json
{
  "frame_policy": "stride",
  "frame_stride": 5,
  "max_return_frames": 300,
  "include_bars_in_frames": false,
  "include_indicators_in_frames": false
}
```

- Strict step debug:

```json
{
  "frame_policy": "full",
  "frame_stride": 1,
  "max_return_frames": 300
}
```

- Long multi-level window replay:

```json
{
  "frame_policy": "window",
  "frame_start": 0,
  "frame_end": 300,
  "include_bars_in_frames": false,
  "include_indicators_in_frames": false
}
```

UI requirement:

- UI must display current `frame_policy`, total frames, returned frames, and truncated status.
- If `stride`, `window`, `latest`, or `frames_truncated=true`, UI must clearly warn that the current view is not full strict one-by-one replay.

### F1a.4 Meta contract

Backend meta must include:

```json
{
  "step_frame_format": "compact_v1",
  "frame_policy": "stride",
  "frame_stride": 5,
  "frames_total": 3000,
  "frames_returned": 300,
  "frames_truncated": true,
  "include_bars_in_frames": false,
  "include_indicators_in_frames": false
}
```

Copy diagnostics must include the same meta in `Copy Step`, `Copy P0`, `Copy Time Log`, and `Copy Result Validation` when available.

### F1a.5 Multi-level compact structure

Multi-level response should not put each level's bars inside every frame.

Recommended structure:

```json
{
  "levels": {
    "DAILY": {"bars": [], "indicators": {}},
    "MIN30": {"bars": [], "indicators": {}},
    "MIN5": {"bars": [], "indicators": {}}
  },
  "frames": [
    {
      "cursor": 120,
      "current_time": "2025-01-01 15:00:00",
      "levels": {
        "DAILY": {"visible_count": 121, "merged_bars": [], "fx": [], "bi": [], "seg": [], "zs": [], "bsp": []},
        "MIN30": {"visible_count": 800, "merged_bars": [], "fx": [], "bi": [], "seg": [], "zs": [], "bsp": []},
        "MIN5": {"visible_count": 4800, "merged_bars": [], "fx": [], "bi": [], "seg": [], "zs": [], "bsp": []}
      },
      "relations": []
    }
  ]
}
```

Principles:

- Each level's bars are returned once at top-level for that level.
- Each frame carries only that level's `visible_count` and current structures.
- Relations remain current-frame relations and must come from native backend relation data.

### F1a.6 Result validation and acceptance

Required validation:

- `Copy Result Validation` must compare baseline and compact result for the same request.
- It must report:
  - once final merged/K/FX/BI/SEG/ZS/BSP counts unchanged.
  - step final frame structures unchanged.
  - multi-level final structures unchanged per level.
  - relation counts unchanged or mismatch explicitly reported.
  - signal counts by rule unchanged or mismatch explicitly reported.
  - `validation_status: match|mismatch|blocked`.

No future-data acceptance:

- Any frame must show only `visible_count` bars.
- Any frame must show only indicators up to `visible_count`.
- Crosshair/tooltip must not access future bars/indicators.
- FX/BI/SEG/ZS/BSP structures in a frame must not reference K-line indexes beyond visible range.

Payload acceptance:

- `frame.bars` must be absent by default in new compact output.
- `frame.indicators` full arrays must be absent by default.
- JSON response bytes must be reported in Time Log before and after compact mode.
- JSON size should materially decrease for the same step request.

UI acceptance:

- UI displays `step_frame_format`, `frame_policy`, `frames_total`, `frames_returned`, and `frames_truncated`.
- UI distinguishes full strict step from stride/window/latest replay.
- Compatibility parser may read old `frame.bars`, but new export contract is `compact_v1`.

### F1a.7 Deliverables

Task party must deliver:

1. Backend `step_frame_format: compact_v1` output.
2. Single-level step does not repeat `bars` inside frames.
3. Single-level step does not repeat full indicators inside frames.
4. Multi-level step does not repeat each level's bars inside frames.
5. `frame_policy`, `frame_stride`, `frame_start`, `frame_end`, `max_return_frames` support.
6. `include_bars_in_frames=false` and `include_indicators_in_frames=false` default behavior.
7. Flutter parser support for `compact_v1` plus temporary old-format compatibility.
8. UI display for `frame_policy` / `frames_total` / `frames_returned` / `frames_truncated`.
9. Copy diagnostics include compact meta and payload/parse timings.
10. Copy Result Validation proves compact output matches baseline.
11. Time Log shows JSON bytes, backend serialize time, frontend decode time, frontend parse time before/after.
12. Clear statement that `chan.py` core logic was not changed.

### F1a.8 Forbidden for this task

- Modify `chan.py` core FX/BI/SEG/ZS/BSP logic.
- Recalculate Chan structures in Flutter/Dart.
- Drop `is_sure=false` structures for speed unless explicitly part of an accepted UI filter that does not affect diagnostics.
- Drop BSP types for speed.
- Pretend `stride` replay is full strict step replay.
- Continue writing `bars[:i+1]` into every frame by default.
- Continue writing full indicators into every frame by default.
- Hide mismatch between compact output and baseline output.

## Future phases after F1a compact_v1 validation

Phase F1b: raw data cache.

- Cache raw bars only before chan.py calculation.
- On cache hit, still run original chan.py using cached raw bars.
- Add cache timing fields to Time Log.

Phase F2: baseline result cache for identical requests.

- Cache baseline original chan.py analysis output for identical request parameters and raw-data digest.
- On exact cache hit, return cached baseline result, clearly marked as `fast_cache_hit: true`.
- Result Validation must compare cached return against baseline at least once and report `match`.

Phase F3: additional response-size and frontend parse reduction.

- Build on compact_v1.
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

- Re-run `flutter analyze` after `0ae7c864bba799093d7c94c8eda29c0131ae692a` and after compact_v1 changes.
- Runtime `Copy Result Validation` output must be pasted and checked.
- Expected F0 status now: `validation_status: blocked`, because no fast candidate exists.
- F1a compact_v1 implementation is now the current performance priority after F0 output is checked.
- Strategy mode acceptance is paused until F0 and F1a validation requirements are satisfied.
- Full-history/paged strict step replay remains deferred, but F1a/F4 are the planned path toward scalable strict replay.
- `极速` mode implementation must follow F0 then F1a; no speed mode is accepted yet.

## Next task-party operation

1. Run `git pull`.
2. Run `flutter analyze`.
3. Open multi-level page and perform normal step Load.
4. Open `区间信号`.
5. Click `Copy Result Validation`; paste the result.
6. Expected F0 fields:
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
7. After F0 output is accepted, implement F1a `compact_v1` step frame export and indicator de-duplication.
8. After F1a implementation, provide:
   - Copy Time Log before/after timings.
   - Copy Result Validation with `validation_status: match` or exact mismatch details.
   - Copy Step / Copy P0 showing `step_frame_format: compact_v1` and frame policy meta.
   - JSON size comparison.
9. Do not continue strategy acceptance, raw-data cache, result cache, or Rust/other rewrites before F1a is validated.
