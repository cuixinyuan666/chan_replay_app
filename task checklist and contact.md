# task checklist and contact

Branch: hichan1

Base branch lineage:

- `hichan` was created from latest `origin_vespa_tdx` commit `8fcd455a456a8c196e77ce7694d6ab5c6ed609bb`.
- `hichan1` was created from the same baseline for S13 interval-nest validator work.
- Tool limitation: the current GitHub toolset can create/move refs but does not expose a safe delete-ref operation, so old `origin_vespa_tdx` was not removed. Treat `hichan` as the renamed continuation branch and `hichan1` as the active task branch.

Last supervisor update: 2026-06-15

## Open questions

- S13 interval-nest / nested BSP marker implementation is code-complete but still needs logic-risk validation against real step frames.
- Main review question: whether current interval nesting display has hidden logical errors, especially when one parent K maps to multiple child ranges or when a lower-level BSP maps upward without a same-bar higher-level BSP.
- Presentation decision is now fixed: if multiple lower-level BSP observations map to the same higher-level K, keep the same horizontal K position and display numeric sequence labels beside the arrows. If the count is one, do not display a number.
- BSP candidate trail decision is now fixed: BSP candidate trail is treated as an at-the-time observation and has the same interval-nest trigger priority as a current/final BSP. The UI may distinguish candidate/current state visually or in evidence, but must not exclude or downgrade candidate trail triggers.

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
- S2 pinned offline fixture export for accepted S1 baseline: accepted.
- S3 pinned S1 fixture offline validator: accepted.
- R1 receiver burden code cleanup: accepted by App evidence.
- R1b CLI receiver-burden validation: accepted.
- S4 CLI strategy diagnostics validator: accepted.
- S5 CLI strategy rule matrix validation: accepted.
- S6 strategy signal sample coverage: accepted.
- S7 App strategy signal display loop: accepted.
- S8a CLI scanner / batch candidate output: accepted.
- S8b App scanner / batch candidate navigation: accepted.
- S8 scanner / batch strategy output: accepted.
- S9 local generated artifact hygiene and continuation baseline: accepted.
- S10 analyze_multi long-history window count expansion: accepted by receiver CLI evidence.
- S11 post-S10 guardrail regression bundle: accepted by receiver CLI evidence.
- S12a App single-stock replay high-speed baseline static validation: accepted by receiver CLI evidence.
- S12b replay evidence button, indicator default-hidden state, and explicit level-validation feedback: accepted by receiver CLI + App evidence.
- S12c step-load temporal evidence state tracking: accepted by receiver CLI + App evidence.
- S12d interval-link marker ids for parent-child replay navigation evidence: accepted by receiver CLI + App evidence.
- S12e shared marker-overlap policy for S12 chart and evidence markers: accepted by receiver CLI + App evidence.
- S13 single-stock multi-level replay workspace UI optimizations: implementation completed; `flutter analyze` passed; App visual validation remains required.
- S13 touch-friendly unified toolbar, date picker, full-step replay controls, draggable controls, and clean BSP labels: implementation completed; `flutter analyze` passed; App visual validation remains required.
- S13 native multi-level step frames through `CChan(lv_list=[...]).step_load()` and compact frame transport: implementation completed in code; dedicated S13 CLI/native validator remains required.
- S13 nested BSP marker overlay, lower-level BSP upward trigger, loaded-level switcher, and BSP candidate persistence: implementation completed in code; hidden logic review remains required.
- S13 default publish prep: start date `2026-01-01`, end date `system current date - 2 days`, replay mode `step`; `flutter analyze` passed.

## Current selected task

S13 interval-nest hidden logic hardening is selected on branch `hichan1`.

Current supervisor position:

- S12 full evidence chain is complete.
- S13 implementation work is recorded as code-complete but not fully accepted as logic-verified.
- `hichan` is the renamed continuation branch created from latest `origin_vespa_tdx`.
- `hichan1` is the active validation/hardening branch.
- No new Chan algorithm authority is granted to Flutter/Dart.
- The validator is intentionally allowed to fail until S13 marker mapping is hardened.
- Multiple lower-level BSP observations mapped to one higher-level K must be preserved as distinct triggers and rendered with numeric labels only when count > 1.
- BSP candidate-trail observations are at-the-time observations and have the same interval-nest trigger priority as current/final BSP observations.

Optional display-layout debt remains:

- Global chart-label migration debt: `_drawFx` should eventually migrate through the shared `ChartLabelLayout` path and clear `audit_origin_kline_global_label_layout_usage.py --strict`.

## Historical accepted summary

### S1-S3

- S1 accepted with `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B`.
- S2 accepted pinned fixture export: `test/fixtures/pinned/s1_600340_SH_DAILY_MIN30_MIN5_2025-09-01_2025-10-20_step_compact_v1.json`.
- S3 accepted pinned S1 fixture CLI validation with compact match, native lv_list, no bridge fallback, relation pairs `DAILY->MIN30` and `MIN30->MIN5`, and no Chan recalculation.

### R1/R1b

- R1 accepted by App evidence. It made `rule mode = strategy` and `strategy rule = DAILY_2B_MIN30_1B` the S1-like defaults, kept `S1一键复制`, and de-emphasized low-level debug copy buttons.
- R1b accepted by CLI validation: `python tools/validate_r1_receiver_burden.py`.

### S4-S7

- S4 accepted: CLI strategy diagnostics validator.
- S5 accepted: CLI strategy rule matrix validation for `DAILY_2B_MIN30_1B`, `DAILY_3B_MIN30_1B`, and `DAILY_3B_MIN30_2B`.
- S6 accepted: strategy signal sample coverage, including matched-output metadata and no-output diagnostic path.
- S7 accepted: App strategy signal display loop, selected-signal callback, raw-index jump, chart marker wiring, and copy evidence.

### S8-S9

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

### S13 time-window and replay defaults

completed_tasks:

- Changed S13 default start date to `2026-01-01`.
- Changed S13 default end date to system current date minus two days.
- Changed S13 default replay mode to `step`.
- S13 page sends `startDate` and `endDate` to `analyzeMulti` and validates `start <= end`.

validation_result:

- `flutter analyze` passed.

remaining_risk:

- Need confirm backend S13 path does not effectively reintroduce `count` as a hidden truncation condition when `start/end` are provided.

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

- Current implementation can still have hidden logical display errors. See review section below.

## S13 interval-nest logic review

### Supervisor conclusion

Current interval-nest implementation is not a Chan-calculation violation, because it reads backend-exported relations and backend-exported BSP rows. However, it is not yet logic-accepted as a correct interval-nest display. It has several hidden UI/model-mapping risks that can make the chart show a plausible but logically wrong nested marker chain.

Important correction from supervisor philosophy:

- BSP candidate trail is an at-the-time observation and is part of the replay's current-state evidence.
- Candidate-trail BSP and current/final BSP have equal priority when generating interval-nest markers.
- Candidate trail must not be excluded, downgraded, or treated as merely decorative.
- Candidate/current identity must still be preserved for UI/evidence clarity.
- Candidate trail remains UI-only and must not mutate backend frames, final snapshots, or `python/chan.py` structures.

### Risk 1: first-child-range selection can lose valid child mapping

- Current mapping from parent to child effectively selects the first sorted child range for a parent rawIndex.
- If backend relations contain multiple child ranges for one parent rawIndex, selecting the first range can map to the wrong child segment for a BSP that actually belongs to a later child range.
- This is a display-level logical error risk, not a chan.py computation error.

Required fix:

- When mapping downward, choose the child relation that contains the target lower-level BSP or target child raw index.
- If only a parent rawIndex is available, expose multiple child candidates or mark ambiguity instead of silently taking the first range.

### Risk 2: downward chain anchors to childStart when no child BSP exists

- When no BSP exists inside the child range, the code can use `childStartRawIndex` as a placeholder anchor.
- This is acceptable for navigation to a region, but not equivalent to a child-level buy/sell point.
- If rendered as a nested BSP marker row, it can visually imply a child signal where only a child interval exists.

Required fix:

- Separate `interval anchor` from `BSP anchor` in the row model.
- Render missing BSP rows as `-` or interval-only, and never style a childStart placeholder as a BSP signal.

### Risk 3: active-level mapping can collapse many lower-level BSPs onto the same parent K

- Mapping lower-level BSP observations upward to the active higher level can collapse multiple lower-level observations into one higher-level rawIndex.
- This applies equally to current/final BSP observations and candidate-trail BSP observations.
- The current dedupe key includes row information, so some duplicates are preserved, but visible x-position can still overlap and imply a single event cluster.

Required fix:

- Replace the `Set<int>` active-anchor model with a trigger identity list.
- Each trigger must preserve `sourceLevel`, `sourceRawIndex`, `activeRawIndex`, and candidate/current state.
- Group triggers by `activeRawIndex` only for display placement, not for data loss.
- Within each `activeRawIndex`, sort by lower-level rawIndex and assign sequence labels.
- If group count is one, do not display a number.
- If group count is greater than one, display `1`, `2`, `3`, etc. beside the arrows.

### Risk 4: current-frame relation availability may be weaker than current-frame BSP availability

- Strict step mode correctly reads `analysis.frames[_safeFrameIndex]`.
- But if a frame contains a lower-level BSP before the corresponding parent-child relation is fully exported or stable, upward/downward mapping can fail or later change.

Required fix:

- In S13 evidence, record per-marker `frame_index`, `relation_source_frame`, `bsp_source_frame`, and whether mapping source is `current` or `candidate_trail`.
- Candidate-trail observations must have equal trigger priority, but their identity must remain explicit.

### Risk 5: candidate trail identity can be lost

- Candidate trail is intentionally preserved as a same-priority at-the-time BSP observation.
- The risk is not that candidate trail participates in interval-nest marker generation. It should participate.
- The real risk is losing the identity of whether a trigger came from current/final BSP or candidate trail.

Required fix:

- Keep internal state explicit: `current` versus `candidate_trail`.
- Candidate-trail and current/final BSP observations must share the same numbering and trigger priority.
- Add optional debug tooltip or copied evidence showing `candidate_trail=true/false`.

### Risk 6: loaded-level order must match backend semantic hierarchy

- S13 now uses backend-loaded levels instead of default selected levels, which is better.
- But if backend returns levels in a different order or missing an intermediate level, the chain `levels[i] -> levels[i+1]` can produce wrong parent/child assumptions.

Required fix:

- Validate every adjacent pair has relation rows before using it as a hierarchy edge.
- If an edge lacks relations, disable nested mapping for that edge and report the missing pair.

## hichan1 task record: S13 interval-nest validator and numbering policy

completed_tasks:

- Created branch `hichan` from latest `origin_vespa_tdx` commit `8fcd455a456a8c196e77ce7694d6ab5c6ed609bb`.
- Created branch `hichan1` from the same baseline.
- Added `tools/validate_s13_interval_nest_marker_logic.py` on `hichan1`.
- Added `lib/ui/pages/s13_nested_marker_numbering_policy.dart` to pin the confirmed numbering rule.
- Updated `lib/ui/pages/s13_nested_marker_numbering_policy.dart` so candidate-trail and current/final BSP states compare at equal priority.
- The validator checks that step mode reads `analysis.frames[_safeFrameIndex]` instead of final snapshot slicing.
- The validator checks that nested markers use backend `relations` and backend BSP rows only.
- The validator rejects an unconditional first-child-range pattern in `_relationDown`.
- The validator rejects `childStartRawIndex` acting as an implicit BSP anchor without explicit interval-anchor state.
- The validator rejects collapsing multiple lower-level BSP triggers into a single `Set<int>` active raw index.
- The validator checks historical candidate BSPs are UI-only copies and do not mutate backend frame or snapshot objects.
- The manual was updated to record this branch/task process and the equal-priority candidate-trail rule.

validation_result:

- Validator script added.
- Numbering policy helper added.
- Candidate-trail equal-priority policy added to code helper and manual.
- The validator is expected to fail on current S13 page code until the known mapping risks are fixed.
- Main S13 page wiring is not yet logic-accepted because `_nestedBspMarkers` still needs trigger-list hardening.

remaining_risk:

- True remote branch rename could not remove old `origin_vespa_tdx` because the available toolset has no delete-ref operation.
- S13 marker rendering still needs the actual logic hardening step after this validator identifies failures.
- Receiver should run `python tools/validate_s13_interval_nest_marker_logic.py` after pulling `hichan1`.
- The main page must connect the numbering policy and preserve candidate/current trigger identity before App acceptance.

next_task:

- Fix S13 marker mapping to satisfy `tools/validate_s13_interval_nest_marker_logic.py`.
- Replace active raw-index set dedupe with a trigger identity list.
- Connect `S13NestedMarkerNumberingPolicy` to `_nestedBspMarkers` and `_nestedBspMarkerGlyph`.
- Ensure candidate-trail BSP and current/final BSP are both included as equal-priority trigger sources.
- Render sequence labels only when the same active rawIndex has more than one trigger.

## Next task-party operation

1. Receiver pulls latest `hichan1`.
2. Run existing baseline checks:
   - `flutter analyze`
   - `python tools/audit_dart_algorithm_usage.py`
   - `python tools/check_chanpy_guardrails.py`
3. Run the new validator:
   - `python tools/validate_s13_interval_nest_marker_logic.py`
4. Expected current behavior:
   - The validator should pass source-authority checks.
   - The validator should fail known hidden mapping-risk checks until S13 marker logic is hardened.
5. Receiver App validation after later logic hardening:
   - Step through `DAILY,MIN30,MIN5` real data.
   - Verify lower-level BSP appears on higher-level chart.
   - Verify click-through lands on the intended lower-level BSP or explicitly marked interval-only region.
   - Verify multiple lower-level BSPs under one parent K are not visually collapsed into one misleading signal.
   - Verify candidate-trail BSP observations and current/final BSP observations both trigger interval-nest markers with equal priority.
   - Verify count-one marker shows no number, while count-greater-than-one markers show `1`, `2`, `3`, etc.
