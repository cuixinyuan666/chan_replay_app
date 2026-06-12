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
- F1j is the final planned diagnostic pass of the current performance chain. After F1j, stop performance work by default and return to the business task chain unless the explicit exception rule below is met.

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
- `4860e0ee5aa54b22da19978eb4ef2e93388f6690`: accept F1g step export decomposition.
- `707ceb8ca439d8eddc05bd17f072e7e4a5c1fcab`: export compact step frames directly.
- `2680cb1e60b9a8182bf521a07d4457b7155c595a`: expose compact-first step export flags and final snapshot timing.
- `31af043bd41298e9a643d036b6716d53180b7ee3`: accept F1h compact-first step export.
- `8018efeee26b57f3a657e647ae9ed7bb30f63d8f`: split backend structure export timings.
- `89afef251c8de84d1fc5acf0d01acb262ce7f782`: surface structure export substage timings.
- `82f0dc610ed41012b5c8d7142917e4c77cd5f47f`: surface frontend top snapshot parse timings for F1j diagnostics. This is implementation progress only; F1j runtime acceptance is still pending.
- Current update: add a performance-chain stop rule after F1j and require returning to the business task chain unless a strict exception is proven.

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
- F1h compact-first step frame export: accepted.
- F1i backend residual structure-export decomposition: accepted.
- F1j frontend top snapshot parse timing visibility: implementation progress only, not accepted until runtime Copy Time Log and validation output are pasted.

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

- Process-local raw K-line cache around `load_easy_tdx_bars`.
- Cache key includes symbol, market, period, adjust, count, start, end.
- Copy Time Log exposes cache diagnostics.
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

Accepted F1g warm-run baseline:

- `backend.native.step_export: 3056ms`.
- `backend.step_export.iter: 1034ms`.
- `backend.step_export.frame_build: 1996ms`.
- `backend.step_export.level_snapshot: 1836ms`.
- `backend.step_export.level_payload: 1374ms`.
- `backend.step_export.structure: 332ms`.
- Validation remained `match`.

F1g conclusion:

- After F1f, data load is no longer the bottleneck.
- Step export is the primary backend bottleneck.
- `level_payload` is wasteful because compact_v1 later removes frame-level bars and indicators.

## Phase F1h: compact-first step frame export / skip redundant frame payload

Accepted.

- Step frame export builds compact frame-level levels directly.
- Frame-level payload keeps `visible_count` and Chan structures.
- Frame-level payload omits `bars` and `indicators` without first constructing them.
- Full final top-level snapshot is built once after step iteration.
- Copy Time Log exposes `backend.step_export.final_snapshot`.

Accepted F1h output, second warm same-session run:

- `backend.native.step_export: 2699ms`.
- `backend.step_export.iter: 1481ms`.
- `backend.step_export.frame_build: 1063ms`.
- `backend.step_export.level_snapshot: 782ms`.
- `backend.step_export.structure: 684ms`.
- `backend.step_export.level_payload: 1ms`.
- `backend.step_export.final_snapshot: 127ms`.
- Copy Step remained strict backend step frame.
- Result Validation remained `match`.

F1h effect:

- `backend.step_export.level_payload` dropped from F1g `1374ms` to `1ms`.
- `backend.step_export.frame_build` dropped from `1996ms` to `1063ms`.
- `backend.native.step_export` dropped from `3056ms` to `2699ms`.
- Remaining backend costs are mainly `step_load()` iteration and structure export.

## Phase F1i: residual backend structure export decomposition

Accepted.

Implemented:

- Backend structure export was split into:
  - `backend.structure_export.merged`
  - `backend.structure_export.fx`
  - `backend.structure_export.bi`
  - `backend.structure_export.seg`
  - `backend.structure_export.zs`
  - `backend.structure_export.bsp`

Accepted F1i output, second warm same-session run:

- `backend_process_pid: 1524`.
- `backend_process_start_count: 1`.
- `backend_request_count: 2`.
- `backend_last_request_reused: true`.
- `backend.data_cache.hits: 3`.
- `backend.data_cache.misses: 0`.
- `backend.native.data_load: 166ms`.
- `backend.native.prepare_chan: 241ms`.
- `backend.native.step_export: 1764ms`.
- `backend.step_export.iter: 1054ms`.
- `backend.step_export.frame_build: 546ms`.
- `backend.step_export.level_snapshot: 391ms`.
- `backend.step_export.structure: 320ms`.
- `backend.step_export.relation: 112ms`.
- `backend.step_export.final_snapshot: 139ms`.
- `backend.structure_export.merged: 206ms`.
- `backend.structure_export.fx: 52ms`.
- `backend.structure_export.bi: 4ms`.
- `backend.structure_export.seg: 0ms`.
- `backend.structure_export.zs: 0ms`.
- `backend.structure_export.bsp: 0ms`.
- `frontend.total: 3597ms`.
- `frontend.http_round_trip: 2516ms`.
- `frontend.parse.top_snapshot: 823ms`.
- Copy Step remained strict backend step frame:
  - `frame_source: native_step_frame`.
  - `final_snapshot_rendered_as_step: false`.
  - `frame.number.local: 1/29`.
  - `frame.cursor.native: 0`.
- Result Validation remained accepted:
  - `validation_status: match`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
  - `fallback_to_bridge: false`.
  - `native_cchan_lv_list: true`.

F1i conclusion:

- Backend structure export is no longer a large opaque block.
- Largest structure sub-cost is merged K-line export at about `206ms`.
- Remaining largest backend cost is `step_load()` iteration around `1054ms`.
- Frontend top snapshot parse remains visible at about `823ms`.
- Next best diagnostic target is frontend top snapshot parse decomposition and possible parse reduction.

Forbidden after F1i remains:

- No algorithmic fast/极速 mode.
- No Chan result cache.
- No Flutter-side Chan calculation.
- No final snapshot slicing fake replay.
- No `python/chan.py` core algorithm change.

## Phase F1j: frontend top snapshot parse decomposition / chart payload parse reduction

Selected next task and implementation progress started.

Goal:

- Split and reduce `frontend.parse.top_snapshot`, currently around `823ms` on the accepted warm-run baseline.
- Preserve final chart rendering, strict backend step frames, compact validation, and result validation.

Implemented progress:

- Commit `82f0dc610ed41012b5c8d7142917e4c77cd5f47f` passes timing hooks into frontend top snapshot parsers.
- It surfaces top snapshot bars/merged/fx/bi/seg/zs/bsp/indicators/levels/relations timings in Copy Time Log stages.
- It keeps backend residual timing, cache diagnostics, and strict step replay unchanged.
- Runtime F1j acceptance is still pending.

Allowed F1j implementation directions:

1. Add frontend parser timing for top snapshot:
   - bars parse.
   - indicators parse.
   - structures parse.
   - relations parse.
   - levels aggregation parse.
2. Identify whether top snapshot parse cost is dominated by raw bars, indicators, structures, or relation parsing.
3. If safe, defer non-visible or heavy top-level indicator parsing behind lazy access, but only after timing proves the target.
4. Keep Copy Step strict backend frame and Result Validation passing.

Forbidden in F1j:

- Do not implement algorithmic fast/极速 mode.
- Do not use Chan result cache.
- Do not fake step replay from final snapshot.
- Do not change `python/chan.py` core algorithm.
- Do not move Chan calculations to Flutter.

F1j acceptance criteria:

- Copy Time Log shows frontend top snapshot sub-stage timing fields.
- Warm backend reuse and raw data cache hit diagnostics remain visible.
- `validation_status: match` and `compact_validation_status: match` remain true.
- `fallback_to_bridge: false` and `native_cchan_lv_list: true` remain true.
- Copy Step remains `native_step_frame`, not final snapshot slicing.

## Performance optimization stop rule after F1j

F1j is the final planned diagnostic pass for the current performance chain.

Default rule after F1j:

- Stop the performance optimization chain.
- Do not continue with F1k/F1l/F1m merely to chase small millisecond-level improvements.
- Return to the business task chain unless the exception rule below is satisfied.

Exception rule for opening F1k or later:

A new performance phase may be opened only if all of the following are true:

1. Copy Time Log proves a single remaining stage is consistently above `800ms-1000ms` on the accepted warm-run test window.
2. The proposed optimization is low-risk and does not change `python/chan.py` core logic.
3. The proposed optimization does not introduce Chan result cache, Flutter-side Chan calculation, or final-snapshot fake step replay.
4. Same-request Result Validation remains `validation_status: match` and `compact_validation_status: match`.
5. The manual is updated before implementation with the target stage, baseline time, proposed change, forbidden scope, and acceptance criteria.

If the exception rule is not satisfied, performance work must stop and the next task must return to one of the business-chain items:

- Strategy mode runtime acceptance.
- Interval-nest buy rule acceptance.
- Full-history / paged strict step replay.
- Signal/rule validation usability.
- Other explicitly selected manual task-chain items.

## Current blockers / pending verification

- No speed/fast/turbo/极速 mode is accepted yet.
- Strategy mode acceptance remains paused until F1j is accepted or explicitly deferred by the supervisor.
- Full-history/paged strict step replay remains deferred.
- Algorithmic fast mode is prohibited until a stricter validation plan is written and accepted.
- Chan result cache remains prohibited.
- F1j frontend top snapshot parse decomposition is now the selected next task.
- F1j is the planned stop point for the current performance chain unless the explicit exception rule above is proven.

## Next task-party operation

1. Complete F1j frontend top snapshot parse timing decomposition.
2. Keep F1f raw data cache diagnostics, F1g/F1h/F1i backend timings visible.
3. Re-run the accepted test window twice in the same App session.
4. Paste Copy Time Log, Copy Step, and Copy Result Validation from the warm second run.
5. Accept F1j only if finer frontend parse timing is visible and validation remains match.
6. After F1j, do not start another performance phase unless the stop-rule exception is explicitly proven and recorded in this manual.
