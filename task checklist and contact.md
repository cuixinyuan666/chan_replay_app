# task checklist and contact

Branch: origin_vespa_tdx

## Hard rules

- Original `python/chan.py` remains the only Chan calculation engine.
- Flutter/Dart must not recreate Chan FX/BI/SEG/ZS/BSP logic.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Bridge fallback is not accepted as a completed native result.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- Normal Windows workflow uses App-managed bundled Python.
- Validation mode and strategy mode must stay separate.
- No strategy signal may be accepted unless Copy Signal proves source BSPs, native relation range, strict-step visibility, and signal state.
- Speed optimization must not replace chan.py calculation semantics.
- No `fast` / `turbo` / `极速` mode may be accepted without same-request result validation proving no meaningful deviation from original chan.py output.
- Step-frame compact export may change App adapter transport/export shape only; it must not change chan.py core output semantics.
- No Chan result cache is accepted. F1f accepted only a raw K-line cache.

## Latest important commits

- `25a7bbce2d0f2d78ba625d5e591b30d8881578e3`: reuse app-managed Python backend across source/page rebuilds.
- `fbd0a979eb48c181a06b36da5e9c2a926ce6420f`: accept F1d warm backend reuse.
- `773f428864e42766c4368bb839c9e5bb70d92d3d`: accept F1e native timing decomposition.
- `a533a8b9d076e9f3b254b4e5d5568ecc2145be26`: add process-local raw easy-tdx K-line cache diagnostics.
- `8aae12d62a6d7517872274c282e952a06d0cc403`: attach raw data cache stats to native timing meta.
- `59fabc39a5e48f843584fb4b9d10410fd145be5f`: expose raw data cache diagnostics in Time Log meta and stages.
- `5e2a6f5e525908b04bdcbacd6062555e0ce55e6a`: accept F1f raw data cache reuse.
- `ca9c2e100de03b835f3e9f3a1c2105e91d7f8169`: decompose native step export timing.
- `c961f7f2aaf0aca7990420e89e879cdacca6e68d`: surface step export substage timings in Time Log.
- Current update: accept F1g step export decomposition and select F1h compact-first step frame export.

## Current accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A active-route strict step replay: accepted.
- Batch B native `LevelRelation` targeting: accepted for DAILY->MIN30 and MIN30->MIN5.
- Batch C arbitrary BSP pair strict-step validation: accepted using real easy-tdx/original chan.py data.
- P0 Time Log instrumentation: accepted.
- F0 Copy Result Validation blocked gate: accepted.
- F1a compact-v1 transport equivalence: accepted.
- F1b post-compact performance measurement: accepted.
- F1c lazy frame parsing: accepted.
- F1d backend lifecycle diagnostics and warm backend reuse: accepted.
- F1e backend route and native-internal timing decomposition: accepted.
- F1f process-local raw K-line data-load cache reuse: accepted.
- F1g step export sub-stage timing decomposition: accepted.

## Accepted runtime baseline

Accepted test request:

- symbol `600340`, market `SH`.
- levels `DAILY,MIN30,MIN5`.
- count `220`.
- max_step_frames `60`.
- start/end `2025-09-01` to `2025-10-20`.
- mode `step`.
- selected pair `DAILY->MIN30`.
- rule mode `validation_any_bsp_pair`.

## Phase F1a: compact_v1 transport equivalence

Accepted.

- Backend `compact_v1` adapter is implemented at App adapter/export layer.
- Frame-level `bars` and `indicators` are omitted by default.
- Frame-level `visible_count` is preserved.
- Top-level result keeps each level's final bars/indicators once.
- Flutter parser reconstructs visible bars/indicators for display without recalculating Chan structures.
- Backend compact transport validation is accepted with `compact_validation_status: match` and `compact_validation_mismatch_count: 0`.
- This accepts transport equivalence only. It does not accept algorithmic `极速` mode.

## Phase F1b: post-compact measurement

Accepted.

- `response_bytes` remained around `4.06MB`.
- Frontend parse and backend/http round-trip were both major bottlenecks.
- Selected F1c lazy frame parsing.

## Phase F1c: lazy frame parsing

Accepted.

- `lazy_frame_parsing: true`.
- `raw_frame_count: 29`.
- `parsed_frame_count: 1`.
- `frontend.parse.frames: 0ms`.
- Strict step replay still uses backend frames.
- Validation remains match.

## Phase F1d: backend lifecycle diagnostics and warm reuse

Accepted.

- Backend lifecycle fields are visible in Copy Time Log.
- Same-session reload reuses the app-managed Python backend process.
- Warm backend ready drops to health-check time.
- Validation remains match.

## Phase F1e: backend route and native-internal timing decomposition

Accepted.

Visible timing fields:

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

- Before F1f, primary bottleneck was data load.
- Secondary bottleneck was step export.
- Compact transform, JSON serialization probe, and frontend frame parsing were not primary bottlenecks.

## Phase F1f: validated raw K-line data-load cache instrumentation

Accepted.

Implemented:

- Process-local raw K-line cache around `load_easy_tdx_bars`.
- Cache key includes symbol, market, period, adjust, count, start, end.
- Copy Time Log exposes cache diagnostics:
  - `backend_data_cache_enabled`
  - `backend_data_cache_hits`
  - `backend_data_cache_misses`
  - `backend_data_cache_hit_levels`
  - `backend_data_cache_miss_levels`
  - `backend_data_cache_key_count`
  - `backend_data_cache_policy`
  - `backend.data_cache.hits`
  - `backend.data_cache.misses`
  - `backend.data_cache.key_count`

Accepted F1f output:

- First same-session run: cache hits `0`, misses `3`, key_count `3`, `backend.native.data_load: 19137ms`.
- Second same-session run: cache hits `3`, misses `0`, key_count `3`, `backend.native.data_load: 350ms`.
- Validation remained `match`.
- This is raw K-line cache only, not Chan result cache.

## Phase F1g: step export decomposition / refinement

Accepted.

Implemented timing fields:

- `backend.step_export.iter`
- `backend.step_export.frame_build`
- `backend.step_export.level_snapshot`
- `backend.step_export.structure`
- `backend.step_export.visible_bars`
- `backend.step_export.level_payload`
- `backend.step_export.relation`
- `backend.step_export.bsp`
- `backend.step_export.current_time`
- `backend.step_export.total_frames`
- `backend.step_export.returned_frames`
- `backend.step_export.bsp_count`

Runtime accepted F1g output, second warm same-session run:

- `backend_process_pid: 18088`
- `backend_process_start_count: 1`
- `backend_request_count: 2`
- `backend_last_request_reused: true`
- `backend.data_cache.hits: 3`
- `backend.data_cache.misses: 0`
- `backend.native.data_load: 192ms`
- `backend.native.prepare_chan: 202ms`
- `backend.native.step_export: 3056ms`
- `backend.step_export.iter: 1034ms`
- `backend.step_export.frame_build: 1996ms`
- `backend.step_export.level_snapshot: 1836ms`
- `backend.step_export.structure: 332ms`
- `backend.step_export.visible_bars: 64ms`
- `backend.step_export.level_payload: 1374ms`
- `backend.step_export.relation: 115ms`
- `backend.step_export.bsp: 0ms`
- `backend.step_export.current_time: 0ms`
- `backend.step_export.total_frames: 29`
- `backend.step_export.returned_frames: 29`
- `backend.step_export.bsp_count: 8`
- `frontend.total: 5148ms`
- `frontend.http_round_trip: 3899ms`
- `validation_status: match`
- `compact_validation_status: match`
- `fallback_to_bridge: false`
- `native_cchan_lv_list: true`

F1g conclusion:

- After F1f, data load is no longer the bottleneck.
- Step export is now the primary backend bottleneck.
- The largest step export sub-costs are:
  - frame build / level snapshot conversion.
  - level payload construction.
  - step iterator itself.
- `level_payload` is wasteful because compact_v1 later removes frame-level bars and indicators. This suggests compact-first frame export.

Forbidden after F1g remains:

- No algorithmic fast/极速 mode.
- No Chan result cache.
- No Flutter-side Chan calculation.
- No final snapshot slicing fake replay.
- No `python/chan.py` core algorithm change.

## Phase F1h: compact-first step frame export / skip redundant frame payload

Selected next task.

Goal:

- Reduce `backend.native.step_export`, especially `backend.step_export.level_payload`, by building compact frame payloads directly for step frames.
- Preserve strict step replay from backend frames.
- Preserve top-level final snapshot with bars and indicators for chart rendering.
- Preserve compact validation and result validation.

Allowed F1h implementation directions:

1. In step frame export, for frame-level levels build compact payload directly:
   - keep `visible_count`.
   - keep Chan structures: `merged_bars`, `fx`, `bi`, `seg`, `zs`, `bsp`.
   - omit frame-level `bars` and `indicators` without first constructing them.
2. Final top-level snapshot must still include bars and indicators once.
3. Keep `step_frame_format: compact_v1` and compact validation fields.
4. Keep F1f raw data cache diagnostics and F1g step export sub-stage timing visible.

Forbidden in F1h:

- Do not use final snapshot slicing as step replay.
- Do not use Chan result cache.
- Do not implement algorithmic fast/极速 mode.
- Do not move Chan calculations to Flutter.
- Do not change `python/chan.py` core algorithm.

F1h acceptance criteria:

- Copy Time Log shows `backend.step_export.level_payload` materially reduced.
- `backend.native.step_export` should drop versus F1g accepted warm-run baseline (`3056ms`).
- `validation_status: match` and `compact_validation_status: match` remain true.
- `fallback_to_bridge: false` and `native_cchan_lv_list: true` remain true.
- Copy Step remains strict backend step frame, not final snapshot slicing.

## Current blockers / pending verification

- No speed/fast/turbo/极速 mode is accepted yet.
- Strategy mode acceptance remains paused until F1h decision or implementation is complete, unless the manual explicitly resumes strategy first.
- Full-history/paged strict step replay remains deferred.
- Algorithmic fast mode is prohibited until a stricter validation plan is written and accepted.
- Chan result cache remains prohibited.
- F1h compact-first step frame export is now the selected next task.

## Next task-party operation

1. Implement F1h compact-first step frame export in the App adapter/export layer.
2. Keep F1f raw data cache diagnostics and F1g step export timings visible.
3. Re-run the accepted test window twice in the same App session.
4. Paste Copy Time Log, Copy Step, and Copy Result Validation from the warm second run.
5. Accept F1h only if compact validation remains match and step export cost drops without fake step replay.
