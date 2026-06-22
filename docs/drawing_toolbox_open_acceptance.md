# Drawing toolbox open acceptance notes

Branch: `hichan`
Date: 2026-06-22

This task fixes the S13 K-line page drawing-tool entry behavior without directly replacing large Flutter files. It is delivered as a protected local patch script.

## Script

```text
tools/apply_drawing_toolbox_open_patch.py
```

## Patched file

```text
lib/ui/pages/s13_single_stock_replay_page.dart
```

## Problem

The S13 page had two drawing-tool entry points:

1. side-toolbar section button
2. unified tool panel button

The side-toolbar entry selected `trendLine` and opened the toolbox, while the unified tool panel entry only incremented `_toolboxOpenSignal`.

The chart invocation also passed an empty callback:

```dart
onToolboxQuickToolAdded: (_) {},
```

That made `TradingViewToolboxHost` think an external quick-tool rail existed, so its internal quick-tool rail was disabled while the external callback did nothing.

## Expected behavior after patch

1. Both drawing entry buttons use the same `_openDrawingToolbox()` helper.
2. Clicking either button selects `TradingViewDrawingTool.trendLine`.
3. Clicking either button increments `_toolboxOpenSignal`, so the toolbox panel opens.
4. The user sees a message: `已打开画线工具：趋势线，请在K线图上点击锚点。`
5. The empty quick-tool callback is removed, so the internal quick-tool rail works normally.
6. Existing manual drawing storage and rhythm drawing overlays are not changed.

## Local commands

```bash
git fetch origin
git checkout hichan
git pull origin hichan

python tools/apply_drawing_toolbox_open_patch.py

flutter analyze

git status
git diff -- lib/ui/pages/s13_single_stock_replay_page.dart
```

If analyze passes:

```bash
git add lib/ui/pages/s13_single_stock_replay_page.dart
git commit -m "fix(ui): open drawing toolbox from K-line controls"
git push origin hichan
```

## Manual UI check

Open the S13 K-line page and load replay data. Then verify:

1. Click sidebar `画线 -> 打开画线工具`.
2. The toolbox panel opens.
3. `趋势线` is selected.
4. Click twice on the K-line chart, and a trend line is created.
5. Drag a drawing tool into the quick rail; the internal quick rail should no longer be disabled by an empty external callback.
