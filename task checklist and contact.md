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
- `1ab4b0dfa2a8de48c7e6ae33644e30db31d2b58e`: added backend compact_v1 transport validation meta.
- `0f94fb9012930bef8f75911d3cd1a1e9fb872128`: added `compact_validation_*` fields to Copy P0 and Copy Step diagnostics.
- `958920a489bfb33edc7ba390476a8c38270b10e8`: wired Copy Result Validation to report F1a compact match/mismatch when compact validation meta is present.
- Current update: accepted runtime Copy Result Validation F1a compact transport match and marked F1a compact-v1 transport equivalence accepted.

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
- F1a Copy Time Log compact meta: runtime accepted.
- F1a Copy Result Validation compact meta: runtime accepted for compact fields while F0 remained blocked.
- F1a Copy Step compact meta: runtime accepted.
- F1a Copy P0 compact meta: runtime accepted.
- F1a backend compact transport validation in Copy P0 / Copy Step: runtime accepted with `compact_validation_status: match` and `compact_validation_mismatch_count: 0`.
- F1a Copy Result Validation compact transport equivalence: runtime accepted with `validation_phase: F1a`, `validation_status: match`, `mismatch_count: 0`, and `status: ok`.
- F1a compact-v1 transport equivalence: accepted.

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
- Runtime F0 blocked output was accepted before compact validation existed.
- F0 remains the fallback output only when no compact validation fields are present.
- `极速` mode remains not accepted and not implemented.

## Phase F1a: step frames compact_v1 export and indicator de-duplication

Goal:

- Optimize App backend step / multi-level step export format without modifying original `chan.py` FX/BI/SEG/ZS/BSP calculation logic.
- Continue using original step semantics, especially `CChanConfig(trigger_step=True)` and `CChan.step_load()` or equivalent original chan.py step output.
- Reduce repeated JSON, repeated K-line arrays, repeated indicator arrays, and unnecessary frontend parsing.
- Preserve final chart and diagnostic equivalence with the pre-optimization baseline.

Implemented:

- `backend/app/main.py` wraps `/api/chan/analyze_multi` step responses at the App adapter/export layer.
- `compact_v1` default frame-level behavior:
  - `include_bars_in_frames=false`.
  - `include_indicators_in_frames=false`.
  - frame-level payload keeps current-frame structures from original chan.py output.
  - frame-level payload adds `visible_count`.
  - top-level result keeps each level's final bars/indicators once.
- Backend meta includes compact fields when step response is compacted:
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
- Each compact_v1 frame meta also carries:
  - `frames_total`
  - `frames_returned`
  - `frames_truncated`
  - `max_return_frames`
- Backend adapter-level compact transport validation is implemented and accepted:
  - `compact_validation_scope: backend_precompact_vs_compact_transport`
  - `compact_validation_status: match`
  - `compact_validation_mismatch_count: 0`
  - `compact_validation_first_mismatch:` blank.
  - Validation checks `visible_count`, bars/indicators removal switches, and `merged_bars/fx/bi/seg/zs/bsp` list count preservation.
  - This validation does not recalculate Chan structures.
- `lib/data/multi_level_chan_analysis_parser.dart` supports compact_v1 frames:
  - If a frame level omits `bars` and includes `visible_count`, parser reconstructs visible bars from top-level level bars.
  - If a frame level omits `indicators`, parser clips top-level indicators up to `visible_count`.
  - Old full frame format remains supported.
- `lib/data/python_multi_level_chan_analysis_source.dart` passes top-level `levels` into the compact frame parser.
- `lib/ui/widgets/multi_level_interval_signal_panel.dart` prints compact meta, keeps response bytes separate from timing stages, and reports F1a compact validation match/mismatch in `Copy Result Validation`.
- `lib/ui/pages/multi_level_replay_page.dart` adds compact meta and compact validation fields to `Copy P0` and `Copy Step` diagnostics.

Runtime accepted F1a outputs:

- Copy P0 compact meta accepted.
- Copy Step compact meta accepted.
- Time Log compact meta and `response_bytes` accepted.
- Copy P0 / Copy Step compact validation accepted.
- Copy Result Validation F1a compact validation accepted:
  - `validation_phase: F1a`
  - `validation_scope: backend_precompact_vs_compact_transport`
  - `compact_candidate_enabled: true`
  - `compact_candidate_source: compact_v1 transport adapter`
  - `validation_status: match`
  - `mismatch_count: 0`
  - `first_mismatch:` blank.
  - `status: ok`.

F1a acceptance status:

- Backend compact_v1 adapter: accepted.
- Flutter compact_v1 parser compatibility: accepted.
- Response bytes timing: accepted.
- Copied Time Log / Result Validation compact meta: accepted.
- Compact frame total propagation: accepted.
- Copy P0 / Copy Step compact meta fields: accepted.
- Backend compact transport validation meta: accepted.
- Copy P0 / Copy Step compact validation fields: accepted.
- Copy Result Validation F1a match/mismatch wiring: accepted.
- F1a compact-v1 transport equivalence: accepted.

Important limitation:

- This accepts only compact transport equivalence. It does not accept algorithmic `极速` mode.
- `极速` mode remains not implemented, not exposed, and not accepted.
- Any later algorithmic fast path still requires validation_status=match for the same request and must respect original chan.py as calculation authority.

## Current blockers / pending verification

- Strategy mode acceptance remains paused unless the next manual task explicitly resumes it.
- Full-history/paged strict step replay remains deferred unless the next manual task selects it.
- No speed/fast/turbo/极速 mode is accepted yet.
- The current manual has no explicit next implementation phase after F1a; next work must be added to this manual before coding.

## Next task-party operation

1. Do not start algorithmic speed mode merely because F1a compact transport equivalence is accepted.
2. Select and document the next phase in this manual before implementation.
3. Candidate next phases mentioned earlier but not yet selected:
   - Strategy mode runtime acceptance.
   - Full-history / paged strict step replay.
   - Additional backend Time Log granularity.
   - Algorithmic fast mode only after a stricter result validation plan is written and accepted.
