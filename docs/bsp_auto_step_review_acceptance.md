# BSP auto step review acceptance notes

Branch: `hichan`
Date: 2026-06-22

## Added in this batch

### 1. Review bucket stats model

File: `lib/core/models/bsp_step_review.dart`

Adds `BspReviewBucketStats` for grouped review statistics.

Grouping key:

```text
level|side|label
```

Fields:

- `appeared`
- `judged`
- `correct`
- `wrong`
- `rate`

### 2. Protected S13 auto-step patch script

File: `tools/apply_bsp_auto_step_review.py`

The script wires automatic step review into `lib/ui/pages/s13_single_stock_replay_page.dart` by exact-match replacements.

It adds:

- `_autoJudgeBspStepReview`, default `true`.
- `_bspReviewBucketStats`.
- `_bspReviewBucketStatsText()`.
- `_updateCurrentBspStepReviews({required bool notify})`.
- Automatic review on:
  - replay load initial frame;
  - `_setFrameIndex()` step changes;
  - enabling the auto-review switch.
- UI controls:
  - `自动检查 BSP` switch;
  - `BSP分组` info.

## Semantics

The existing judge key remains unchanged:

```text
level|rawIndex|side
```

Manual and automatic checks share the same update function.

A BSP is judged:

- `correct` if `level|rawIndex|side` exists in the final snapshot for the active level.
- `wrong` if it does not exist in the final snapshot.
- `pending` before it is checked.

The bucket stats aggregate already-seen review items by:

```text
level|side|label
```

## Local apply commands

```bash
git fetch origin
git checkout hichan
git pull origin hichan

python tools/apply_bsp_auto_step_review.py

flutter analyze

git status
git diff -- lib/ui/pages/s13_single_stock_replay_page.dart

git add lib/ui/pages/s13_single_stock_replay_page.dart
git commit -m "feat(bsp): auto judge step review stats"
git push origin hichan
```

## Not completed in this batch

- Durable persistence to disk across app restarts.
- Exportable review report file.
- Backend-side BSP review computation.
- UI table with sortable columns; current display is compact text.

These are intentionally kept as later steps so the first automatic-review path can be analyzed and tested independently.
