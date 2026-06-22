import 'package:flutter/material.dart';

import '../../core/services/replay_analysis_store.dart';
import '../settings/kline_appearance_controller.dart';

enum _SidebarEdge { left, right, top, bottom }

enum _GranularPanelKind { klineAppearance, stock, placeholder }

class FourWayGranularSidebarShell extends StatefulWidget {
  final Widget child;
  final int selectedRouteIndex;
  final ValueChanged<int> onOpenRoute;

  const FourWayGranularSidebarShell({
    super.key,
    required this.child,
    required this.selectedRouteIndex,
    required this.onOpenRoute,
  });

  @override
  State<FourWayGranularSidebarShell> createState() =>
      _FourWayGranularSidebarShellState();
}

class _FourWayGranularSidebarShellState
    extends State<FourWayGranularSidebarShell> {
  static const double _leftCollapsedWidth = 54;
  static const double _leftExpandedWidth = 306;
  static const double _rightCollapsedWidth = 48;
  static const double _rightExpandedWidth = 342;
  static const double _topCollapsedHeight = 34;
  static const double _topExpandedHeight = 88;
  static const double _bottomCollapsedHeight = 34;
  static const double _bottomExpandedHeight = 108;
  static const Duration _animationDuration = Duration(milliseconds: 180);

  bool _leftOpen = false;
  bool _rightOpen = false;
  bool _topOpen = false;
  bool _bottomOpen = false;
  String _activeItemId = 'replay.kline.appearance';
  int? _branchIndex;

  static const List<_NavBranch> _branches = <_NavBranch>[
    _NavBranch('复盘分析', Icons.candlestick_chart, <_NavLeaf>[
      _NavLeaf('单股多级别复盘', Icons.account_tree, 1),
      _NavLeaf('扫描器', Icons.radar, 2),
      _NavLeaf('级别推进器', Icons.double_arrow, 3),
      _NavLeaf('S8 批量候选', Icons.view_list, 4),
    ]),
    _NavBranch('研究工具', Icons.science, <_NavLeaf>[
      _NavLeaf('研究', Icons.science_outlined, 5),
      _NavLeaf('筹码分布', Icons.stacked_bar_chart, 8),
    ]),
    _NavBranch('系统', Icons.settings, <_NavLeaf>[
      _NavLeaf('设置', Icons.tune, 6),
      _NavLeaf('运行日志', Icons.receipt_long, 7),
    ]),
  ];

  static const List<_GranularSidebarItem> _granularItems =
      <_GranularSidebarItem>[
    _GranularSidebarItem(
      id: 'replay.kline.appearance',
      title: 'K图外观',
      icon: Icons.palette_outlined,
      group: '复盘分析',
      page: '单股多级别复盘',
      area: 'K线图',
      edge: _SidebarEdge.right,
      kind: _GranularPanelKind.klineAppearance,
      description: '背景、主题、K线叠加色、透明度。',
    ),
    _GranularSidebarItem(
      id: 'replay.kline.stock',
      title: '股票',
      icon: Icons.query_stats,
      group: '复盘分析',
      page: '单股多级别复盘',
      area: 'K线图',
      edge: _SidebarEdge.right,
      kind: _GranularPanelKind.stock,
      description: 'market、代码、起止日期、级别入口。',
    ),
    _GranularSidebarItem(
      id: 'replay.kline.layers',
      title: '图层显示',
      icon: Icons.layers_outlined,
      group: '复盘分析',
      page: '单股多级别复盘',
      area: 'K线图',
      edge: _SidebarEdge.right,
      kind: _GranularPanelKind.placeholder,
      description: '分型、笔、线段、中枢、买卖点显示入口。',
    ),
    _GranularSidebarItem(
      id: 'replay.kline.rhythm',
      title: '节奏线',
      icon: Icons.show_chart,
      group: '复盘分析',
      page: '单股多级别复盘',
      area: 'K线图',
      edge: _SidebarEdge.right,
      kind: _GranularPanelKind.placeholder,
      description: '1.382节奏线、命中点、层级显示入口。',
    ),
    _GranularSidebarItem(
      id: 'replay.controls',
      title: '回放控制',
      icon: Icons.play_circle_outline,
      group: '复盘分析',
      page: '单股多级别复盘',
      area: '复盘控制',
      edge: _SidebarEdge.bottom,
      kind: _GranularPanelKind.placeholder,
      description: 'once / step、播放速度、窗口、定位。',
    ),
    _GranularSidebarItem(
      id: 'research.scanner.conditions',
      title: '选股条件',
      icon: Icons.filter_alt_outlined,
      group: '研究工具',
      page: '选股/回测',
      area: '扫描器',
      edge: _SidebarEdge.top,
      kind: _GranularPanelKind.placeholder,
      description: '后续承载单股/全市场扫描条件。',
    ),
    _GranularSidebarItem(
      id: 'system.global.theme',
      title: '系统外观',
      icon: Icons.display_settings,
      group: '系统',
      page: '全局设置',
      area: '主题',
      edge: _SidebarEdge.top,
      kind: _GranularPanelKind.placeholder,
      description: '后续承载全局主题、布局密度、窗口设置。',
    ),
  ];

  _GranularSidebarItem get _activeItem => _granularItems.firstWhere(
        (item) => item.id == _activeItemId,
        orElse: () => _granularItems.first,
      );

  double get _leftWidth => _leftOpen ? _leftExpandedWidth : _leftCollapsedWidth;
  double get _rightWidth =>
      _rightOpen ? _rightExpandedWidth : _rightCollapsedWidth;
  double get _topHeight => _topOpen ? _topExpandedHeight : _topCollapsedHeight;
  double get _bottomHeight =>
      _bottomOpen ? _bottomExpandedHeight : _bottomCollapsedHeight;

  void _toggleLeft() => setState(() {
        _leftOpen = !_leftOpen;
        if (!_leftOpen) _branchIndex = null;
      });

  void _openLeftBranch(int index) => setState(() {
        _leftOpen = true;
        _branchIndex = index;
      });

  void _openRoute(_NavLeaf leaf) {
    widget.onOpenRoute(leaf.routeIndex);
    setState(() {
      _leftOpen = false;
      _branchIndex = null;
    });
  }

  void _selectGranularItem(_GranularSidebarItem item) {
    setState(() {
      _activeItemId = item.id;
      switch (item.edge) {
        case _SidebarEdge.left:
          _leftOpen = true;
        case _SidebarEdge.right:
          _rightOpen = true;
        case _SidebarEdge.top:
          _topOpen = true;
        case _SidebarEdge.bottom:
          _bottomOpen = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedPositioned(
          duration: _animationDuration,
          curve: Curves.easeOutCubic,
          left: _leftWidth,
          right: _rightWidth,
          top: _topHeight,
          bottom: _bottomHeight,
          child: ClipRect(child: widget.child),
        ),
        _leftSidebar(),
        _rightSidebar(),
        _topSidebar(),
        _bottomSidebar(),
      ],
    );
  }

  Widget _leftSidebar() => AnimatedPositioned(
        duration: _animationDuration,
        curve: Curves.easeOutCubic,
        left: 0,
        top: 0,
        bottom: 0,
        width: _leftWidth,
        child: _edgeBox(
          border: const Border(right: BorderSide(color: Colors.white12)),
          child: SafeArea(
            child: _leftOpen ? _leftExpanded() : _leftCollapsed(),
          ),
        ),
      );

  Widget _leftCollapsed() => Column(
        children: <Widget>[
          _toggleButton(
            open: _leftOpen,
            tooltip: _leftOpen ? '收起左侧栏' : '展开左侧栏',
            onPressed: _toggleLeft,
          ),
          const Divider(height: 10, color: Colors.white12),
          for (var i = 0; i < _branches.length; i++)
            IconButton(
              tooltip: _branches[i].label,
              onPressed: () => _openLeftBranch(i),
              icon: Icon(_branches[i].icon),
              color: _branchContainsRoute(_branches[i], widget.selectedRouteIndex)
                  ? const Color(0xFFFFD54F)
                  : Colors.white60,
            ),
        ],
      );

  Widget _leftExpanded() {
    final branch = _branchIndex == null ? null : _branches[_branchIndex!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 6, 4),
          child: Row(
            children: <Widget>[
              if (branch != null)
                IconButton(
                  tooltip: '返回功能域',
                  onPressed: () => setState(() => _branchIndex = null),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  color: Colors.white70,
                  visualDensity: VisualDensity.compact,
                )
              else
                const Icon(Icons.apps, color: Color(0xFFFFD54F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  branch?.label ?? '功能域',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _toggleButton(
                open: _leftOpen,
                tooltip: '收起左侧栏',
                onPressed: _toggleLeft,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: branch == null
                ? <Widget>[
                    for (var i = 0; i < _branches.length; i++)
                      ListTile(
                        leading: Icon(_branches[i].icon, color: Colors.white70),
                        title: Text(
                          _branches[i].label,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: Colors.white38),
                        onTap: () => _openLeftBranch(i),
                      ),
                    const Divider(color: Colors.white12),
                    _miniSectionTitle('最小颗粒度入口'),
                    for (final item in _granularItems)
                      _granularListTile(item, compact: true),
                  ]
                : <Widget>[
                    for (final leaf in branch.children) _routeListTile(leaf),
                    const Divider(color: Colors.white12),
                    _miniSectionTitle('${branch.label} / 最小颗粒度'),
                    for (final item in _granularItems
                        .where((item) => item.group == branch.label))
                      _granularListTile(item, compact: true),
                  ],
          ),
        ),
      ],
    );
  }

  Widget _routeListTile(_NavLeaf leaf) {
    final selected = widget.selectedRouteIndex == leaf.routeIndex;
    return ListTile(
      selected: selected,
      selectedTileColor: const Color(0x332962FF),
      leading: Icon(
        leaf.icon,
        color: selected ? const Color(0xFF8AB4FF) : Colors.white60,
      ),
      title: Text(
        leaf.label,
        style: TextStyle(
          color: selected ? const Color(0xFF8AB4FF) : Colors.white70,
        ),
      ),
      trailing:
          selected ? const Icon(Icons.check, size: 17, color: Color(0xFF8AB4FF)) : null,
      onTap: () => _openRoute(leaf),
    );
  }

  Widget _rightSidebar() => AnimatedPositioned(
        duration: _animationDuration,
        curve: Curves.easeOutCubic,
        right: 0,
        top: 0,
        bottom: 0,
        width: _rightWidth,
        child: _edgeBox(
          border: const Border(left: BorderSide(color: Colors.white12)),
          child: SafeArea(
            child: _rightOpen ? _rightExpanded() : _rightCollapsed(),
          ),
        ),
      );

  Widget _rightCollapsed() => Column(
        children: <Widget>[
          _toggleButton(
            open: _rightOpen,
            tooltip: '展开右侧栏',
            onPressed: () => setState(() => _rightOpen = true),
          ),
          const Divider(height: 10, color: Colors.white12),
          for (final item in _granularItems
              .where((item) => item.edge == _SidebarEdge.right))
            IconButton(
              tooltip: item.title,
              onPressed: () => _selectGranularItem(item),
              icon: Icon(item.icon),
              color: item.id == _activeItemId
                  ? const Color(0xFFFFD54F)
                  : Colors.white60,
            ),
        ],
      );

  Widget _rightExpanded() => Row(
        children: <Widget>[
          SizedBox(
            width: 54,
            child: Column(
              children: <Widget>[
                _toggleButton(
                  open: _rightOpen,
                  tooltip: '收起右侧栏',
                  onPressed: () => setState(() => _rightOpen = false),
                ),
                const Divider(height: 10, color: Colors.white12),
                for (final item in _granularItems
                    .where((item) => item.edge == _SidebarEdge.right))
                  IconButton(
                    tooltip: item.title,
                    onPressed: () => _selectGranularItem(item),
                    icon: Icon(item.icon),
                    color: item.id == _activeItemId
                        ? const Color(0xFFFFD54F)
                        : Colors.white60,
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _panelHeader(_activeItem),
                const Divider(height: 1, color: Colors.white12),
                Expanded(child: _granularPanel(_activeItem)),
              ],
            ),
          ),
        ],
      );

  Widget _topSidebar() => AnimatedPositioned(
        duration: _animationDuration,
        curve: Curves.easeOutCubic,
        left: _leftWidth,
        right: _rightWidth,
        top: 0,
        height: _topHeight,
        child: _edgeBox(
          border: const Border(bottom: BorderSide(color: Colors.white12)),
          child: _topOpen ? _topExpanded() : _topCollapsed(),
        ),
      );

  Widget _topCollapsed() => Row(
        children: <Widget>[
          _toggleButton(
            open: _topOpen,
            tooltip: '展开顶部栏',
            onPressed: () => setState(() => _topOpen = true),
          ),
          Expanded(child: _breadcrumb(_activeItem, dense: true)),
        ],
      );

  Widget _topExpanded() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: <Widget>[
            _toggleButton(
              open: _topOpen,
              tooltip: '收起顶部栏',
              onPressed: () => setState(() => _topOpen = false),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _breadcrumb(_activeItem, dense: false),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        for (var i = 0; i < _branches.length; i++)
                          _domainChip(i),
                        const SizedBox(width: 8),
                        for (final item in _granularItems
                            .where((item) => item.edge == _SidebarEdge.top))
                          _granularPill(item),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _bottomSidebar() => AnimatedPositioned(
        duration: _animationDuration,
        curve: Curves.easeOutCubic,
        left: _leftWidth,
        right: _rightWidth,
        bottom: 0,
        height: _bottomHeight,
        child: _edgeBox(
          border: const Border(top: BorderSide(color: Colors.white12)),
          child: _bottomOpen ? _bottomExpanded() : _bottomCollapsed(),
        ),
      );

  Widget _bottomCollapsed() => Row(
        children: <Widget>[
          _toggleButton(
            open: _bottomOpen,
            tooltip: '展开底部栏',
            onPressed: () => setState(() => _bottomOpen = true),
          ),
          Expanded(
            child: Text(
              '当前颗粒度：${_activeItem.title}    ${_activeItem.group} / ${_activeItem.page} / ${_activeItem.area}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ],
      );

  Widget _bottomExpanded() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _toggleButton(
              open: _bottomOpen,
              tooltip: '收起底部栏',
              onPressed: () => setState(() => _bottomOpen = false),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  _quickRouteCard('K线图', Icons.candlestick_chart, 1),
                  _quickRouteCard('扫描器', Icons.radar, 2),
                  _quickRouteCard('选股/回测', Icons.science_outlined, 5),
                  for (final item in _granularItems
                      .where((item) => item.edge == _SidebarEdge.bottom))
                    _granularCard(item),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _edgeBox({required Widget child, Border? border}) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF5131722),
          border: border,
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x44000000), blurRadius: 16),
          ],
        ),
        child: Material(color: Colors.transparent, child: child),
      );

  Widget _toggleButton({
    required bool open,
    required String tooltip,
    required VoidCallback onPressed,
  }) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(open ? Icons.chevron_left : Icons.chevron_right),
        color: const Color(0xFFFFD54F),
        visualDensity: VisualDensity.compact,
      );

  Widget _granularListTile(_GranularSidebarItem item, {bool compact = false}) {
    final selected = item.id == _activeItemId;
    return ListTile(
      dense: compact,
      selected: selected,
      selectedTileColor: const Color(0x222962FF),
      leading: Icon(
        item.icon,
        color: selected ? const Color(0xFFFFD54F) : Colors.white60,
      ),
      title: Text(
        item.title,
        style: TextStyle(
          color: selected ? const Color(0xFFFFD54F) : Colors.white70,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      subtitle: compact
          ? Text(
              '${item.page} / ${item.area}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            )
          : null,
      onTap: () => _selectGranularItem(item),
    );
  }

  Widget _panelHeader(_GranularSidebarItem item) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(item.icon, color: const Color(0xFFFFD54F), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${item.group} / ${item.page} / ${item.area} / ${item.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _granularPanel(_GranularSidebarItem item) {
    switch (item.kind) {
      case _GranularPanelKind.klineAppearance:
        return const _KlineAppearancePanel();
      case _GranularPanelKind.stock:
        return _StockGranularityPanel(onOpenRoute: widget.onOpenRoute);
      case _GranularPanelKind.placeholder:
        return _PlaceholderGranularityPanel(item: item);
    }
  }

  Widget _breadcrumb(_GranularSidebarItem item, {required bool dense}) => Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 4 : 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${item.group}  >  ${item.page}  >  ${item.area}  >  ${item.title}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white70,
              fontSize: dense ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

  Widget _domainChip(int index) {
    final branch = _branches[index];
    final selected = _branchContainsRoute(branch, widget.selectedRouteIndex);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(branch.icon,
            size: 16, color: selected ? Colors.black : Colors.white70),
        label: Text(branch.label),
        onPressed: () => _openLeftBranch(index),
        backgroundColor: selected ? const Color(0xFFFFD54F) : const Color(0xFF20242E),
        labelStyle: TextStyle(
          color: selected ? Colors.black : Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _granularPill(_GranularSidebarItem item) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          avatar: Icon(item.icon, size: 16, color: Colors.white70),
          label: Text(item.title),
          onPressed: () => _selectGranularItem(item),
          backgroundColor: item.id == _activeItemId
              ? const Color(0x663D5AFE)
              : const Color(0xFF20242E),
          labelStyle: const TextStyle(color: Colors.white70),
        ),
      );

  Widget _quickRouteCard(String title, IconData icon, int routeIndex) {
    final selected = widget.selectedRouteIndex == routeIndex;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 132,
        child: FilledButton.tonalIcon(
          onPressed: selected ? null : () => widget.onOpenRoute(routeIndex),
          icon: Icon(icon, size: 18),
          label: Text(title, overflow: TextOverflow.ellipsis),
          style: FilledButton.styleFrom(
            alignment: Alignment.centerLeft,
            backgroundColor:
                selected ? const Color(0xAAFFD54F) : const Color(0x661C2330),
            foregroundColor: selected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _granularCard(_GranularSidebarItem item) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: () => _selectGranularItem(item),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 184,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.id == _activeItemId
                  ? const Color(0x332962FF)
                  : const Color(0xFF1C2330),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: <Widget>[
                Icon(item.icon, color: const Color(0xFFFFD54F), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white45, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _miniSectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFFFFD54F),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  bool _branchContainsRoute(_NavBranch branch, int route) =>
      branch.children.any((leaf) => leaf.routeIndex == route);
}

class _NavLeaf {
  final String label;
  final IconData icon;
  final int routeIndex;

  const _NavLeaf(this.label, this.icon, this.routeIndex);
}

class _NavBranch {
  final String label;
  final IconData icon;
  final List<_NavLeaf> children;

  const _NavBranch(this.label, this.icon, this.children);
}

class _GranularSidebarItem {
  final String id;
  final String title;
  final IconData icon;
  final String group;
  final String page;
  final String area;
  final _SidebarEdge edge;
  final _GranularPanelKind kind;
  final String description;

  const _GranularSidebarItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.group,
    required this.page,
    required this.area,
    required this.edge,
    required this.kind,
    required this.description,
  });
}

class _KlineAppearancePanel extends StatelessWidget {
  const _KlineAppearancePanel();

  static const List<Color> _klineColors = <Color>[
    Color(0xFFFFD54F),
    Color(0xFF66BB6A),
    Color(0xFFEF5350),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
  ];

  static const List<Color> _backgroundColors = <Color>[
    Color(0xFF0D1117),
    Color(0xFF0B0D10),
    Color(0xFF131722),
    Color(0xFF101820),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KlineAppearanceSettings>(
      valueListenable: KlineAppearanceController.selected,
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            _sectionTitle('K线图外观'),
            const Text(
              '该面板是“复盘分析 / 单股多级别复盘 / K线图 / K图外观”的最小颗粒度设置入口。',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _label('K线叠加色'),
            _colorRow(
              selected: settings.klineColor,
              colors: _klineColors,
              onSelected: KlineAppearanceController.setKlineColor,
            ),
            const SizedBox(height: 14),
            _label('K线叠加透明度'),
            Slider(
              value: settings.klineOpacity,
              min: 0,
              max: 0.85,
              divisions: 17,
              label: settings.klineOpacity.toStringAsFixed(2),
              onChanged: KlineAppearanceController.setKlineOpacity,
            ),
            const SizedBox(height: 14),
            _label('图表背景'),
            _colorRow(
              selected: settings.chartBackgroundColor,
              colors: _backgroundColors,
              onSelected: KlineAppearanceController.setChartBackgroundColor,
            ),
            const SizedBox(height: 14),
            _label('App主题色'),
            _colorRow(
              selected: settings.appThemeColor,
              colors: _klineColors,
              onSelected: KlineAppearanceController.setAppThemeColor,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: KlineAppearanceController.reset,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('恢复默认外观'),
            ),
            const SizedBox(height: 12),
            _evidenceBox(settings.toEvidenceText()),
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFD54F),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _colorRow({
    required Color selected,
    required List<Color> colors,
    required ValueChanged<Color> onSelected,
  }) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final color in colors)
            _colorButton(
              color: color,
              selected: color.toARGB32() == selected.toARGB32(),
              onTap: () => onSelected(color),
            ),
        ],
      );

  Widget _colorButton({
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.black, size: 18)
              : null,
        ),
      );

  Widget _evidenceBox(String text) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      );
}

class _StockGranularityPanel extends StatefulWidget {
  final ValueChanged<int> onOpenRoute;

  const _StockGranularityPanel({required this.onOpenRoute});

  @override
  State<_StockGranularityPanel> createState() => _StockGranularityPanelState();
}

class _StockGranularityPanelState extends State<_StockGranularityPanel> {
  final TextEditingController _symbolController =
      TextEditingController(text: '600340');
  final TextEditingController _marketController = TextEditingController(text: 'SH');
  final TextEditingController _startController =
      TextEditingController(text: '2026-01-01');
  final TextEditingController _endController = TextEditingController(text: '2026-06-18');
  final TextEditingController _levelController = TextEditingController(text: 'MIN5');
  final TextEditingController _countController = TextEditingController(text: '900');

  @override
  void dispose() {
    _symbolController.dispose();
    _marketController.dispose();
    _startController.dispose();
    _endController.dispose();
    _levelController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        _sectionTitle('股票'),
        const Text(
          '该面板是“复盘分析 / 单股多级别复盘 / K线图 / 股票”的最小颗粒度设置入口。应用后会切到K线图并发出加载/定位请求。',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _field(_marketController, 'market，例如 SH / SZ'),
        const SizedBox(height: 10),
        _field(_symbolController, '股票代码，例如 600340'),
        const SizedBox(height: 10),
        _field(_startController, 'start，YYYY-MM-DD'),
        const SizedBox(height: 10),
        _field(_endController, 'end，YYYY-MM-DD'),
        const SizedBox(height: 10),
        _field(_levelController, '触发级别，例如 MIN5 / DAILY'),
        const SizedBox(height: 10),
        _field(_countController, 'count，预留字段'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _apply,
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('应用到单股多级别复盘'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt, size: 16),
          label: const Text('恢复默认股票参数'),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0D10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: const Text(
            '说明：当前S13复盘页面实际加载仍以 market、symbol、start、end、level 为主；count字段先作为UI颗粒度占位，避免和现有加载逻辑强耦合。',
            style: TextStyle(color: Colors.white45, fontSize: 11),
          ),
        ),
      ],
    );
  }

  void _apply() {
    final symbol = _symbolController.text.trim().toUpperCase();
    final market = _marketController.text.trim().toUpperCase();
    final level = _levelController.text.trim().toUpperCase().isEmpty
        ? 'MIN5'
        : _levelController.text.trim().toUpperCase();
    if (symbol.isEmpty || market.isEmpty) {
      _showSnack('market 和股票代码不能为空');
      return;
    }
    final start = _parseDate(_startController.text);
    final end = _parseDate(_endController.text);
    widget.onOpenRoute(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReplayAnalysisStore.requestKlineLocation(
        symbol: symbol,
        market: market,
        level: level,
        rawIndex: 0,
        startDate: start,
        endDate: end,
        label: '四向侧边栏股票设置',
      );
    });
    _showSnack('已应用股票设置：$market$symbol $level');
  }

  void _reset() {
    setState(() {
      _symbolController.text = '600340';
      _marketController.text = 'SH';
      _startController.text = '2026-01-01';
      _endController.text = '2026-06-18';
      _levelController.text = 'MIN5';
      _countController.text = '900';
    });
  }

  DateTime? _parseDate(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFFFD54F),
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      );

  Widget _field(TextEditingController controller, String label) => TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF0B0D10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
}

class _PlaceholderGranularityPanel extends StatelessWidget {
  final _GranularSidebarItem item;

  const _PlaceholderGranularityPanel({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(item.icon, color: const Color(0xFFFFD54F)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.description,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 16),
        _infoRow('功能域', item.group),
        _infoRow('页面', item.page),
        _infoRow('区域', item.area),
        _infoRow('最小颗粒度', item.title),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0D10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: const Text(
            '该入口已进入统一侧边栏注册表，后续只需要把对应设置面板接到当前 granular item，不需要重写四向侧边栏框架。',
            style: TextStyle(color: Colors.white45, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 74,
              child: Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}
