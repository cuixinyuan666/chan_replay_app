# BSP review JSON export acceptance notes

Branch: `hichan`
Date: 2026-06-22

## Added

File: `tools/apply_bsp_review_json_export.py`

The protected script adds BSP review report export into `lib/ui/pages/s13_single_stock_replay_page.dart`.

It adds these page helpers:

- `_allBspStepReviewItems`
- `_bspReviewReportJson()`
- `_bspReviewReportText()`
- `_copyBspReviewReport()`
- `_exportBspReviewReportJson()`

It also adds two UI buttons:

- `复制BSP报告`
- `导出BSP JSON`

## Report schema

Schema name: `chan_replay_app.bsp_review_report.v1`

The report records symbol, market, mode, active level, loaded levels, runtime path, replay window, frame state, auto judge flag, summary stats, bucket stats, and individual BSP review items.

The judge key remains:

```text
level|rawIndex|side
```

## Local apply commands

```bash
git fetch origin
git checkout hichan
git pull origin hichan
python tools/apply_bsp_review_json_export.py
flutter analyze
git status
git diff -- lib/ui/pages/s13_single_stock_replay_page.dart
git add lib/ui/pages/s13_single_stock_replay_page.dart
git commit -m "feat(bsp): export review report json"
git push origin hichan
```

## Deferred

CSV export, automatic save on every step, loading previous JSON back into UI, and user-selected save location are intentionally deferred.
