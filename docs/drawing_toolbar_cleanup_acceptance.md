# Drawing toolbar cleanup acceptance notes

Branch: `hichan`
Date: 2026-06-22

This patch batch cleans the K-line drawing toolbar behavior and removes duplicate BSP text overlays from the main chart. It is delivered as a protected local patch script.

## Script

```text
tools/apply_drawing_toolbar_cleanup_patch.py
```

## Patched files

```text
lib/ui/drawing/tradingview_toolbox_host.dart
lib/ui/widgets/auto_collapsible_side_toolbar.dart
lib/ui/pages/s13_single_stock_replay_page.dart
lib/ui/widgets/recursive_seg_origin_kline_chart.dart
```

## Expected behavior

### 1. Remove the left fixed quick-tool icon

The fixed icon with tooltip text:

```text
拖拽工具到这里，形成左侧快捷工具栏
```

is removed.

The drag-to-quick-rail behavior is disabled. Tool rows are no longer `Draggable`.

### 2. Open drawing tools directly from the side toolbar title

In the S13 K-line page, the side toolbar section changes from:

```text
画线 -> 打开画线工具
```

to a clickable section title:

```text
画线工具
```

Clicking the section title directly opens the drawing toolbox and selects `trendLine`.

### 3. Toolbox panel background transparency

The drawing toolbox panel background is made transparent. The panel content remains visible and clickable.

This is intentionally not implemented as `Opacity(opacity: 0)` on the whole panel, because that would make the tool buttons invisible and unusable.

### 4. Wheel scrolling in toolbox no longer zooms the K-line chart

The toolbox panel now blocks pointer-wheel signals at the panel boundary. Scrolling inside the toolbox should not trigger K-line zoom.

### 5. Toolbox right scrollbar becomes usable

The toolbox list now uses a dedicated `ScrollController` shared by `RawScrollbar` and `ListView`, so the right scrollbar thumb can be dragged.

### 6. Remove residual main-chart recursive BSP text

Main-chart recursive BSP price labels such as:

```text
2段候选SEG2_S
2段B2
2段B2
```

are suppressed. BSP text authority remains the bottom layered BSP band only.

## Local commands

```bash
git fetch origin
git checkout hichan
git pull origin hichan

python tools/apply_drawing_toolbar_cleanup_patch.py

flutter analyze

git status
git diff -- lib/ui/drawing/tradingview_toolbox_host.dart \
            lib/ui/widgets/auto_collapsible_side_toolbar.dart \
            lib/ui/pages/s13_single_stock_replay_page.dart \
            lib/ui/widgets/recursive_seg_origin_kline_chart.dart
```

If analyze passes:

```bash
git add lib/ui/drawing/tradingview_toolbox_host.dart \
        lib/ui/widgets/auto_collapsible_side_toolbar.dart \
        lib/ui/pages/s13_single_stock_replay_page.dart \
        lib/ui/widgets/recursive_seg_origin_kline_chart.dart

git commit -m "fix(ui): clean drawing toolbar interactions"
git push origin hichan
```

## Manual UI checks

1. K-line left side should no longer show the fixed quick-tool icon.
2. Side toolbar section `画线工具` should open the toolbox directly.
3. Drawing toolbox background should be transparent, while buttons remain visible/clickable.
4. Mouse wheel over the toolbox should scroll the toolbox and should not zoom the K-line chart.
5. The right scrollbar thumb in the toolbox should be draggable.
6. The K-line main chart should not show recursive BSP text labels; only the bottom BSP band should show BSP text.
