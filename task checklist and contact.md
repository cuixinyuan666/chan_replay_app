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
- Performance work is now stopped after F1k. Do not continue with F1l/F1m unless a new manual exception is explicitly proven and recorded first.

## Latest important commits

- `25a7bbce2d0f2d78ba625d5e591b30d8881578e3`: reuse app-managed Python backend across source/page rebuilds.
- `fbd0a979eb48c181a06b36da5e9c2a926ce6420f`: accept F1d warm backend reuse.
- `773f428864e42766c4368bb839c9e5bb70d92d3d`: accept F1e native timing decomposition.
- `5e2a6f5e525908b04bdcbacd6062555e0ce55e6a`: accept F1f raw data cache reuse.
- `4860e0ee5aa54b22da19978eb4ef2e93388f6690`: accept F1g step export decomposition.
- `31af043bd41298e9a643d036b6716d53180b7ee3`: accept F1h compact-first step export.
- `8018efeee26b57f3a657e647ae9ed7bb30f63d8f`: split backend structure export timings.
- `89afef251c8de84d1fc5acf0d01acb262ce7f782`: surface structure export substage timings.
- `829b5c4a0e060a18cb91919678034b298518eb51`: accept F1i backend residual decomposition.
- `97fb334009d213f206e08a7211afa0321a4ca263`: add single-level frontend parse timing hooks.
- `be2e68d7006bb0c5a007bcb5f8f7cfdb27291d39`: add multi-level frontend parse timing hooks.
- `82f0dc610ed41012b5c8d7142917e4c77cd5f47f`: surface frontend top snapshot parse timings.
- `06db968caa093ecb10914ab0420582571beb0478`: lazily parse Easy TDX indicator payloads.
- Current update: accept F1j and F1k, then stop the performance optimization chain.

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
- F1j frontend top snapshot parse decomposition: accepted.
- F1k lazy Easy TDX indicator parsing: accepted.
- Performance chain F1a-F1k: stopped by rule; return to business task chain.

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
- Copy Step remained strict backend step frame.
- Result Validation remained accepted.

F1i conclusion:

- Backend structure export is no longer a large opaque block.
- Largest structure sub-cost is merged K-line export at about `206ms`.
- Remaining largest backend cost is `step_load()` iteration around `1054ms`.
- Frontend top snapshot parse remained visible at about `823ms`.

## Phase F1j: frontend top snapshot parse decomposition / chart payload parse reduction

Accepted.

Implemented:

- Single-level frontend parser timing hooks:
  - `frontend.parse.top_snapshot.single_level.bars`
  - `frontend.parse.top_snapshot.single_level.merged`
  - `frontend.parse.top_snapshot.single_level.fx`
  - `frontend.parse.top_snapshot.single_level.bi`
  - `frontend.parse.top_snapshot.single_level.seg`
  - `frontend.parse.top_snapshot.single_level.zs`
  - `frontend.parse.top_snapshot.single_level.bsp`
  - `frontend.parse.top_snapshot.single_level.indicators`
  - `frontend.parse.top_snapshot.single_level.total`
- Multi-level frontend parser timing hooks:
  - `frontend.parse.top_snapshot.levels`
  - `frontend.parse.top_snapshot.meta_order`
  - `frontend.parse.top_snapshot.relations`
  - `frontend.parse.top_snapshot.total_inner`

Accepted F1j output, second warm same-session run:

- `backend_process_pid: 2252`.
- `backend_process_start_count: 1`.
- `backend_request_count: 2`.
- `backend_last_request_reused: true`.
- `backend.data_cache.hits: 3`.
- `backend.data_cache.misses: 0`.
- `frontend.total: 4127ms`.
- `frontend.http_round_trip: 2845ms`.
- `frontend.parse.top_snapshot: 976ms`.
- `frontend.parse.top_snapshot.single_level.bars: 80ms`.
- `frontend.parse.top_snapshot.single_level.merged: 39ms`.
- `frontend.parse.top_snapshot.single_level.fx: 10ms`.
- `frontend.parse.top_snapshot.single_level.bi: 2ms`.
- `frontend.parse.top_snapshot.single_level.indicators: 837ms`.
- `frontend.parse.top_snapshot.levels: 976ms`.
- `frontend.parse.top_snapshot.relations: 0ms`.
- Copy Step remained strict backend step frame.
- Result Validation remained accepted.

F1j conclusion:

- Frontend top snapshot parse was dominated by indicator parsing.
- `frontend.parse.top_snapshot.single_level.indicators` accounted for about `837ms / 976ms`, more than 85 percent.
- This satisfies the manual exception rule for one more performance phase because a single remaining stage was above 800ms, the proposed optimization is frontend lazy parsing only, and validation remains match.

## Phase F1k: lazy Easy TDX indicator parsing

Accepted.

Exception rule for F1k:

- F1j Copy Time Log proved a single stage above 800ms: `frontend.parse.top_snapshot.single_level.indicators: 837ms`.
- Proposed change was low-risk frontend parsing only.
- No `python/chan.py` core logic change.
- No Chan result cache.
- No Flutter-side Chan calculation.
- No final-snapshot fake step replay.
- Same-request validation remained match.

Implemented:

- `EasyTdxIndicators.fromJson()` now keeps raw indicator JSON and parses individual series on demand.
- Existing public API remains:
  - `vol`
  - `amount`
  - `turnover`
  - `ma`
  - `boll`
  - `macd`
  - `namedSeries`
  - `visibleVol`, `visibleMacd`, `visibleBoll`, `visibleMa`, `visibleNamed`.
- `const EasyTdxIndicators()` remains valid for `ChanSnapshot` defaults.

Accepted F1k output, second warm same-session run:

- `backend_process_pid: 11680`.
- `backend_process_start_count: 1`.
- `backend_request_count: 2`.
- `backend_last_request_reused: true`.
- `backend.data_cache.hits: 3`.
- `backend.data_cache.misses: 0`.
- `frontend.total: 2461ms`.
- `frontend.http_round_trip: 2079ms`.
- `frontend.parse.top_snapshot: 144ms`.
- `frontend.parse.top_snapshot.single_level.bars: 86ms`.
- `frontend.parse.top_snapshot.single_level.merged: 42ms`.
- `frontend.parse.top_snapshot.single_level.fx: 9ms`.
- `frontend.parse.top_snapshot.single_level.bi: 1ms`.
- `frontend.parse.top_snapshot.single_level.indicators: 0ms`.
- `frontend.parse.top_snapshot.levels: 144ms`.
- `frontend.parse.snapshot_frames_relations_bsp: 144ms`.
- Copy Step remained strict backend step frame.
- Result Validation remained accepted:
  - `validation_status: match`.
  - `compact_validation_status: match`.
  - `compact_validation_mismatch_count: 0`.
  - `fallback_to_bridge: false`.
  - `native_cchan_lv_list: true`.

F1k effect:

- `frontend.parse.top_snapshot.single_level.indicators` dropped from F1j `837ms` to `0ms`.
- `frontend.parse.top_snapshot` dropped from `976ms` to `144ms`.
- `frontend.parse.snapshot_frames_relations_bsp` dropped from `976ms` to `144ms`.
- `frontend.total` dropped from `4127ms` to `2461ms`.
- Current largest warm-run stages after F1k:
  - `backend.native.step_export: 1376ms`.
  - `backend.step_export.iter: 728ms`.
  - `backend.step_export.frame_build: 513ms`.
  - `backend.step_export.structure: 317ms`.
- No new frontend single stage remains above the F1j/F1k exception threshold.

## Performance optimization stop rule after F1k

F1j was the final planned diagnostic pass. F1k was opened only because F1j proved a single 800ms+ frontend indicator parse bottleneck and met the exception rule.

After F1k:

- The exceptional indicator bottleneck is resolved.
- No new single frontend stage remains above `800ms-1000ms`.
- Do not continue performance work by default.
- Return to business task chain.

## Current blockers / pending verification

- No speed/fast/turbo/极速 mode is accepted yet.
- Algorithmic fast mode remains prohibited until a stricter validation plan is written and accepted.
- Chan result cache remains prohibited.
- Full-history/paged strict step replay remains deferred.
- Performance chain F1a-F1k is stopped by rule.
- Next task should return to one of the business-chain items:
  - Strategy mode runtime acceptance.
  - Interval-nest buy rule acceptance.
  - Full-history / paged strict step replay.
  - Signal/rule validation usability.
  - Other explicitly selected manual task-chain items.

## Next task-party operation

1. Stop performance-chain work unless a new manual exception is explicitly proven and recorded first.
2. Return to the business task chain.
3. Recommended next task: Strategy mode runtime acceptance using the existing validation gates.
4. Keep F1f raw data cache diagnostics, F1g/F1h/F1i/F1j/F1k timing fields available for regression checks.
5. Continue requiring same-request `validation_status: match`, `compact_validation_status: match`, `fallback_to_bridge: false`, and `native_cchan_lv_list: true` for accepted changes.
