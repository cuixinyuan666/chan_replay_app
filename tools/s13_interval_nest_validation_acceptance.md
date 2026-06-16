# S13 interval-nest marker validation acceptance

Branch: `hichanqujiantao`

Receiver validation date: 2026-06-15

## Result

S13 interval-nest marker hidden logic hardening is expected to be accepted by receiver CLI validation after pulling `hichanqujiantao`.

This branch keeps the S13 interval-nest evidence workflow inside the existing single-stock multi-level replay page. It must not add a separate top-level `区间套` / `S13` / `hichanqujiantao` page, so future merges with `hichan` sibling pages can keep their own route entries without moving S13 evidence out of `S13SingleStockReplayPage`.

## Receiver command bundle

```bash
git pull
python tools/validate_s13_interval_nest_marker_logic.py
python tools/audit_dart_algorithm_usage.py
python tools/check_chanpy_guardrails.py
flutter analyze
```

## Expected validator coverage

- S13 step replay reads backend step frames instead of final-snapshot slicing.
- Nested markers use backend relations and backend BSP rows only.
- Candidate-trail and current BSP triggers keep equal trigger priority while preserving identity.
- Copied evidence starts with `S13_INTERVAL_NEST_MARKER_EVIDENCE`.
- Evidence includes request/runtime/frame/level/count fields, trigger samples, frame provenance, and missing adjacent relation edge diagnostics.
- S13 page integration stays inside the single-stock multi-level replay route and does not add a new top-level page.
