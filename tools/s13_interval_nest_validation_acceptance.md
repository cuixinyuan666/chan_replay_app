# S13 interval-nest marker validation acceptance

Branch: `hichan1`

Receiver validation date: 2026-06-15

## Result

S13 interval-nest marker hidden logic hardening is accepted by receiver CLI validation.

## Receiver command bundle

```bash
git pull
flutter analyze
python tools/audit_dart_algorithm_usage.py
python tools/check_chanpy_guardrails.py
python tools/validate_s13_interval_nest_marker_logic.py
```

## Evidence summary

- `git pull` fast-forwarded `hichan1` to `21b405f1c7661731e983fda86d9bad7216b71904`.
- `flutter analyze` passed with `No issues found`.
- `python tools/audit_dart_algorithm_usage.py` passed with `blocking_count: 0`.
- `python tools/check_chanpy_guardrails.py` produced no blocking failure.
- `python tools/validate_s13_interval_nest_marker_logic.py` passed with `ok: true`.
- Validator `missing_required` is empty.
- Validator `review_notes` is empty.
- Validator reports `chan_recalculated: false`.
- Validator reports `dart_chan_calculation_authority: false`.

## Accepted S13 interval-nest rules

- Strict step replay reads backend step frames, not final-snapshot slicing.
- Nested markers use backend `MultiLevelChanSnapshot.relations` and backend BSP rows only.
- `_relationDown` must reject ambiguous first-child-range selection.
- `childStartRawIndex` is an interval anchor, not a BSP anchor.
- Multiple lower-level BSP observations mapped to the same higher-level K are preserved as distinct triggers.
- Count-one trigger groups show an arrow without a numeric label.
- Count-greater-than-one trigger groups show numeric labels beside arrows.
- Candidate-trail BSP observations and current/final BSP observations have equal interval-nest trigger priority.
- Historical candidate BSPs remain UI-only and must not mutate backend frames, final snapshots, or `python/chan.py` structures.

## Remaining non-blocking work

- App visual validation is still required for marker density, tap target ergonomics, candidate/current visual clarity, and real click-through behavior.
- Optional cleanup: remove the stale `_firstBspInRange` helper and then remove `unused_element: ignore` from `analysis_options.yaml`.
