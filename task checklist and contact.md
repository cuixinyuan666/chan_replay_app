# task checklist and contact

Branch: hichanqujiantao

Base branch lineage:

- `hichan` was created from latest `origin_vespa_tdx` commit `8fcd455a456a8c196e77ce7694d6ab5c6ed609bb`.
- `hichan1` was created from the same baseline for the previous S13 interval-nest validator and numbering-policy work.
- `hichanqujiantao` was created from current `hichan` and fast-forwarded through the accepted `hichan1` S13 context before this evidence-hardening pass.
- Tool limitation: the current GitHub toolset can create/move refs but does not expose a safe delete-ref operation, so historical branches were not removed.

Last supervisor update: 2026-06-15

## Open questions

- S13 interval-nest / nested BSP marker implementation is code-complete but still needs logic-risk validation against real step frames.
- Main review question: whether current interval nesting display has hidden logical errors, especially when one parent K maps to multiple child ranges or when a lower-level BSP maps upward without a same-bar higher-level BSP.
- Presentation decision is fixed: if multiple lower-level BSP observations map to the same higher-level K, keep the same horizontal K position and display numeric sequence labels beside the arrows. If the count is one, do not display a number.
- BSP candidate trail decision is fixed: BSP candidate trail is treated as an at-the-time observation and has the same interval-nest trigger priority as a current/final BSP. The UI may distinguish candidate/current state visually or in evidence, but must not exclude or downgrade candidate trail triggers.

## Hard rules

- Original `python/chan.py` is the only Chan calculation engine.
- Flutter/Dart must not calculate FX/BI/SEG/ZS/BSP/segseg.
- Multi-level native calculation must use `CChan(lv_list=[...])`.
- Strict step replay must use backend step frames, never final-snapshot slicing.
- Bridge fallback, Chan result cache, and algorithmic fast/turbo/speed mode are not accepted.
- High-speed path remains default; slow path is debug/baseline only.
- Prefer repository offline/sample data for validation when it can reproduce the task.
- New files under `python/chan.py` must be in `a_*` folders or named `a_*.py`.
- S13 UI-only marker, candidate-trail, and drawing behavior must not write back into `analysis.snapshot`, backend frames, or `python/chan.py` structure objects.
- S13 candidate-trail BSP observations and current/final BSP observations have equal interval-nest trigger priority. Candidate trail is an at-the-time UI observation; identity must be preserved, but priority must not be downgraded.
- S13 区间套验收硬化 does not add a new top-level page; the evidence and marker logic must stay centralized inside the single-stock multi-level replay page.

## Receiver workload minimization rule

- Prefer command-line validation over App validation when a command can verify the same requirement with less receiver work.
- If a pinned/offline validator exists for the current stage, the preferred receiver path is: `git pull` then run the documented validator command.
- Use App validation only when command-line validation cannot verify UI-specific behavior.
- After each small stage, task party must write a completion summary into this manual.

Required completion summary fields:

- completed_tasks
- evidence_button
- validation_result
- remaining_risk
- next_task

## Accepted work

- P0 App-managed bundled Python backend: accepted.
- Batch A/B/C: accepted.
- F1a-F1k performance chain: accepted and stopped by rule.
- B1a runtime path dropdown and copy diagnostics: accepted.
- B1b Dart-side Chan cleanup/search evidence: accepted.
- S1 Strategy mode runtime acceptance: accepted.
- S2 pinned fixture export for accepted S1 baseline: accepted.
- S3 pinned S1 fixture offline validator: accepted.
- R1 receiver burden code cleanup: accepted.
- R1b CLI receiver-burden validation: accepted.
- S4 CLI strategy diagnostics validator: accepted.
- S5 CLI strategy rule matrix validation.
- S6 strategy signal sample coverage: accepted.
- S7 App strategy signal display loop: accepted.
- S8 scanner / batch strategy output: accepted.
- S9 local generated artifact hygiene and continuation baseline: accepted.
- S10 analyze_multi long-history window count expansion: accepted by receiver CLI evidence.
- S11 post-S10 guardrail regression bundle: accepted by receiver CLI evidence.
- S12a App single-stock replay high-speed baseline static validation: accepted by receiver CLI evidence.
- S12b replay evidence button, indicator default-hidden state, and explicit level-validation feedback: accepted by receiver CLI + App evidence.
- S12c step-load temporal evidence state tracking: accepted by receiver CLI + App evidence.
- S12d interval-link marker ids for parent-child replay navigation evidence: accepted by receiver CLI + App evidence.
- S12e shared marker-overlap policy evidence and full S12 evidence-chain closure.
- S13 single-stock multi-level replay workspace UI optimizations: implementation completed; `flutter analyze` passed in the recorded stage; App visual validation remains required.
- S13 touch-friendly unified toolbar, date picker, full-step replay controls, draggable controls, and clean BSP labels: implementation completed; `flutter analyze` passed in the recorded stage; App visual validation remains required.
- S13 native multi-level step frames through `CChan(lv_list=[...]).step_load()` and compact frame transport: implementation completed in code; dedicated S13 CLI/native validator remains required.
- S13 nested BSP marker overlay, lower-level BSP upward trigger, loaded-level switcher, and BSP candidate persistence: implementation completed in code; hidden logic review remains required.
- S13 default publish prep: start date `2026-01-01`, end date `system current date - 2 days`, replay mode `step`; `flutter analyze` passed.
- hichanhuancun stage-1 backend cache/lazy-layer/BSP-freeze/anti-future contracts: implementation completed in code; dedicated static validator added as `python tools/validate_hichanhuancun_contracts.py`.
- hichanhuancun cache optimization page: implementation completed in code as a new same-level root page `缓存优化`; dedicated static validator updated.
- hichanhuancun chart_lazy_layers v2 transport pruning loop: implementation completed in code; backend prunes returned layer payload by request and App page can send layer requests and display returned manifest.

## Current selected task

S13 interval-nest hidden logic hardening and hichanhuancun chart_lazy_layers v2 transport pruning validation are selected for integration into `hichan`.

Current supervisor position:

- S12 full evidence chain is complete.
- S13 implementation work is recorded as code-complete but not fully accepted as logic-verified.
- `hichan` is the renamed continuation branch created from latest `origin_vespa_tdx`.
- `hichan1` is historical context for S13 trigger-list and numbering-policy work.
- `hichanqujiantao` is the current S13 区间套复盘验收硬化 branch.
- No new Chan algorithm authority is granted to Flutter/Dart.
- Multiple lower-level BSP observations mapped to one higher-level K must be preserved as distinct triggers and rendered with numeric labels only when count > 1.
- BSP candidate-trail observations are at-the-time observations and have the same interval-nest trigger priority as current/final BSP observations.
- hichanhuancun adds backend-only cache, export-history fields, transport contracts, anti-future metadata, and chart layer transport pruning; it does not grant Flutter/Dart Chan calculation authority.
- `缓存优化` is a root-level UI diagnostics/request page beside `复盘` and `单股多级别`; it can send `chart_lazy_layers/chart_layers` to `/api/chan/analyze_multi` and render returned manifest/evidence.
- Next required work is to run the dedicated validator and then receiver App evidence for real backend pruning behavior.

Optional display-layout debt remains:

- Global chart-label migration debt: `_drawFx` should eventually migrate through the shared `ChartLabelLayout` path and clear `audit_origin_kline_global_label_layout_usage.py --strict`.

## hichanhuancun completion summary

- completed_tasks: Added backend raw K-line session cache with key/TTL policy; added BSP `anchor/display/confirmed` frozen export fields; added `multi_level_anti_future_meta_v1`; added same-level App page `缓存优化`; upgraded `chart_lazy_layers` from v1 returned contract to `chart_lazy_layers_v2_transport_pruning`, where request `chart_layers` controls returned layer payload and meta reports display/transport/forced/omitted/pruned/manifest state.
- evidence_button: App page `缓存优化` has `请求 analyze_multi` and `复制证据`; command-line receiver evidence is `python tools/validate_hichanhuancun_contracts.py`.
- validation_result: Static validator updated for backend pruning loop and App request/manifest display loop; full runtime validation still depends on receiver environment with easy-tdx / chan.py / Flutter available.
- remaining_risk: Runtime pruning must still be verified against real step frames; S13 chart page itself has not yet received per-layer chart toggles wired to this transport contract, so the complete visual chart-control integration remains a later UI stage.
- next_task: Run validator, open `缓存优化`, deselect layers, request analyze_multi, and confirm `chart_lazy_layers_pruned_counts` and `chart_lazy_layers_manifest` change as expected.

## Historical accepted summary

### S1-S3

- S1 accepted with `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B`.
- S2 accepted pinned fixture export: `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- S3 accepted pinned S1 fixture CLI validation with compact match, native lv_list, no bridge fallback, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, and no Chan recalculation.

### R1/R1b

- R1 accepted by App evidence. It made `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B` the S1-like defaults, kept `S1一键复制`, and de-emphasized low-level debug copy buttons.
- R1b accepted by CLI validation: `python tools/validate_r1_receiver_burden.py`.

### S4-S9

- S4 accepted: CLI strategy diagnostics validator.
- S5 accepted: CLI strategy rule matrix validation for `DAILY_2B_MIN30_1B`, `DAILY_3B_MIN30_1B`, and `DAILY_3B_MIN30_2B`.
- S6 accepted: strategy signal sample coverage, including matched-output metadata and no-output diagnostic path.
- S7 accepted: App strategy signal display loop, selected-signal callback, raw-index jump, chart marker wiring, and copy evidence.
- S8 accepted: scanner / batch strategy output, local generated candidate JSON, App candidate navigation, chart marker, and traceability evidence.
- S9 accepted: local generated artifact hygiene and continuation baseline.
- Generated `test/fixtures/derived/s8_strategy_batch_candidates_v1.json` is local validation output and should not be committed by default.

### S10-S12

- S10 accepted: analyze_multi long-history window count expansion based on request `start/end`, native `CChan(lv_list=[...])`, and no Dart-side Chan authority.
- S11 accepted: post-S10 guardrail regression bundle, including S10 validation, S8 export/validation, global lazy-loading audit, and chan.py placement guardrail.
- S12a accepted: App single-stock replay high-speed baseline static validation.
- S12b accepted: replay evidence button, default-hidden indicators, and explicit level-validation feedback.
- S12c accepted: backend step-frame temporal evidence state tracking for provisional/confirmed/historical provisional structures.
- S12d accepted: interval-link marker ids from backend `MultiLevelChanSnapshot.relations`.
- S12e accepted: shared marker-overlap policy evidence and full S12 evidence-chain closure.

## S13 implementation inventory

### S13 single-stock multi-level replay workspace

completed_tasks:

- Optimized the single-stock multi-level replay page so the K-line chart uses the full route area by default.
- Replaced permanent side layout with a floating/draggable unified `工具栏`.
- Consolidated stock, level, replay, layer, drawing, and page navigation controls into the unified toolbar.
- Added top title-area level switcher using backend-loaded snapshot levels.
- Kept K-line chart responsible for display, zoom, pan, crosshair, layer/indicator interaction, and drawing tools.

validation_result:

- `flutter analyze` passed in the recorded S13 UI optimization stages.

remaining_risk:

- Receiver still needs visual App validation on Windows and Android, especially toolbar scrolling, drag ergonomics, chart edge usage, and short-window overlap.

### S13 native step frames and compact transport

completed_tasks:

- Backend timed multi-level adapter calls native `analyze_multi_native_timed`.
- Native step mode calls `CChan(lv_list=[...]).step_load()`.
- Step response returns compact frames with `step_frame_format=compact_v1`.
- Backend records `native_step_frames`, `native_step_frames_total`, `native_step_frames_returned`, `native_step_frames_truncated`, and timing metadata.
- Dart source lazily parses compact frames and records lazy-frame parse/cache timing.

validation_result:

- Implementation is present in code.
- Dedicated S13 CLI/native validator is not yet present.

remaining_risk:

- Need validator to prove first/middle/last compact frames match backend-visible counts and relations, and that no final-snapshot slicing is used.

### S13 nested BSP marker overlay and candidate persistence

completed_tasks:

- Removed visible step-mode `区间套链接` overlay/list from the chart workspace.
- Added step-only nested BSP marker overlay on the K-line chart.
- Marker generation uses backend step frames, loaded level order, BSP rows, and backend parent-child relations.
- Lower-level BSPs can trigger markers on a higher-level chart after mapping through backend relations.
- Marker rows can be clicked to jump to the corresponding level/raw K-line.
- Candidate trail accumulates historical BSP observations up to the current frame and preserves prior provisional observations as lighter UI markers.
- Current-frame BSPs remain deep-colored; historical/provisional states are represented by color/alpha rather than text suffixes.
- BSP parser handles `confirmed` and `is_sure`, including string/number false forms.

validation_result:

- `flutter analyze` passed in the recorded nested-marker correction stages.

remaining_risk:

- Current implementation required hidden logic hardening, now addressed by the `hichanqujiantao` evidence task record below.

## S13 interval-nest logic review

### Supervisor conclusion

Current interval-nest implementation is not a Chan-calculation violation, because it reads backend-exported relations and backend-exported BSP rows. However, correctness still needs explicit evidence because a plausible UI marker can be logically wrong if trigger identity, candidate/current state, relation provenance, or interval-only anchors are lost.

Important correction from supervisor philosophy:

- BSP candidate trail is an at-the-time observation and is part of the replay current-state evidence.
- Candidate-trail BSP and current/final BSP have equal priority when generating interval-nest markers.
- Candidate trail must not be excluded, downgraded, or treated as merely decorative.
- Candidate/current identity must still be preserved for UI/evidence clarity.
- Candidate trail remains UI-only and must not mutate backend frames, final snapshots, or `python/chan.py` structures.

Required hardening points:

- When mapping downward, choose a non-ambiguous child relation, and stop mapping instead of silently taking the first child range.
- Separate `interval anchor` from `BSP anchor`; never style childStart placeholder as a BSP signal.
- Replace collapsed active raw-index sets with trigger identity rows that preserve `sourceLevel`, `sourceRawIndex`, `activeRawIndex`, and candidate/current state.
- In copied S13 evidence, record `relation_source_frame`, `bsp_source_frame`, `trigger_state=current|candidate_trail`, and `anchor_kind=bsp|interval`.
- Validate every adjacent loaded-level pair has relation rows before using it as a hierarchy edge; if an edge lacks relations, stop mapping for that edge and report the missing pair.
- Page-level adaptation: keep S13 interval-nest evidence inside the single-stock multi-level replay page; do not add a separate 区间套/S13 top-level page.

## hichan1 task record: S13 interval-nest validator and numbering policy

completed_tasks:

- Created branch `hichan` from latest `origin_vespa_tdx` commit `8fcd455a456a8c196e77ce7694d6ab5c6ed609bb`.
- Created branch `hichan1` from the same baseline.
- Added `tools/validate_s13_interval_nest_marker_logic.py` on `hichan1`.
- Added `lib/ui/pages/s13_nested_marker_numbering_policy.dart` to pin the confirmed numbering rule.
- Updated `lib/ui/pages/s13_nested_marker_numbering_policy.dart` so candidate-trail and current/final BSP states compare at equal priority.
- Updated `lib/ui/pages/s13_single_stock_replay_page.dart` to import the numbering policy and replace the active raw-index `Set<int>` model with explicit `_NestedBspTrigger` identities.
- S13 marker triggers preserve `sourceLevel`, `sourceRawIndex`, `sourceBsp`, active raw index, and candidate/current state before grouping by active rawIndex for display.
- Numeric sequence labels are generated per active rawIndex group and are hidden when group count is one.
- Interval-only child anchors are explicitly separated from BSP trigger rows through `isIntervalAnchor`.
- The validator checks that step mode reads `analysis.frames[_safeFrameIndex]` instead of final snapshot slicing.
- The validator checks that nested markers use backend `relations` and backend BSP rows only.
- The validator rejects an unconditional first-child-range pattern in `_relationDown`.
- The validator rejects `childStartRawIndex` acting as an implicit BSP anchor without explicit interval-anchor state.
- The validator rejects collapsing multiple lower-level BSP triggers into a single `Set<int>` active raw index.
- The validator checks historical candidate BSPs are UI-only copies and do not mutate backend frame or snapshot objects.
- The manual was updated to record this branch/task process and the equal-priority candidate-trail rule.

evidence_button:

- Not present in `hichan1`; evidence copying was selected as the follow-up hardening task.

validation_result:

- Validator script added.
- Numbering policy helper added.
- Candidate-trail equal-priority policy added to code helper and manual.
- Main page trigger-list implementation committed.
- Connector-side file comparison confirms no `python/chan.py` or backend Chan calculation files were modified in this task.
- Local `flutter analyze` and local validator execution are still required by receiver because the task environment cannot run the Flutter project build.

remaining_risk:

- Receiver should run `flutter analyze`, `python tools/check_chanpy_guardrails.py`, and `python tools/validate_s13_interval_nest_marker_logic.py` after pulling `hichan1` if reviewing history.
- The main page preserved trigger identity, but App validation was still required to verify marker density, tap target ergonomics, and visual clarity when many triggers map to one active rawIndex.

next_task:

- Add copied evidence/debug output for marker trigger state: current versus candidate_trail.
- Verify on real `DAILY,MIN30,MIN5` step replay that candidate-trail BSP and current/final BSP both trigger markers with equal priority.

## hichanqujiantao task record: S13 interval-nest replay acceptance evidence hardening

completed_tasks:

- Created branch `hichanqujiantao` from current `hichan`, then fast-forwarded it through the historical `hichan1` S13 trigger-list baseline.
- Updated `lib/ui/pages/s13_single_stock_replay_page.dart` so S13 marker handling uses private observation/trigger models rather than naked `BspPoint` lists for acceptance evidence.
- Added `_BspObservation` with explicit `current` versus `candidate_trail` state, `bspKey`, and `bspSourceFrame`.
- Extended `_NestedBspTrigger` and `_NestedBspMarker` with `sourceLevel`, `sourceRawIndex`, `activeRawIndex`, `sequenceNumber`, `sequenceTotal`, `relationSourceFrame`, `bspSourceFrame`, `bspKey`, and `anchorKind`.
- Preserved the existing numbering policy: one trigger at an active raw index shows no number, while multiple triggers show `1..n` in trigger identity order.
- Kept candidate-trail and current/final BSP triggers at equal priority through `S13NestedMarkerNumberingPolicy.compareTriggerState` returning `0`.
- Added adjacent relation edge diagnostics: every loaded-level adjacent pair must have backend relation rows before marker mapping can use that edge; missing pairs are reported as `missing_relation_edges`.
- Kept interval-only anchors explicit through `anchor_kind=interval` / `isIntervalAnchor`, so child interval placeholders cannot impersonate BSP anchors.
- Added S13 marker evidence copy payload headed by `S13_INTERVAL_NEST_MARKER_EVIDENCE`.
- Extended `tools/validate_s13_interval_nest_marker_logic.py` to check evidence button, evidence fields, candidate/current identity fields, frame provenance fields, missing-edge diagnostics, and interval-anchor/BSP-anchor separation.
- Added page-integration checks to the validator: S13 evidence hardening does not add a new top-level page and remains centralized inside the single-stock multi-level replay page.
- Removed the broad `unused_field: ignore` analyzer waiver that had been temporarily added, so this task does not weaken global analyzer policy.

evidence_button:

- Added `复制 marker 证据` in the S13 unified toolbar `复盘 / marker` area.
- The copied payload header is fixed as `S13_INTERVAL_NEST_MARKER_EVIDENCE`.
- The payload includes request parameters, runtime path, current frame, frame total, active level, loaded levels, relation count, nested marker count, candidate trail count, missing relation edges, and marker trigger samples.
- Marker trigger samples include `activeRawIndex`, `sourceLevel`, `sourceRawIndex`, `trigger_state=current|candidate_trail`, `sequenceNumber`, `sequenceTotal`, `bsp_key`, `relation_source_frame`, `bsp_source_frame`, and `anchor_kind=bsp|interval`.

validation_result:

- Static validator updated: `python tools/validate_s13_interval_nest_marker_logic.py`.
- The validator now treats copied evidence as the stable UI/receiver text interface.
- The validator still enforces that Dart uses backend `MultiLevelChanSnapshot.relations` and backend BSP rows only.
- The validator now also verifies that `root_page.dart` keeps `S13SingleStockReplayPage` in `_multiLevelIndex` and that S13 toolbar page navigation only targets existing pages rather than creating an interval-nest page.
- Local command execution was not performed in this connector-only environment; receiver should run the commands in the next section after pulling `hichanqujiantao`.

remaining_risk:

- Real App validation is still required to verify marker density, tap ergonomics, and visual clarity on live step replay data.
- Real receiver validation is still required to prove copied evidence contains non-empty marker samples on a representative multi-level replay.
- `s13_single_stock_replay_page.dart` still has a large diff versus `hichan1` because the prior evidence pass rewrote substantial formatting while adding logic. This is a merge-risk note, not a runtime issue; future conflict resolution should prefer keeping hichan's page skeleton and reapplying only the evidence/trigger-model hunks if necessary.
- No backend protocol change was made; evidence is a UI/acceptance text interface only.

next_task:

- Receiver pulls `hichanqujiantao` and runs the baseline + S13 validator commands below.
- In App, load a real `DAILY,MIN30,MIN5` step replay, click `复制 marker 证据`, and paste the evidence to verify trigger-state and frame-provenance samples.
- If sample evidence reveals missing relation edges for expected adjacent pairs, inspect backend relation export for that frame before changing Dart display behavior.
- If merging with a `hichan` branch that added new sibling pages, keep the new sibling page entries in `root_page.dart`; do not move S13 evidence out of the existing single-stock multi-level replay page.

## Next task-party operation

1. Receiver pulls latest `hichanqujiantao`.
2. Run baseline checks:
   - `python tools/validate_s13_interval_nest_marker_logic.py`
   - `python tools/check_chanpy_guardrails.py`
   - `python tools/audit_dart_algorithm_usage.py`
   - `flutter analyze`
3. Expected current behavior:
   - The validator should pass source-authority checks.
   - The validator should pass evidence-button, evidence-field, candidate/current identity, frame provenance, missing-edge diagnostic, interval-anchor/BSP-anchor separation, and page-integration checks.
4. Receiver App validation:
   - Step through `DAILY,MIN30,MIN5` real data.
   - Verify lower-level BSP appears on higher-level chart.
   - Verify click-through lands on the intended lower-level BSP or explicitly marked interval-only region.
   - Verify multiple lower-level BSPs under one parent K are not visually collapsed into one misleading signal.
   - Verify candidate-trail BSP observations and current/final BSP observations both trigger interval-nest markers with equal priority.
   - Verify count-one marker shows no number, while count-greater-than-one markers show `1`, `2`, `3`, etc.
   - Copy marker evidence and confirm pasted text starts with `S13_INTERVAL_NEST_MARKER_EVIDENCE`.
