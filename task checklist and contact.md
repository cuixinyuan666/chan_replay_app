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
- After any transport optimization is accepted, the next step must include performance re-measurement before adding a deeper cache or algorithmic fast path.

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
- `f635f70b38848857ef28c7a24efa32b3abbe07ad`: accepted runtime Copy Result Validation F1a compact transport match and marked F1a compact-v1 transport equivalence accepted.
- `f2e3cacc341361afaaa6e221b6bf8c324e5e9f36`: accepted F1b post-compact measurements and selected F1c compact payload refinement / frame paging / lazy frame parsing as the next task.
- `e0a2f1c0a251b0985c4d804ea2f359bb4d3f96fa`: split multi-level frontend parse timing into top snapshot, frames, and interval signal stages.
- `6b12a5123cd24a86330b7823428542f9819e23c7`: exposed single compact frame parser for lazy loading.
- `68cf4e42aa22608fce78f9497a1d6207e5880449`: implemented lazy parsing for compact_v1 multi-level step frames.
- `ca3cce4699e12240788f9d9abfbf59150b263c95`: printed lazy frame counters in Copy Time Log.
- Current update: accepted F1c lazy frame parsing runtime verification and selected F1d backend lifecycle / round-trip diagnostics as the next phase.

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
- F1a Copy Result Validation compact meta: runtime accepted.
- F1a Copy Step compact meta: runtime accepted.
- F1a Copy P0 compact meta: runtime accepted.
- F1a backend compact transport validation in Copy P0 / Copy Step: runtime accepted with `compact_validation_status: match` and `compact_validation_mismatch_count: 0`.
- F1a Copy Result Validation compact transport equivalence: runtime accepted with `validation_phase: F1a`, `validation_status: match`, `mismatch_count: 0`, and `status: ok`.
- F1a compact-v1 transport equivalence: accepted.
- F1b post-compact performance measurement: accepted and classified.
- F1c lazy frame parsing: runtime accepted.

## P0 Time Log instrumentation

Implemented and accepted:

- Metadata path implemented in `lib/data/python_multi_level_chan_analysis_source.dart`.
- `Copy Time Log` implemented in `lib/ui/widgets/multi_level_interval_signal_panel.dart`.
- Runtime step Load Time Log accepted.
- Runtime Scan Signal / once Time Log accepted.
- Runtime strategy context Time Log with explicit rule fields accepted.
- P0 Time Log fully accepted.

Accepted timing before compact_v1 showed repeated bottlenecks:

- Step end-to-end around `26s-33s` for the accepted `600340 / SH / DAILY,MIN30,MIN5 / 2025-09-01 to 2025-10-20 / count=220 / max_step_frames=60` window.
- Backend HTTP/compute around `10s-12s`.
- Frontend parse around `10s-14s`.
- Backend ready around `4s-5s`.
- Step was much heavier than once because step returned many frame structures.

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

Accepted as compact transport equivalence:

- Backend `compact_v1` adapter is implemented at App adapter/export layer.
- Frame-level `bars` and `indicators` are omitted by default.
- Frame-level `visible_count` is preserved.
- Top-level result keeps each level's final bars/indicators once.
- Flutter parser reconstructs visible bars/indicators for display without recalculating Chan structures.
- Backend compact transport validation is accepted:
  - `compact_validation_scope: backend_precompact_vs_compact_transport`
  - `compact_validation_status: match`
  - `compact_validation_mismatch_count: 0`
  - `compact_validation_first_mismatch:` blank.
- Copy Result Validation F1a accepted:
  - `validation_phase: F1a`
  - `validation_scope: backend_precompact_vs_compact_transport`
  - `compact_candidate_enabled: true`
  - `compact_candidate_source: compact_v1 transport adapter`
  - `validation_status: match`
  - `mismatch_count: 0`
  - `first_mismatch:` blank.
  - `status: ok`.

Important limitation:

- This accepts only compact transport equivalence. It does not accept algorithmic `极速` mode.
- `极速` mode remains not implemented, not exposed, and not accepted.
- Any later algorithmic fast path still requires validation_status=match for the same request and must respect original chan.py as calculation authority.

## Phase F1b: compact performance re-measurement and cache-readiness analysis

Accepted F1b post-compact measurement window:

- symbol `600340`, market `SH`.
- levels `DAILY,MIN30,MIN5`.
- count `220`.
- max_step_frames `60`.
- start/end `2025-09-01` to `2025-10-20`.
- mode `step`.

Accepted F1b measurement output:

- `step_frame_format: compact_v1`.
- `frames_total: 29`.
- `frames_returned: 29`.
- `frames_truncated: false`.
- `include_bars_in_frames: false`.
- `include_indicators_in_frames: false`.
- `response_bytes: 4059073`.
- `total_elapsed_ms: 26885`.
- `backend_elapsed_ms: 10879`.
- `frontend_elapsed_ms: 26885`.
- `frontend.http_round_trip: 10879ms`.
- `frontend.body_decode: 17ms`.
- `frontend.json_decode: 114ms`.
- `frontend.parse.snapshot_frames_relations_bsp: 11142ms`.
- `frontend.backend_ready: 4726ms`.
- Result Validation remained `validation_status: match`, `mismatch_count: 0`, and `status: ok`.

F1b bottleneck classification:

- Frontend parse remains the largest explicit stage after total time: `11142ms`.
- HTTP/backend round-trip remains very high: `10879ms`.
- Response bytes remain large: about `4.06MB` for only 29 frames.
- JSON decode is not the main bottleneck: `114ms`.
- Body decode is not the main bottleneck: `17ms`.
- Backend startup/ready is visible but not the primary bottleneck: `4726ms`.

F1b decision:

- Select **F1c compact payload refinement / frame paging / lazy frame parsing**.
- Do not select raw-data cache yet, because frontend parse remains as large as backend/http round-trip.
- Do not select backend lifecycle as the primary next task, because backend_ready was smaller than parse and http round-trip at that stage.
- Do not select strategy/signal fast reuse yet, because the measured slow path is initial step load and frame parse.
- Do not start algorithmic fast/极速 mode.

## Phase F1c: compact payload refinement / frame paging / lazy frame parsing

Accepted.

Goal:

- Reduce frontend parse time and payload/step-frame overhead without changing original `chan.py` calculation logic.
- Keep strict step replay backed by native backend frames.
- Keep compact validation gate visible and passing.
- Avoid loading/parsing all heavy frame snapshots eagerly when only the first/current frame is needed.

Implemented:

- Split frontend parse timing into:
  - `frontend.parse.top_snapshot`
  - `frontend.parse.frames`
  - `frontend.parse.interval_signals`
  - `frontend.parse.snapshot_frames_relations_bsp`
- Added `MultiLevelChanAnalysisParser.parseFrame(...)` for single-frame compact parsing.
- Added lazy frame list for compact_v1 step responses.
- Initial response parse now parses top-level snapshot and interval signals eagerly, while compact frames are parsed on first access and cached.
- Copy Time Log explicitly prints lazy counters:
  - `raw_frame_count`
  - `parsed_frame_count`
  - `parsed_level_count`
  - `lazy_frame_parsing`
  - `lazy_frame_cache_hits`
  - `lazy_frame_cache_misses`
  - `lazy_frame_parse_ms`
  - `lazy_frame_last_index`
  - `lazy_frame_last_parse_ms`

Runtime accepted F1c output:

- `lazy_frame_parsing: true`.
- `raw_frame_count: 29`.
- `parsed_frame_count: 1`.
- `parsed_level_count: 3`.
- `lazy_frame_cache_hits: 7`.
- `lazy_frame_cache_misses: 1`.
- `lazy_frame_parse_ms: 44`.
- `lazy_frame_last_index: 0`.
- `lazy_frame_last_parse_ms: 44`.
- `frontend.parse.frames: 0ms`.
- `frontend.parse.snapshot_frames_relations_bsp: 1285ms`.
- `frontend.parse.top_snapshot: 1284ms`.
- `Copy P0` remained native and compact:
  - `strict_step_blocked: false`
  - `native_cchan_lv_list: true`
  - `fallback_to_bridge: false`
  - `frames.length: 29`
  - `step_frame_format: compact_v1`
  - `compact_validation_status: match`
- `Copy Step` remained strict step:
  - `frame_source: native_step_frame`
  - `final_snapshot_rendered_as_step: false`
  - `native_cchan_lv_list: true`
  - `fallback_to_bridge: false`
  - `frame.number.local: 1/29`
  - `status_summary.current_frame` remains different from final snapshot.

F1c effect:

- Before lazy frame parsing, `frontend.parse.frames` was `13396ms` and `frontend.parse.snapshot_frames_relations_bsp` was `14763ms`.
- After lazy frame parsing, `frontend.parse.frames` is `0ms` and `frontend.parse.snapshot_frames_relations_bsp` is about `1196ms-1285ms`.
- Compact transport validation remains accepted.
- No `python/chan.py` core logic changed.

Remaining bottleneck after F1c:

- Backend/http round trip remains high, around `9s-13s`.
- Backend ready/startup can be high, observed at `3.5s-9.1s`.
- Response bytes remain about `4.06MB`.
- Frontend frame parsing is no longer the primary bottleneck.

Forbidden after F1c remains:

- Do not modify `python/chan.py` core algorithm.
- Do not calculate FX/BI/SEG/ZS/BSP in Flutter.
- Do not expose `极速` as accepted.
- Do not drop relation/BSP diagnostics.
- Do not hide that paging/stride is not full strict replay.

## Phase F1d: backend lifecycle / round-trip diagnostics and warm backend reuse

Selected next task.

Goal:

- Determine whether the remaining `frontend.backend_ready` and `frontend.http_round_trip` cost comes from backend startup, backend compute, data fetch, serialization, HTTP transfer, or frontend request lifecycle.
- Reduce avoidable backend startup/restart overhead in normal Windows App-managed bundled Python workflow.
- Preserve original `chan.py` calculation semantics.

Allowed F1d implementation directions:

1. Add backend lifecycle diagnostics:
   - backend process pid.
   - backend process start count.
   - backend reused vs newly started.
   - backend uptime before request.
   - health-check elapsed ms.
2. Split backend/http timing further:
   - frontend backend_ready start/reuse/health ms.
   - backend compute ms from server meta if available.
   - serialization / compact adapter ms if available.
3. Keep backend warm across repeated requests where safe:
   - Do not spawn a new backend process for each request.
   - Reuse existing app-managed backend when healthy.
4. Preserve validation:
   - Copy Result Validation must remain match.
   - Copy P0 and Copy Step must remain native and strict-step based.

Forbidden in F1d:

- Do not implement algorithmic fast/极速 mode.
- Do not add result cache unless a separate validation plan is written.
- Do not bypass original `chan.py`.
- Do not hide backend fallback.

F1d acceptance criteria:

- Copy Time Log must show backend lifecycle fields and split backend_ready/reuse health timing.
- Repeated same-window load should show whether backend process is reused.
- Copy Result Validation must remain `validation_status: match`.
- Copy P0 / Copy Step must remain native, compact, and strict-step based.

## Current blockers / pending verification

- No speed/fast/turbo/极速 mode is accepted yet.
- Strategy mode acceptance remains paused until F1d decision or implementation is complete, unless the manual explicitly resumes strategy first.
- Full-history/paged strict step replay remains deferred.
- Algorithmic fast mode is prohibited until a stricter validation plan is written and accepted.
- F1d backend lifecycle / round-trip diagnostics is now the selected next task.

## Next task-party operation

1. Implement F1d backend lifecycle diagnostics without changing `chan.py`.
2. Add Time Log fields for backend process reuse/start/health timing.
3. Re-run the accepted test window twice in the same App session.
4. Paste Copy Time Log, Copy P0, Copy Step, and Copy Result Validation from both runs if possible.
5. Accept F1d only if backend lifecycle state is visible and validation remains match.
