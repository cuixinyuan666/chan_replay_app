# BSP bottom label layer acceptance notes

Branch: `hichan`
Date: 2026-06-22

## Problem checked

The K-line page had two BSP text paths:

1. Near-candle labels, rendered inside `origin_kline_chart.dart` through `BspChartLabelAdapter`.
2. Lower bottom-band labels, rendered by `BspBottomLabelOverlay` from S13 page state.

Before this batch, the two paths did not use the same visual text format, and the lower bottom-band labels only represented the current step review items. Recursive 2-seg/N-seg BSP rows were not fed into the lower bottom-band overlay.

## Fixes

### 1. Unified BSP text type

File: `lib/ui/widgets/bsp_chart_label_adapter.dart`

Adds a shared `displayTypeFor(BspPoint)` and `labelTextFor(...)`.

Examples:

```text
buy3a / 买3a -> B3a
sell2 / 卖2 -> S2
B3a -> B3a
S2 -> S2
```

Near-candle labels and bottom-band labels now use this same formatter.

### 2. Recursive BSP near-candle labels aligned

File: `lib/ui/widgets/recursive_seg_origin_kline_chart.dart`

Recursive BSP price labels now use the shared formatter too, so 2-seg/N-seg labels are rendered like:

```text
2段B3a
3段S2
```

### 3. Bottom-band label overlay no longer collision-stacks

File: `lib/ui/widgets/bsp_bottom_label_overlay.dart`

The bottom overlay now uses fixed visual lanes:

```text
笔  -> lowest lane
段  -> above 笔
2段 -> above 段
3段/N段 -> progressively higher
```

It no longer uses occupied-rect collision avoidance, so labels may overlap/cover each other horizontally instead of being pushed into extra stacked rows when zoomed out.

### 4. Protected S13 patch script

File: `tools/apply_bsp_bottom_label_layers.py`

This script patches `lib/ui/pages/s13_single_stock_replay_page.dart` so the bottom-band labels include:

- native BI BSP as `笔...`
- native SEG BSP as `段...`
- recursive layer BSP as `2段...`, `3段...`, `N段...`

## Answer to the type-consistency question

After this batch, the bottom-band BSP type and the near-candle BSP type share the same `BspChartLabelAdapter.displayTypeFor` normalization. The structure prefix differs by visual level, but the BSP type body is the same.

Example:

```text
near candle: 笔B3a
bottom band: 笔B3a
near candle recursive: 2段B3a
bottom band recursive: 2段B3a
```

## Local apply commands

```bash
git fetch origin
git checkout hichan
git pull origin hichan
python tools/apply_bsp_bottom_label_layers.py
flutter analyze
git status
git diff -- lib/ui/pages/s13_single_stock_replay_page.dart
git add lib/ui/pages/s13_single_stock_replay_page.dart
git commit -m "fix(bsp): show layered bottom BSP labels"
git push origin hichan
```
