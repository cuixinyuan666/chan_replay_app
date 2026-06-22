# BSP step review overlay acceptance notes

Branch: `hichan`
Date: 2026-06-22

## Added in this batch

### 1. Bottom-label overlay widget

File: `lib/ui/widgets/bsp_bottom_label_overlay.dart`

Purpose:

- Draw `BspBottomLabel` rows at the bottom of the main K-line panel.
- Keep it as a visual overlay only; it does not calculate Chan structures.
- Map `rawIndex -> x` using the same visible window assumptions as the K-line painter.
- Support `pending / correct / wrong` visual states:
  - `?` pending
  - `✓` correct
  - `×` wrong

### 2. Protected S13 patch script

File: `tools/apply_bsp_step_review_overlay.py`

The script wires the new overlay into `lib/ui/pages/s13_single_stock_replay_page.dart` by exact-match replacements:

- Imports `bsp_step_review.dart`.
- Imports `bsp_bottom_label_overlay.dart`.
- Adds frozen review state:
  - `_bspStepReviewItems`
  - `_bspStepReviewCorrectKeys`
  - `_bspStepReviewWrongKeys`
- Adds review helpers:
  - `_bspReviewJudgeKey(level, bsp)` where judge key is `level|rawIndex|side`.
  - `_currentBspStepReviewItems`.
  - `_bspBottomLabels`.
  - `_bspReviewStats`.
  - `_judgeCurrentBspStepReviews()`.
- Adds UI controls:
  - `检查当前买卖点`.
  - `BSP统计`.
- Adds `BspBottomLabelOverlay` above the interval-nest marker layer.

## Local apply commands

```bash
# make sure you are on hichan and synced
git fetch origin
git checkout hichan
git pull origin hichan

# apply patch
python tools/apply_bsp_step_review_overlay.py

# verify
flutter analyze

git status
git diff -- lib/ui/pages/s13_single_stock_replay_page.dart

# commit and push if analyze passes
git add lib/ui/pages/s13_single_stock_replay_page.dart
git commit -m "feat(bsp): wire step review bottom labels"
git push origin hichan
```

## Current semantics

Manual `检查当前买卖点` compares BSP rows visible up to the current step frame against final once snapshot BSP rows on the same active level.

The current judge key is intentionally strict and stable:

```text
level|rawIndex|side
```

A candidate/current BSP is judged:

- `correct` if the same `level|rawIndex|side` exists in the final snapshot.
- `wrong` if it does not exist in the final snapshot.
- `pending` before manual check.

## Not completed in this batch

- Automatic judgment on each step advance.
- User-editable judgment override.
- Persistence of review state across app restarts.
- Backend-side review computation.
- Rich confusion matrix by BSP type and level.

These should remain separate to avoid turning the K-line painter into a strategy/statistics engine.
