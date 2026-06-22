from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TOOLBOX = ROOT / 'lib' / 'ui' / 'drawing' / 'tradingview_toolbox_host.dart'
SIDEBAR = ROOT / 'lib' / 'ui' / 'widgets' / 'auto_collapsible_side_toolbar.dart'
S13 = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'
RECURSIVE = ROOT / 'lib' / 'ui' / 'widgets' / 'recursive_seg_origin_kline_chart.dart'


def subn(pattern: str, repl: str, text: str, label: str, expected: int = 1, flags: int = 0) -> str:
    next_text, count = re.subn(pattern, repl, text, count=expected, flags=flags)
    if count != expected:
        raise SystemExit(f'[abort] {label}: expected {expected}, got {count}')
    return next_text


def require_contains(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f'[abort] {label}: not found')


def patch_toolbox_host() -> None:
    text = TOOLBOX.read_text(encoding='utf-8')
    original = text

    text = subn(
        r"final hasExternalQuickRail = widget\.onQuickToolAdded != null;",
        "// Quick-tool rail is disabled by product policy; do not render the left fixed icon.\n    const hasExternalQuickRail = true;",
        text,
        'disable quick tool rail rendering',
    )

    text = subn(
        r"final List<TradingViewDrawingTool> _quickTools = \[\];\n  Offset\? _panelOffset;",
        "Offset? _panelOffset;\n  final ScrollController _toolboxScrollController = ScrollController();",
        text,
        'add toolbox scroll controller',
    )

    text = subn(
        r"(void dispose\(\) \{\n\s*widget\.openSignal\?\.removeListener\(_handleOpenSignal\);\n)(\s*super\.dispose\(\);)",
        r"\1    _toolboxScrollController.dispose();\n\2",
        text,
        'dispose toolbox scroll controller',
    )

    text = subn(
        r"Opacity\(\n\s*opacity: 0\.72,\n\s*child: _ToolboxPanel\(",
        "Listener(\n                  behavior: HitTestBehavior.opaque,\n                  onPointerSignal: (_) {},\n                  child: _ToolboxPanel(",
        text,
        'replace toolbox opacity wrapper with wheel blocker',
    )

    text = subn(
        r"(child: _ToolboxPanel\(\n\s*selectedTool: selected,)",
        r"\1\n                    scrollController: _toolboxScrollController,",
        text,
        'pass scroll controller to toolbox panel',
    )

    text = subn(
        r"color: const Color\(0xF2131722\),",
        "color: const Color(0x00131722),",
        text,
        'make toolbox panel background transparent',
    )

    text = subn(
        r"boxShadow:\s*const\s*\[\s*BoxShadow\(\s*blurRadius:\s*20,\s*offset:\s*Offset\(0,\s*8\),\s*color:\s*Color\(0x99000000\)\),\s*\],",
        "boxShadow: const [],",
        text,
        'remove toolbox panel shadow',
        flags=re.S,
    )

    text = subn(
        r"class _ToolboxPanel extends StatelessWidget \{\n\s*final TradingViewDrawingTool selectedTool;",
        "class _ToolboxPanel extends StatelessWidget {\n  final ScrollController scrollController;\n  final TradingViewDrawingTool selectedTool;",
        text,
        'add toolbox panel scroll field',
    )

    text = subn(
        r"const _ToolboxPanel\(\{\n\s*required this\.selectedTool,",
        "const _ToolboxPanel({\n    required this.scrollController,\n    required this.selectedTool,",
        text,
        'add toolbox panel scroll constructor arg',
    )

    text = subn(
        r"child: RawScrollbar\(\n\s*thumbVisibility: true,",
        "child: RawScrollbar(\n                controller: scrollController,\n                thumbVisibility: true,",
        text,
        'wire raw scrollbar controller',
    )

    text = subn(
        r"child: ListView\(\n\s*physics: const ClampingScrollPhysics\(\),",
        "child: ListView(\n                  controller: scrollController,\n                  physics: const ClampingScrollPhysics(),",
        text,
        'wire list view controller',
    )

    text = subn(
        r"return Draggable<TradingViewDrawingTool>\(\s*data: meta\.tool,.*?child: tile,\s*\);",
        "return tile;",
        text,
        'remove draggable tool tile behavior',
        flags=re.S,
    )

    if text == original:
        raise SystemExit('[abort] toolbox host no changes')
    TOOLBOX.write_text(text, encoding='utf-8')


def patch_sidebar() -> None:
    text = SIDEBAR.read_text(encoding='utf-8')
    original = text

    text = subn(
        r"class SideToolbarSection \{\n\s*final String title;\n\s*final List<Widget> children;\n\n\s*const SideToolbarSection\(\{\n\s*required this\.title,\n\s*required this\.children,\n\s*\}\);\n\}",
        "class SideToolbarSection {\n  final String title;\n  final List<Widget> children;\n  final VoidCallback? onTitleTap;\n\n  const SideToolbarSection({\n    required this.title,\n    required this.children,\n    this.onTitleTap,\n  });\n}",
        text,
        'add sidebar section title tap callback',
    )

    text = subn(
        r"behavior: HitTestBehavior\.translucent,\n\s*onPointerSignal: _handlePointerSignal,",
        "behavior: HitTestBehavior.opaque,\n            onPointerSignal: _handlePointerSignal,",
        text,
        'make side toolbar wheel hit-test opaque',
    )

    text = subn(
        r"_SectionDivider\(title: sections\[i\]\.title\),",
        "_SectionDivider(\n                    title: sections[i].title,\n                    onTap: sections[i].onTitleTap,\n                  ),",
        text,
        'wire sidebar section title tap',
    )

    text = subn(
        r"class _SectionDivider extends StatelessWidget \{.*?\n\}\n\nclass _ToolbarToggleButton extends StatelessWidget \{",
        """class _SectionDivider extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _SectionDivider({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: <Widget>[
        const Expanded(child: Divider(color: Colors.white24, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '- $title -',
            style: TextStyle(
              color: onTap == null ? Colors.white70 : const Color(0xFFFFD54F),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white24, height: 1)),
      ],
    );
    if (onTap == null) return row;
    return Tooltip(
      message: '打开$title',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

class _ToolbarToggleButton extends StatelessWidget {""",
        text,
        'replace section divider with clickable variant',
        flags=re.S,
    )

    if text == original:
        raise SystemExit('[abort] sidebar no changes')
    SIDEBAR.write_text(text, encoding='utf-8')


def patch_s13() -> None:
    text = S13.read_text(encoding='utf-8')
    original = text

    text = subn(
        r"SideToolbarSection\(\n\s*title: '画线',\n\s*children: <Widget>\[\n\s*Align\(\n\s*alignment: Alignment\.centerLeft,\n\s*child: FilledButton\.tonalIcon\(\n\s*onPressed: _openDrawingToolbox,\n\s*icon: const Icon\(Icons\.architecture, size: 18\),\n\s*label: const Text\('打开画线工具'\),\n\s*\),\n\s*\),\n\s*\],\n\s*\),",
        "SideToolbarSection(\n          title: '画线工具',\n          onTitleTap: _openDrawingToolbox,\n          children: const <Widget>[],\n        ),",
        text,
        'make side toolbar drawing section title open toolbox directly',
        flags=re.S,
    )

    if text == original:
        raise SystemExit('[abort] s13 page no changes')
    S13.write_text(text, encoding='utf-8')


def patch_recursive_chart() -> None:
    text = RECURSIVE.read_text(encoding='utf-8')
    original = text

    text = subn(
        r"List<DrawingObject> _recursiveSegBspDrawingObjects\(ChanSnapshot snapshot\) \{.*?\n\s*\}\n\n\s*List<DrawingObject> _recursiveSegZsDrawingObjects\(ChanSnapshot snapshot\) \{",
        """List<DrawingObject> _recursiveSegBspDrawingObjects(ChanSnapshot snapshot) {
    // Main-chart recursive BSP price labels are intentionally suppressed.
    // The bottom BSP band is the only BSP text authority on the K-line page.
    return const <DrawingObject>[];
  }

  List<DrawingObject> _recursiveSegZsDrawingObjects(ChanSnapshot snapshot) {""",
        text,
        'suppress recursive BSP price labels on main chart',
        flags=re.S,
    )

    if text == original:
        raise SystemExit('[abort] recursive chart no changes')
    RECURSIVE.write_text(text, encoding='utf-8')


def main() -> None:
    patch_toolbox_host()
    patch_sidebar()
    patch_s13()
    patch_recursive_chart()
    print('Drawing toolbar cleanup v3 patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
