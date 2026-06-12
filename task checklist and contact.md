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
- `94f1ef2ac820f197905a2abd2a53174fffb29874`: accepted F1c lazy frame parsing runtime verification and selected F1d backend lifecycle / round-trip diagnostics.
- `fddda9c97c449fa9b3fd0b08eadf82776844b1b5`: exposed app-managed backend lifecycle diagnostics.
- `7caa0c0e24f8b8286303d50035c087518be1a9a4`: included backend lifecycle diagnostics in Time Log.
- `4b08bc5c2906b513872c1d0fd9a4861e59c6167c`: printed backend lifecycle fields in Copy Time Log.
- `25a7bbce2d0f2d78ba625d5e591b30d8881578e3`: reused the app-managed Python backend process across source/page rebuilds.
- `fbd0a979eb48c181a06b36da5e9c2a926ce6420f`: accepted F1d warm backend reuse and selected F1e backend compute/export/http decomposition.
- `e47a0157086d67e641acef775913c22b65eeb9a5`: added route-level timing metadata for `/api/chan/analyze_multi`.
- `3eb51f85105f8b0584293c588cb638ec24b71ca1`: surfaced backend route timing stages in Copy Time Log.
- `58e55919f72711b8689bb058aecdb912235e3b2f`: added timed native multi-level wrapper.
- `2820362f6eebca6ef0392bdfc17991c62bc5756c`: added timed multi-level analysis entrypoint.
- `8302b6cfe618ff15fa46bc56d452c50ebf66b088`: routed FastAPI analyze_multi through the timed entrypoint.
- `db5b94a93e86e02b30282fe247359e686bff1cc8`: preserved scanner stream iterator invocation after the timed-entrypoint patch.
- `e9c5dcf84b29962df1eb7304b103cb50d9940090`: removed invalid timed-wrapper diagnostic import and fixed backend startup crash.
- `773f428864e42766c4368bb839c9e5bb70d92d3d`: accepted F1e native timing decomposition and selected F1f validated data-load reuse/cache instrumentation.
- `a533a8b9d076e9f3b254b4e5d5568ecc2145be26`: added process-local raw easy-tdx K-line cache diagnostics.
- `8aae12d62a6d7517872274c282e952a06d0cc403`: attached raw data cache stats to native timing meta.
- `59fabc39a5e48f843584fb4b9d10410fd145be5f`: exposed raw data cache diagnostics in Time Log meta and stages.
- Current update: accepted F1f raw data cache reuse and selected F1g step export decomposition/refinement.

## Current accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A active-route strict step replay: accepted for current lightweight/runtime route.
- Batch B native `LevelRelation` targeting: accepted for DAILY->MIN30 and MIN30->MIN5.
- Batch C arbitrary BSP pair strict-step validation: accepted using real easy-tdx/original chan.py data.
- Legacy `OriginReplayPageV2` / `_sliceSnapshot` blocker: cleared by code search.
- P0 Time Log normal step Load path: runtime accepted.
- P0 Time Log Scan Signal / once path: runtime accepted.
- P0 Time Log interval-panel step timing path: runtime accepted.
- P0 Time Log strategy context with explicit rule fields: runtime accepted by user-provided log.
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
- F1d backend lifecycle diagnostics and warm backend reuse: runtime accepted.
- F1e backend route and native-internal timing decomposition: runtime accepted.
- F1f process-local raw K-line data-load cache reuse: runtime accepted.

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
- Runtime F0 blocked output was accepted before compact validation existed.
- F0 remains the fallback output only when no compact validation fields are present.
- `极速` mode remains not accepted and not implemented.

## Phase F1a: step frames compact_v1 export and indicator de-duplication

Accepted.

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
- This accepts only compact transport equivalence. It does not accept algorithmic `极速` mode.

## Phase F1b: compact performance re-measurement and cache-readiness analysis

Accepted.

Accepted F1b measurement output showed:

- `response_bytes: 4059073`.
- `frontend.http_round_trip: 10879ms`.
- `frontend.parse.snapshot_frames_relations_bsp: 11142ms`.
- `frontend.backend_ready: 4726ms`.

F1b selected F1c because frontend parse was still as large as backend/http round-trip.

## Phase F1c: compact payload refinement / frame paging / lazy frame parsing

Accepted.

- `lazy_frame_parsing: true`.
- `raw_frame_count: 29`.
- `parsed_frame_count: 1`.
- `frontend.parse.frames: 0ms`.
- Compact transport validation remained accepted.
- No `python/chan.py` core logic changed.

## Phase F1d: backend lifecycle / round-trip diagnostics and warm backend reuse

Accepted.

- App-managed backend lifecycle diagnostics implemented.
- Backend process is shared across source/page rebuilds.
- Second same-session load reused the same backend process.
- `frontend.backend_ready` dropped to about `162ms` in the accepted warm run.
- Validation remained `match`.

## Phase F1e: backend route and native-internal timing decomposition

Accepted.

- Backend route timing metadata implemented.
- Native timing metadata implemented.
- Copy Time Log surfaces:
  - `backend.route.analyze_multi`
  - `backend.route.compact_transform`
  - `backend.route.json_serialize_probe`
  - `backend.route.total_before_response`
  - `backend.native.data_load`
  - `backend.native.prepare_chan`
  - `backend.native.step_export`
  - `backend.native.once_export`
  - `backend.native.total`

F1e conclusion:

- Primary bottleneck before F1f was data loading.
- Secondary bottleneck was step export.
- Compact transform, JSON serialization probe, and frontend frame parsing were not the main bottlenecks.

## Phase F1f: validated raw K-line data-load cache instrumentation

Accepted.

Goal:

- Reduce repeated same-session `backend.native.data_load` cost while preserving original chan.py calculation semantics.
- Add raw K-line cache only; no Chan result cache.
- Surface cache hit/miss diagnostics in Copy Time Log.

Implemented:

- Process-local raw K-line cache around `load_easy_tdx_bars`.
- Cache key includes:
  - symbol
  - market
  - period
  - adjust
  - count
  - start
  - end
- Per-request cache diagnostics:
  - `backend_data_cache_enabled`
  - `backend_data_cache_hits`
  - `backend_data_cache_misses`
  - `backend_data_cache_hit_levels`
  - `backend_data_cache_miss_levels`
  - `backend_data_cache_key_count`
  - `backend_data_cache_policy`
- Time Log stages include:
  - `backend.data_cache.hits`
  - `backend.data_cache.misses`
  - `backend.data_cache.key_count`

Runtime accepted F1f output:

- First same-session run:
  - `backend.data_cache.hits: 0`
  - `backend.data_cache.misses: 3`
  - `backend.data_cache.key_count: 3`
  - `backend.native.data_load: 19137ms`
  - `backend.native.step_export: 6199ms`
  - `validation_status: match`
- Second warm same-session run:
  - `backend_process_pid: 7032`
  - `backend_process_start_count: 1`
  - `backend_request_count: 2`
  - `backend_last_request_reused: true`
  - `backend.data_cache.hits: 3`
  - `backend.data_cache.misses: 0`
  - `backend.data_cache.key_count: 3`
  - `backend.native.data_load: 350ms`
  - `backend.native.step_export: 3735ms`
  - `frontend.http_round_trip: 5179ms`
  - `frontend.total: 6632ms`
  - `validation_status: match`
  - `compact_validation_status: match`
  - `fallback_to_bridge: false`
  - `native_cchan_lv_list: true`

F1f effect:

- `backend.native.data_load` dropped from `19137ms` to `350ms` in the accepted same-session warm run.
- Warm-run total dropped to about `6632ms`.
- The remaining main backend bottleneck became `backend.native.step_export: 3735ms`.
- Validation remained `match`.
- This is raw K-line cache only, not Chan result cache.

Forbidden after F1f remains:

- No Chan result cache.
- No algorithmic fast/极速 mode.
- No Flutter-side Chan calculation.
- No stale data reuse without visible key/policy diagnostics.

## Phase F1g: step export decomposition / refinement

Selected next task.

Goal:

- Split and reduce `backend.native.step_export` without changing chan.py calculation semantics.
- Preserve strict step replay from backend step frames.
- Keep compact validation and result validation visible and passing.

Allowed F1g implementation directions:

1. Add internal timing inside step export:
   - `backend_step_export_iter_ms`
   - `backend_step_export_frame_build_ms`
   - `backend_step_export_relation_ms`
   - `backend_step_export_level_snapshot_ms`
   - `backend_step_export_bsp_ms`
   - `backend_step_export_total_frames`
2. Identify whether cost is from iterating `chan.step_load()`, converting snapshots, relations, BSP extraction, or building full frame dictionaries.
3. Keep lazy frontend parsing.
4. Keep compact frame transport validation.

Potential later optimization after decomposition:

- frame-window / latest-frame export for UI startup, with explicit non-full strict-replay labeling.
- separate on-demand full strict frame load.

Forbidden in F1g:

- Do not implement algorithmic fast/极速 mode.
- Do not use Chan result cache.
- Do not fake step replay from final snapshot.
- Do not change `python/chan.py` core algorithm.
- Do not drop compact validation or result validation.

F1g acceptance criteria:

- Copy Time Log must show step export sub-stage timing fields.
- Warm backend reuse and raw data cache hit diagnostics must remain visible.
- `validation_status: match` and `compact_validation_status: match` must remain true.
- `fallback_to_bridge: false` and `native_cchan_lv_list: true` must remain true.

## Current blockers / pending verification

- No speed/fast/turbo/极速 mode is accepted yet.
- Strategy mode acceptance remains paused until F1g decision or implementation is complete, unless the manual explicitly resumes strategy first.
- Full-history/paged strict step replay remains deferred.
- Algorithmic fast mode is prohibited until a stricter validation plan is written and accepted.
- Chan result cache remains prohibited.
- F1g step export decomposition/refinement is now the selected next task.

## Next task-party operation

1. Implement F1g step export sub-stage timing in the App adapter/export layer.
2. Keep F1f raw data cache diagnostics visible.
3. Re-run the accepted test window twice in the same App session.
4. Paste Copy Time Log, Copy P0, Copy Step, and Copy Result Validation from the warm second run.
5. Accept F1g only if step export sub-stage timing is visible and validation remains match.
