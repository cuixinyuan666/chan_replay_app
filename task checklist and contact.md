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
- `16e31fb85d2eed3b259701b7cb58d4c1c3ca1b7c`: accepted user-provided F0 blocked validation output and promoted F1a as current task.
- `b424b9baf7d66b00f95d62b5347929fbe9a8120a`: added backend App adapter `compact_v1` wrapping for multi-level step frames.
- `45355548d52e2860dc5f0b8e9d84a8e8eca20064`: added Flutter parser compatibility for compact_v1 frames.
- `5279e912dbaee634072f20e3b5efc74fd1fe91b4`: passed top-level levels into compact parser and added `frontend.response_bytes` to Time Log stages.
- `7992b7a6d950999ff3a2b41008480228969d1395`: fixed copied Time Log/Result Validation diagnostics so `response_bytes` is printed as bytes and not sorted as milliseconds; added compact meta fields to copied Time Log and Result Validation.
- `6ada07e1bb464ce1bf8a0710137e399d35cf7721`: propagated compact frame total fields into every compact_v1 frame meta.
- `231a9b07b67d107a0e7fc142e0e2a1b66637f14d`: added compact_v1 meta fields to Copy P0 and Copy Step diagnostics.
- Current update: recorded Copy P0 / Copy Step compact meta implementation; runtime validation is pending.

## Current accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A active-route strict step replay: accepted for current lightweight/runtime route.
- Batch B native `LevelRelation` targeting: accepted for DAILY->MIN30 and MIN30->MIN5.
- Batch C arbitrary BSP pair strict-step validation: accepted using real easy-tdx/original chan.py data.
- Legacy `OriginReplayPageV2` / `_sliceSnapshot` blocker: cleared by code search.
- P0 Time Log normal step Load path: runtime accepted.
- P0 Time Log Scan Signal / once path: runtime accepted.
- P0 Time Log interval-panel step timing path: runtime accepted.
- P0 Time Log strategy context with explicit fields: runtime accepted by user-provided log.
- F0 Copy Result Validation blocked gate: runtime accepted.

## P0 Time Log instrumentation

Implemented and accepted:

- Metadata path implemented in `lib/data/python_multi_level_chan_analysis_source.dart`.
- `Copy Time Log` implemented in `lib/ui/widgets/multi_level_interval_signal_panel.dart`.
- Runtime step Load Time Log accepted.
- Runtime Scan Signal / once Time Log accepted.
- Runtime strategy context Time Log with explicit rule fields accepted.
- P0 Time Log fully accepted.

Accepted timing showed repeated bottlenecks:

- Step end-to-end around `26s-33s` for the accepted `600340 / SH / DAILY,MIN30,MIN5 / 2025-09-01 to 2025-10-20 / count=220 / max_step_frames=60` window.
- Backend HTTP/compute around `10s-12s`.
- Frontend parse around `10s-14s`.
- Backend ready around `4s-5s`.
- Step is much heavier than once because step returns many frame structures.

## F0 Result Validation foundation

Implemented in `lib/ui/widgets/multi_level_interval_signal_panel.dart`:

- Added visible `Copy Result Validation` button next to `Copy Signal` and `Copy Time Log`.
- Current implementation does not enable any fast candidate.
- Current output reports `validation_status: blocked`, which is expected when no fast candidate exists.

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
- baseline.level_count: `3`
- baseline.relation_count.total: `9`
- baseline.relation_count.selected_pair: `1`
- baseline.signal_count.current_rule: `0`
- validation_status: `blocked`
- status: `blocked`

F0 acceptance status:

- UI/action implemented.
- Runtime Copy Result Validation output accepted.
- `validation_status: blocked` is expected because no fast candidate exists.
- `极速` mode remains not accepted and not implemented.
- F1a compact_v1 work may start.

## Phase F1a: step frames compact_v1 export and indicator de-duplication

Current priority after F0 acceptance.

Goal:

- Optimize App backend step / multi-level step export format without modifying original `chan.py` FX/BI/SEG/ZS/BSP calculation logic.
- Continue using original step semantics, especially `CChanConfig(trigger_step=True)` and `CChan.step_load()` or equivalent original chan.py step output.
- Reduce repeated JSON, repeated K-line arrays, repeated indicator arrays, and unnecessary frontend parsing.
- Preserve final chart and diagnostic equivalence with the pre-optimization baseline.

First implementation batch completed:

- `backend/app/main.py` wraps `/api/chan/analyze_multi` step responses at the App adapter/export layer.
- `compact_v1` default frame-level behavior:
  - `include_bars_in_frames=false`.
  - `include_indicators_in_frames=false`.
  - frame-level payload keeps current-frame structures from original chan.py output.
  - frame-level payload adds `visible_count`.
  - top-level result keeps each level's final bars/indicators once.
- Backend meta now includes compact fields when step response is compacted:
  - `step_frame_format: compact_v1`
  - `frame_policy`
  - `frame_stride`
  - `frame_start`
  - `frame_end`
  - `frames_total`
  - `frames_returned`
  - `frames_truncated`
  - `max_return_frames`
  - `include_bars_in_frames`
  - `include_indicators_in_frames`
  - `compact_transport_only: true`
  - `chan_py_core_unchanged: true`
- Each compact_v1 frame meta now also carries:
  - `frames_total`
  - `frames_returned`
  - `frames_truncated`
  - `max_return_frames`
- `lib/data/multi_level_chan_analysis_parser.dart` now supports compact_v1 frames:
  - If a frame level omits `bars` and includes `visible_count`, parser reconstructs visible bars from top-level level bars.
  - If a frame level omits `indicators`, parser clips top-level indicators up to `visible_count`.
  - Old full frame format remains supported.
- `lib/data/python_multi_level_chan_analysis_source.dart` now passes top-level `levels` into the compact frame parser.
- `lib/ui/widgets/multi_level_interval_signal_panel.dart` now prints compact meta and keeps response bytes separate from timing stages in copied logs.
- `lib/ui/pages/multi_level_replay_page.dart` now adds compact meta fields to `Copy P0` and `Copy Step` diagnostics:
  - `step_frame_format`
  - `frame_policy`
  - `frame_stride`
  - `frames_total`
  - `frames_returned`
  - `frames_truncated`
  - `max_return_frames`
  - `include_bars_in_frames`
  - `include_indicators_in_frames`
  - `compact_transport_only`
  - `chan_py_core_unchanged`

First compact_v1 runtime diagnostic findings from user:

- App still loaded step mode successfully after compact_v1 implementation.
- Copy P0 still reported native CChan/lv_list true, chan parent-child relations, fallback false, frames present, and final structures available.
- Copy Step still rendered frame `0/29` with visible frame structures and no final-snapshot-as-step fallback.
- Time Log after `7992b7a6...` correctly printed `response_bytes=4051090` as bytes and no longer put `frontend.response_bytes` inside `slowest_stages`.
- Time Log / Result Validation showed `step_frame_format=compact_v1`, `frame_policy=full`, `frame_stride=1`, `include_bars_in_frames=false`, and `include_indicators_in_frames=false`.
- After `6ada07e1...`, Time Log / Result Validation also showed `frames_total=29`, `frames_returned=29`, and `frames_truncated=false`.
- Copy P0 / Copy Step compact meta output is implemented but not runtime-verified yet.

F1a implementation status:

- Backend compact_v1 adapter: implemented.
- Flutter compact_v1 parser compatibility: implemented.
- Response bytes timing: implemented.
- Copied Time Log / Result Validation compact meta: implemented and runtime-proven.
- Compact frame total propagation: implemented and runtime-proven.
- Copy P0 / Copy Step compact meta fields: implemented, pending runtime verification.
- Compact-v1 result equivalence is not accepted yet.
- `极速` mode remains not accepted and not exposed.

Forbidden for F1a remains:

- Modify `chan.py` core FX/BI/SEG/ZS/BSP logic.
- Recalculate Chan structures in Flutter/Dart.
- Drop `is_sure=false` structures for speed unless explicitly part of an accepted UI filter that does not affect diagnostics.
- Drop BSP types for speed.
- Pretend `stride` replay is full strict step replay.
- Continue writing `bars[:i+1]` into every frame by default.
- Continue writing full indicators into every frame by default.
- Hide mismatch between compact output and baseline output.

## Current blockers / pending verification

- Re-run `flutter analyze` after `231a9b07b67d107a0e7fc142e0e2a1b66637f14d`.
- Runtime compact_v1 Copy P0 and Copy Step outputs must be pasted after compact meta additions.
- Copy P0 / Copy Step must show `step_frame_format: compact_v1`, `include_bars_in_frames: false`, `include_indicators_in_frames: false`, `frames_total`, `frames_returned`, and `frames_truncated`.
- Result Validation for compact-v1 equivalence remains pending.
- Strategy mode acceptance remains paused while F1a remains current priority.
- Full-history/paged strict step replay remains deferred, but F1a/F4 are the planned path toward scalable strict replay.
- No speed mode is accepted yet.

## Next task-party operation

1. Run `git pull`.
2. Run `flutter analyze`.
3. Open multi-level page and perform normal step Load with accepted test window:
   - symbol `600340`, market `SH`
   - levels `DAILY,MIN30,MIN5`
   - count `220`
   - max_step_frames `60`
   - start/end `2025-09-01` to `2025-10-20`
4. Paste Copy P0.
5. Paste Copy Step.
6. Expected fixed fields in both outputs:
   - `step_frame_format: compact_v1`
   - `include_bars_in_frames: false`
   - `include_indicators_in_frames: false`
   - `frames_total: 29` or another non-empty value.
   - `frames_returned: 29` or another non-empty value.
   - `frames_truncated: false` or another explicit value.
7. If this passes, next code task is compact-v1 result equivalence comparison.
