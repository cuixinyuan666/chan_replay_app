from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLBOX = ROOT / 'lib' / 'ui' / 'drawing' / 'tradingview_toolbox_host.dart'
SIDEBAR = ROOT / 'lib' / 'ui' / 'widgets' / 'auto_collapsible_side_toolbar.dart'
S13 = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'
RECURSIVE = ROOT / 'lib' / 'ui' / 'widgets' / 'recursive_seg_origin_kline_chart.dart'


def replace_exact(text: str, old: str, new: str, label: str, expected: int = 1) -> str:
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'[abort] {label}: expected {expected}, got {count}')
    return text.replace(old, new, expected)


def replace_between(text: str, start: str, end: str, new: str, label: str) -> str:
    i = text.find(start)
    if i < 0:
        raise SystemExit(f'[abort] {label}: start not found')
    j = text.find(end, i)
    if j < 0:
        raise SystemExit(f'[abort] {label}: end not found')
    return text[:i] + new + text[j:]


def patch_toolbox_host() -> None:
    text = TOOLBOX.read_text(encoding='utf-8')
    original = text

    text = replace_exact(
        text,
        '  final List<TradingViewDrawingTool> _quickTools = [];\n',
        '',
        'remove quick tools state',
    )

    text = replace_between(
        text,
        '  void _addQuickTool(TradingViewDrawingTool tool) {\n',
        '  @override\n  Widget build(BuildContext context) {\n',
        '  @override\n  Widget build(BuildContext context) {\n',
        'remove quick tool add/remove handlers',
    )

    text = replace_exact(
        text,
        '    final hasExternalQuickRail = widget.onQuickToolAdded != null;\n',
        '',
        'remove external quick rail flag',
    )

    text = replace_between(
        text,
        '        if (!hasExternalQuickRail)\n',
        '        if (!hasExternalButton)\n',
        '        if (!hasExternalButton)\n',
        'remove quick tool rail from stack',
    )

    text = replace_exact(
        text,
        '                Opacity(\n                  opacity: 0.72,\n                  child: _ToolboxPanel(\n',
        '                Listener(\n                  behavior: HitTestBehavior.opaque,\n                  onPointerSignal: (_) {},\n                  child: _ToolboxPanel(\n',
        'replace toolbox opacity wrapper with wheel blocker',
    )

    text = replace_exact(
        text,
        '                    onQuickToolAdded: _handleQuickToolAdded,\n',
        '',
        'remove quick tool callback panel argument',
    )

    text = replace_between(
        text,
        'class _QuickToolRail extends StatelessWidget {\n',
        'class _ToolboxButton extends StatelessWidget {\n',
        'class _ToolboxButton extends StatelessWidget {\n',
        'remove quick tool rail class',
    )

    text = replace_exact(
        text,
        '  final ValueChanged<TradingViewDrawingTool> onQuickToolAdded;\n',
        '',
        'remove panel quick callback field',
        expected=3,
    )

    text = replace_exact(
        text,
        '    required this.onQuickToolAdded,\n',
        '',
        'remove panel quick callback constructor argument',
        expected=3,
    )

    text = replace_exact(
        text,
        '                         onQuickToolAdded: onQuickToolAdded,\n',
        '',
        'remove group quick callback pass',
    )

    text = replace_exact(
        text,
        '             onQuickToolAdded: onQuickToolAdded,\n',
        '',
        'remove tile quick callback pass',
    )

    text = replace_exact(
        text,
        '            color: const Color(0xF2131722),\n',
        '            color: const Color(0x00131722),\n',
        'make toolbox panel background transparent',
    )

    text = replace_exact(
        text,
        """          boxShadow: const [
            BoxShadow(
                blurRadius: 20, offset: Offset(0, 8), color: Color(0x99000000)),
          ],
""",
        '          boxShadow: const [],\n',
        'remove toolbox panel shadow',
    )

    text = replace_exact(
        text,
        """            Expanded(
              child: RawScrollbar(
                thumbVisibility: true,
                interactive: true,
                thickness: 8,
                radius: const Radius.circular(8),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 10),
                  children: [
                    for (final group in groups)
                      _ToolGroupTile(
                        key: PageStorageKey('tv_tool_group_${group.name}'),
                        group: group,
                        tools: grouped[group] ??
                            const <TradingViewDrawingToolMeta>[],
                        selectedTool: selectedTool,
                        hasBars: hasBars,
                        hasChanSnapshot: hasChanSnapshot,
                        isToolAvailable: isToolAvailable,
                        isChanOverlayVisible: isChanOverlayVisible,
                        onChanOverlayToggled: onChanOverlayToggled,
                        additionalChanOverlays:
                            group == TradingViewDrawingGroup.chanOverlay
                                ? additionalChanOverlays
                                : const [],
                        onSelected: onSelected,
                        onQuickToolAdded: onQuickToolAdded,
                        indicatorKeys: indicatorKeys,
                        enabledIndicators: enabledIndicators,
                        onIndicatorToggled: onIndicatorToggled,
                        easyTdxSubPanelCount: easyTdxSubPanelCount,
                        onSubPanelCountChanged: onSubPanelCountChanged,
                      ),
                  ],
                ),
              ),
            ),
""",
        """            Expanded(
              child: _ToolboxPanelList(
                children: [
                  for (final group in groups)
                    _ToolGroupTile(
                      key: PageStorageKey('tv_tool_group_${group.name}'),
                      group: group,
                      tools: grouped[group] ??
                          const <TradingViewDrawingToolMeta>[],
                      selectedTool: selectedTool,
                      hasBars: hasBars,
                      hasChanSnapshot: hasChanSnapshot,
                      isToolAvailable: isToolAvailable,
                      isChanOverlayVisible: isChanOverlayVisible,
                      onChanOverlayToggled: onChanOverlayToggled,
                      additionalChanOverlays:
                          group == TradingViewDrawingGroup.chanOverlay
                              ? additionalChanOverlays
                              : const [],
                      onSelected: onSelected,
                      indicatorKeys: indicatorKeys,
                      enabledIndicators: enabledIndicators,
                      onIndicatorToggled: onIndicatorToggled,
                      easyTdxSubPanelCount: easyTdxSubPanelCount,
                      onSubPanelCountChanged: onSubPanelCountChanged,
                    ),
                ],
              ),
            ),
""",
        'replace toolbox list with controlled scrollbar',
    )

    text = replace_exact(
        text,
        """class _ToolGroupTile extends StatelessWidget {
""",
        """class _ToolboxPanelList extends StatefulWidget {
  final List<Widget> children;

  const _ToolboxPanelList({required this.children});

  @override
  State<_ToolboxPanelList> createState() => _ToolboxPanelListState();
}

class _ToolboxPanelListState extends State<_ToolboxPanelList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerSignal: (_) {},
      child: RawScrollbar(
        controller: _controller,
        thumbVisibility: true,
        interactive: true,
        thickness: 8,
        radius: const Radius.circular(8),
        child: ListView(
          controller: _controller,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 10),
          children: widget.children,
        ),
      ),
    );
  }
}

class _ToolGroupTile extends StatelessWidget {
""",
        'insert controlled toolbox list widget',
    )

    text = replace_between(
        text,
        '    return Draggable<TradingViewDrawingTool>(\n',
        '  }\n}\n\nclass _AdditionalChanOverlayTile extends StatelessWidget {\n',
        '    return tile;\n  }\n}\n\nclass _AdditionalChanOverlayTile extends StatelessWidget {\n',
        'remove tool tile draggable behavior',
    )

    if text == original:
        raise SystemExit('[abort] toolbox host no changes')
    TOOLBOX.write_text(text, encoding='utf-8')


def patch_sidebar() -> None:
    text = SIDEBAR.read_text(encoding='utf-8')
    original = text

    text = replace_exact(
        text,
        """class SideToolbarSection {
  final String title;
  final List<Widget> children;

  const SideToolbarSection({
    required this.title,
    required this.children,
  });
}
""",
        """class SideToolbarSection {
  final String title;
  final List<Widget> children;
  final VoidCallback? onTitleTap;

  const SideToolbarSection({
    required this.title,
    required this.children,
    this.onTitleTap,
  });
}
""",
        'add sidebar section title tap callback',
    )

    text = replace_exact(
        text,
        '            behavior: HitTestBehavior.translucent,\n            onPointerSignal: _handlePointerSignal,\n',
        '            behavior: HitTestBehavior.opaque,\n            onPointerSignal: _handlePointerSignal,\n',
        'make side toolbar wheel hit-test opaque',
    )

    text = replace_exact(
        text,
        '                _SectionDivider(title: sections[i].title),\n',
        '                _SectionDivider(\n                    title: sections[i].title,\n                    onTap: sections[i].onTitleTap,\n                  ),\n',
        'wire sidebar section title tap',
    )

    text = replace_between(
        text,
        'class _SectionDivider extends StatelessWidget {\n',
        'class _ToolbarToggleButton extends StatelessWidget {\n',
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

class _ToolbarToggleButton extends StatelessWidget {
""",
        'replace section divider with clickable variant',
    )

    if text == original:
        raise SystemExit('[abort] sidebar no changes')
    SIDEBAR.write_text(text, encoding='utf-8')


def patch_s13() -> None:
    text = S13.read_text(encoding='utf-8')
    original = text

    text = replace_exact(
        text,
        """        SideToolbarSection(
          title: '画线',
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _openDrawingToolbox,
                icon: const Icon(Icons.architecture, size: 18),
                label: const Text('打开画线工具'),
              ),
            ),
          ],
        ),
""",
        """        SideToolbarSection(
          title: '画线工具',
          onTitleTap: _openDrawingToolbox,
          children: const <Widget>[],
        ),
""",
        'make side toolbar drawing section title open toolbox directly',
    )

    if text == original:
        raise SystemExit('[abort] s13 page no changes')
    S13.write_text(text, encoding='utf-8')


def patch_recursive_chart() -> None:
    text = RECURSIVE.read_text(encoding='utf-8')
    original = text

    text = replace_between(
        text,
        '  List<DrawingObject> _recursiveSegBspDrawingObjects(ChanSnapshot snapshot) {\n',
        '  List<DrawingObject> _recursiveSegZsDrawingObjects(ChanSnapshot snapshot) {\n',
        """  List<DrawingObject> _recursiveSegBspDrawingObjects(ChanSnapshot snapshot) {
    // Main-chart recursive BSP price labels are intentionally suppressed.
    // The bottom BSP band is the only BSP text authority on the K-line page.
    return const <DrawingObject>[];
  }

""" + '  List<DrawingObject> _recursiveSegZsDrawingObjects(ChanSnapshot snapshot) {\n',
        'suppress recursive BSP price labels on main chart',
    )

    if text == original:
        raise SystemExit('[abort] recursive chart no changes')
    RECURSIVE.write_text(text, encoding='utf-8')


def main() -> None:
    patch_toolbox_host()
    patch_sidebar()
    patch_s13()
    patch_recursive_chart()
    print('Drawing toolbar cleanup patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
