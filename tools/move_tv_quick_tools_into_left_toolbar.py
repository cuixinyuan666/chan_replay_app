#!/usr/bin/env python3
"""Move TV quick tools into the page left toolbar.

This is a follow-up to the drag-refinement patch. The previous patch made a
chart-side quick tool rail. This patch changes the ownership so that:
- The left edge drawer owns the TV quick tool drop zone and shortcut buttons.
- TV toolbox tiles remain draggable sources.
- Dropping a tool into the left toolbar pins it there.
- Tapping a pinned quick tool selects that TV drawing tool in OriginKlineChart.

Run:
  python tools/move_tv_quick_tools_into_left_toolbar.py --check
  python tools/move_tv_quick_tools_into_left_toolbar.py --apply
  flutter analyze
"""
from __future__ import annotations

import argparse
from pathlib import Path

PAGE = Path("lib/ui/pages/origin_replay_page_v2.dart")
CHART = Path("lib/ui/widgets/origin_kline_chart.dart")
TOOLBOX = Path("lib/ui/drawing/tradingview_toolbox_host.dart")


def replace_once(src: str, old: str, new: str, label: str):
    if new in src:
        return src, False, f"OK {label}"
    if old not in src:
        return src, False, f"SKIP {label}"
    return src.replace(old, new, 1), True, f"APPLY {label}"


def replace_method(src: str, signature: str, new_method: str, label: str):
    if new_method in src:
        return src, False, f"OK {label}"
    start = src.find(signature)
    if start < 0:
        return src, False, f"SKIP {label}: signature not found"
    open_brace = src.find('{', start)
    if open_brace < 0:
        return src, False, f"SKIP {label}: open brace not found"
    depth = 0
    end = -1
    for i in range(open_brace, len(src)):
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end < 0:
        return src, False, f"SKIP {label}: close brace not found"
    return src[:start] + new_method + src[end:], True, f"APPLY {label}"


PAGE_HELPERS = r'''  void _addQuickTvTool(TradingViewDrawingTool tool) {
    if (_quickTvTools.contains(tool)) return;
    setState(() => _quickTvTools.add(tool));
  }

  void _removeQuickTvTool(TradingViewDrawingTool tool) {
    setState(() => _quickTvTools.remove(tool));
  }

  void _selectQuickTvTool(TradingViewDrawingTool tool) {
    _tvToolSelectSignal.value = null;
    _tvToolSelectSignal.value = tool;
    _tvToolboxOpenSignal.value++;
  }

  IconData _quickTvToolIcon(TradingViewDrawingTool tool) {
    return switch (tool) {
      TradingViewDrawingTool.chanFx => Icons.filter_center_focus,
      TradingViewDrawingTool.chanFxLine => Icons.timeline,
      TradingViewDrawingTool.chanFxText => Icons.format_color_text,
      TradingViewDrawingTool.chanBi => Icons.edit_note,
      TradingViewDrawingTool.chanBiText => Icons.format_color_text,
      TradingViewDrawingTool.chanSeg => Icons.account_tree,
      TradingViewDrawingTool.chanSegText => Icons.short_text,
      TradingViewDrawingTool.chanZs => Icons.select_all,
      TradingViewDrawingTool.chanBiBsp => Icons.shopping_cart_checkout,
      TradingViewDrawingTool.chanSegBsp => Icons.sell_outlined,
      TradingViewDrawingTool.chanMergedBars => Icons.view_week,
      _ => Icons.architecture,
    };
  }

  Widget _buildTvQuickToolDropZone() {
    return DragTarget<TradingViewDrawingTool>(
      onAcceptWithDetails: (details) => _addQuickTvTool(details.data),
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(vertical: 4),
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1E3A8A) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: active ? const Color(0xFF8AB4FF) : Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                waitDuration: const Duration(seconds: 3),
                message: '拖拽 TV 工具到这里固定为左侧快捷按钮',
                child: Icon(active ? Icons.add_circle : Icons.push_pin_outlined,
                    size: 18, color: Colors.white70),
              ),
              for (final tool in _quickTvTools)
                Tooltip(
                  waitDuration: const Duration(seconds: 3),
                  message: '${TradingViewDrawingToolRegistry.metaOf(tool).label}\n右键或长按移出快捷栏',
                  child: GestureDetector(
                    onTap: () => _selectQuickTvTool(tool),
                    onLongPress: () => _removeQuickTvTool(tool),
                    onSecondaryTap: () => _removeQuickTvTool(tool),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_quickTvToolIcon(tool), size: 17, color: Colors.white70),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

'''


def patch_page(src: str):
    changed = False
    notes = []
    if '_tvToolSelectSignal' not in src:
        src, did, note = replace_once(
            src,
            '  final ValueNotifier<int> _tvToolboxOpenSignal = ValueNotifier<int>(0);\n',
            '  final ValueNotifier<int> _tvToolboxOpenSignal = ValueNotifier<int>(0);\n  final ValueNotifier<TradingViewDrawingTool?> _tvToolSelectSignal =\n      ValueNotifier<TradingViewDrawingTool?>(null);\n  final List<TradingViewDrawingTool> _quickTvTools = [];\n',
            'page quick tv fields',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK page quick tv fields')
    if '_tvToolSelectSignal.dispose();' not in src:
        src, did, note = replace_once(
            src,
            '    _tvToolboxOpenSignal.dispose();\n',
            '    _tvToolboxOpenSignal.dispose();\n    _tvToolSelectSignal.dispose();\n',
            'page dispose tv select signal',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK page dispose tv select signal')
    if 'void _addQuickTvTool(' not in src:
        src, did, note = replace_once(
            src,
            '  Widget _buildLeftToolbar() {\n',
            PAGE_HELPERS + '  Widget _buildLeftToolbar() {\n',
            'page quick tv helpers',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK page quick tv helpers')
    if '_buildTvQuickToolDropZone(),' not in src:
        src, did, note = replace_once(
            src,
            "                        _toolIcon('TV 工具箱', Icons.architecture,\n                            () => _tvToolboxOpenSignal.value++),\n",
            "                        _toolIcon('TV 工具箱', Icons.architecture,\n                            () => _tvToolboxOpenSignal.value++),\n                        _buildTvQuickToolDropZone(),\n",
            'page insert quick tv drop zone',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK page insert quick tv drop zone')
    if 'toolboxSelectedToolSignal: _tvToolSelectSignal,' not in src:
        src, did, note = replace_once(
            src,
            '                  toolboxOpenSignal: _tvToolboxOpenSignal,\n',
            '                  toolboxOpenSignal: _tvToolboxOpenSignal,\n                  toolboxSelectedToolSignal: _tvToolSelectSignal,\n                  onToolboxQuickToolAdded: _addQuickTvTool,\n',
            'page pass quick tv signals',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK page pass quick tv signals')
    return src, changed, notes


def patch_chart(src: str):
    changed = False
    notes = []
    if 'toolboxSelectedToolSignal;' not in src:
        src, did, note = replace_once(
            src,
            '  final ValueListenable<int>? toolboxOpenSignal;\n',
            '  final ValueListenable<int>? toolboxOpenSignal;\n  final ValueListenable<TradingViewDrawingTool?>? toolboxSelectedToolSignal;\n  final ValueChanged<TradingViewDrawingTool>? onToolboxQuickToolAdded;\n',
            'chart quick tv fields',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chart quick tv fields')
    if 'this.toolboxSelectedToolSignal,' not in src:
        src, did, note = replace_once(
            src,
            '    this.toolboxOpenSignal,\n',
            '    this.toolboxOpenSignal,\n    this.toolboxSelectedToolSignal,\n    this.onToolboxQuickToolAdded,\n',
            'chart quick tv constructor params',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chart quick tv constructor params')
    if 'widget.toolboxSelectedToolSignal?.addListener(_handleExternalToolSelection);' not in src:
        src, did, note = replace_once(
            src,
            '    _loadPersistedDrawings();\n',
            '    _loadPersistedDrawings();\n    widget.toolboxSelectedToolSignal?.addListener(_handleExternalToolSelection);\n',
            'chart listen external tool selection init',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chart listen external tool selection init')
    if 'oldWidget.toolboxSelectedToolSignal?.removeListener(_handleExternalToolSelection);' not in src:
        src, did, note = replace_once(
            src,
            '    if (_effectiveStorageKey != _loadedStorageKey) _loadPersistedDrawings();\n',
            '    if (_effectiveStorageKey != _loadedStorageKey) _loadPersistedDrawings();\n    if (oldWidget.toolboxSelectedToolSignal != widget.toolboxSelectedToolSignal) {\n      oldWidget.toolboxSelectedToolSignal?.removeListener(_handleExternalToolSelection);\n      widget.toolboxSelectedToolSignal?.addListener(_handleExternalToolSelection);\n    }\n',
            'chart update external tool selection listener',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chart update external tool selection listener')
    if 'void _handleExternalToolSelection()' not in src:
        src, did, note = replace_once(
            src,
            '  @override\n  Widget build(BuildContext context) {\n',
            '  @override\n  void dispose() {\n    widget.toolboxSelectedToolSignal?.removeListener(_handleExternalToolSelection);\n    super.dispose();\n  }\n\n  void _handleExternalToolSelection() {\n    final tool = widget.toolboxSelectedToolSignal?.value;\n    if (tool != null) _selectDrawingTool(tool);\n  }\n\n  @override\n  Widget build(BuildContext context) {\n',
            'chart external tool selection handler',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chart external tool selection handler')
    if 'onQuickToolAdded: widget.onToolboxQuickToolAdded,' not in src:
        src, did, note = replace_once(
            src,
            '      onChanOverlayToggled: widget.onChanOverlayToggled,\n',
            '      onChanOverlayToggled: widget.onChanOverlayToggled,\n      onQuickToolAdded: widget.onToolboxQuickToolAdded,\n',
            'chart pass quick tool callback to host',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK chart pass quick tool callback to host')
    return src, changed, notes


def patch_toolbox(src: str):
    changed = False
    notes = []
    if 'final ValueChanged<TradingViewDrawingTool>? onQuickToolAdded;' not in src:
        src, did, note = replace_once(
            src,
            '  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n',
            '  final ValueChanged<TradingViewDrawingTool>? onChanOverlayToggled;\n  final ValueChanged<TradingViewDrawingTool>? onQuickToolAdded;\n',
            'toolbox quick callback field',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK toolbox quick callback field')
    if 'this.onQuickToolAdded,' not in src:
        src, did, note = replace_once(
            src,
            '    this.onChanOverlayToggled,\n',
            '    this.onChanOverlayToggled,\n    this.onQuickToolAdded,\n',
            'toolbox quick callback constructor',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK toolbox quick callback constructor')
    if 'void _handleQuickToolAdded(TradingViewDrawingTool tool)' not in src:
        src, did, note = replace_once(
            src,
            '  void _removeQuickTool(TradingViewDrawingTool tool) {\n    setState(() => _quickTools.remove(tool));\n  }\n',
            '  void _removeQuickTool(TradingViewDrawingTool tool) {\n    setState(() => _quickTools.remove(tool));\n  }\n\n  void _handleQuickToolAdded(TradingViewDrawingTool tool) {\n    final external = widget.onQuickToolAdded;\n    if (external != null) {\n      external(tool);\n      return;\n    }\n    _addQuickTool(tool);\n  }\n',
            'toolbox quick callback dispatcher',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK toolbox quick callback dispatcher')
    if 'final hasExternalQuickRail = widget.onQuickToolAdded != null;' not in src:
        src, did, note = replace_once(
            src,
            '    final hasExternalButton = widget.openSignal != null;\n',
            '    final hasExternalButton = widget.openSignal != null;\n    final hasExternalQuickRail = widget.onQuickToolAdded != null;\n',
            'toolbox external quick rail flag',
        )
        changed |= did
        notes.append(note)
    else:
        notes.append('OK toolbox external quick rail flag')
    src, did, note = replace_once(
        src,
        '        Positioned(\n          left: hasExternalButton ? 54 : 8,\n          top: 8,\n          bottom: 12,\n          child: _QuickToolRail(\n            tools: _quickTools,\n            selectedTool: selected,\n            onAcceptTool: _addQuickTool,\n            onRemoveTool: _removeQuickTool,\n            onSelected: _selectTool,\n          ),\n        ),\n',
        '        if (!hasExternalQuickRail)\n          Positioned(\n            left: hasExternalButton ? 54 : 8,\n            top: 8,\n            bottom: 12,\n            child: _QuickToolRail(\n              tools: _quickTools,\n              selectedTool: selected,\n              onAcceptTool: _addQuickTool,\n              onRemoveTool: _removeQuickTool,\n              onSelected: _selectTool,\n            ),\n          ),\n',
        'toolbox hide internal quick rail when external exists',
    )
    changed |= did
    notes.append(note)
    src, did, note = replace_once(
        src,
        '              onQuickToolAdded: _addQuickTool,\n',
        '              onQuickToolAdded: _handleQuickToolAdded,\n',
        'toolbox use quick callback dispatcher',
    )
    changed |= did
    notes.append(note)
    return src, changed, notes


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--check', action='store_true')
    group.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    paths = [(PAGE, patch_page), (CHART, patch_chart), (TOOLBOX, patch_toolbox)]
    changed_any = False
    all_notes = []
    for path, patcher in paths:
        if not path.exists():
            print(f'FAIL missing {path}')
            return 1
        src = path.read_text(encoding='utf-8')
        target, changed, notes = patcher(src)
        changed_any |= changed
        all_notes.extend(f'{path}: {note}' for note in notes)
        if args.apply and changed:
            path.write_text(target, encoding='utf-8')
    for note in all_notes:
        print(note)
    print(('UPDATED' if changed_any else 'NOOP already applied') if args.apply else ('PASS can apply' if changed_any else 'PASS already applied'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
