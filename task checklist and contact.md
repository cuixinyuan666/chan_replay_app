# task checklist and contact

Branch: origin_vespa_tdx

Last supervisor update: 2026-06-15

## Open questions

- S13 interval-nest / nested BSP marker implementation is code-complete but still needs logic-risk validation against real step frames.
- Main review question: whether current interval nesting display has hidden logical errors, especially when one parent K maps to multiple child ranges or when a lower-level BSP maps upward without a same-bar higher-level BSP.

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
- S12e shared marker-overlap policy for S12 chart and evidence markers: accepted by receiver CLI + App evidence.
- S13 single-stock multi-level replay workspace UI optimizations: implementation completed; `flutter analyze` passed; App visual validation remains required.
- S13 touch-friendly unified toolbar, date picker, full-step replay controls, draggable controls, and clean BSP labels: implementation completed; `flutter analyze` passed; App visual validation remains required.
- S13 native multi-level step frames through `CChan(lv_list=[...]).step_load()` and compact frame transport: implementation completed in code; dedicated S13 CLI/native validator remains required.
- S13 nested BSP marker overlay, lower-level BSP upward trigger, loaded-level switcher, and BSP candidate persistence: implementation completed in code; hidden logic review remains required.
- S13 default publish prep: start date `2026-01-01`, end date `system current date - 2 days`, replay mode `step`; `flutter analyze` passed.
- hichanhuancun stage-1 backend cache/lazy-layer/BSP-freeze/anti-future contracts: implementation completed in code; dedicated static validator added as `python tools/validate_hichanhuancun_contracts.py`.
- hichanhuancun cache optimization page: implementation completed in code as a new same-level root page `缓存优化`; dedicated static validator updated.
- hichanhuancun chart_lazy_layers v2 transport pruning loop: implementation completed in code; backend prunes returned layer payload by request and App page can send layer requests and display returned manifest.

## Current selected task

hichanhuancun chart_lazy_layers v2 transport pruning validation is selected.

Current supervisor position:

- S12 full evidence chain is complete.
- S13 implementation work is recorded as code-complete but not fully accepted as logic-verified.
- No new Chan algorithm authority is granted to Flutter/Dart.
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

### S4-S7

- S4 accepted: CLI strategy diagnostics validator.
- S5 accepted: CLI strategy rule matrix validation for `DAILY_2B_MIN30_1B`, `DAILY_3B_MIN30_1B`, and `DAILY_3B_MIN30_2B`.
- S6 accepted: strategy signal sample coverage, including matched-output metadata and no-output diagnostic path.
- S7 accepted: App strategy signal display loop, selected-signal callback, raw-index jump, chart marker wiring, and copy evidence.
