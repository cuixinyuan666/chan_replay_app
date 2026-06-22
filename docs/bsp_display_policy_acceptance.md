# BSP display policy acceptance notes

Branch: `hichan`
Date: 2026-06-22

This batch is intentionally delivered as a protected local patch script instead of directly replacing large Flutter source files.

## Script

```text
tools/apply_bsp_display_policy_patch.py
```

## Scope

The script patches four files:

```text
lib/ui/widgets/origin_kline_chart.dart
lib/ui/widgets/recursive_seg_origin_kline_chart.dart
lib/ui/pages/research_backtest_page.dart
test/recursive_seg_label_test.dart
```

## Expected behavior

### 1. Near-candle BSP markers hidden

The K-line candle-area BSP triangles and near-candle BSP text are hidden.

The bottom layered BSP band becomes the only visual BSP text authority on the K-line page.

### 2. Bottom BSP text remains layered and colored

Already retained from the previous safe commit:

```text
2段/N段 sell: sky blue
段 sell: green
笔 sell: light blue
all buy levels: red
```

### 3. Recursive N-seg auto display

The K-line page no longer depends on `LevelPromoterSettings.currentMaxLayer` for the default recursive segment max layer.

Default max layer is inferred from actual snapshot data:

```text
recursiveSegLayers
recursiveSegBsps
recursiveSegBspCandidates
recursiveSegZss
```

If the snapshot has 7-seg data, the chart can show 7段 line/BSP without manually changing the level promoter max layer.

### 4. Research/backtest `other` layer

The segN rule editor structure-layer dropdown now has:

```text
2段
3段
4段
5段
6段
other
```

Selecting `other` opens a numeric input for manual N段. The generated JSON still sends `layer` as an integer, so backend payload shape remains compatible.

### 5. Type consistency test

The test file is updated so it proves the shared type body formatter is used:

```text
buy3a -> B3a
卖2 -> S2
笔B3a / 2段B3a share the same B3a body
段S2 shares the same S2 body
```

## Local commands

```bash
git fetch origin
git checkout hichan
git pull origin hichan

python tools/apply_bsp_display_policy_patch.py

flutter analyze
flutter test test/recursive_seg_label_test.dart

git status
git diff -- lib/ui/widgets/origin_kline_chart.dart lib/ui/widgets/recursive_seg_origin_kline_chart.dart lib/ui/pages/research_backtest_page.dart test/recursive_seg_label_test.dart
```

If analyze and the targeted test pass:

```bash
git add lib/ui/widgets/origin_kline_chart.dart \
        lib/ui/widgets/recursive_seg_origin_kline_chart.dart \
        lib/ui/pages/research_backtest_page.dart \
        test/recursive_seg_label_test.dart

git commit -m "fix(bsp): apply bottom-only BSP display policy"
git push origin hichan
```
