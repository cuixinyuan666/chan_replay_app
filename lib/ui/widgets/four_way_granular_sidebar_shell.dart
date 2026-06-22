import 'package:flutter/material.dart';

import '../../core/services/replay_analysis_store.dart';
import '../settings/kline_appearance_controller.dart';

enum SidebarEdge { left, right, top, bottom }

/// Declarative entry used by the four-way frame. New tools can be added by
/// registering one item instead of editing the rail layout.
class SidebarRegistration {
  final String id;
  final String label;
  final String category;
  final IconData icon;
  final SidebarEdge edge;
  final int? routeIndex;
  final WidgetBuilder? panelBuilder;

  const SidebarRegistration({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    required this.edge,
    this.routeIndex,
    this.panelBuilder,
  }) : assert(routeIndex != null || panelBuilder != null);
}

class FourWaySidebarRegistry {
  final ValueNotifier<List<SidebarRegistration>> entries =
      ValueNotifier<List<SidebarRegistration>>(const <SidebarRegistration>[]);
  final Map<Object, List<SidebarRegistration>> _owners =
      <Object, List<SidebarRegistration>>{};

  void register(Object owner, List<SidebarRegistration> registrations) {
    _owners[owner] = registrations;
    _publish();
  }

  void unregister(Object owner) {
    if (_owners.remove(owner) != null) _publish();
  }

  void _publish() {
    entries.value = <SidebarRegistration>[
      for (final owned in _owners.values) ...owned,
    ];
  }
}

final FourWaySidebarRegistry fourWaySidebarRegistry = FourWaySidebarRegistry();

class FourWayGranularSidebarShell extends StatefulWidget {
  final Widget child;
  final int selectedRouteIndex;
  final ValueChanged<int> onOpenRoute;
  final List<SidebarRegistration> additionalRegistrations;

  const FourWayGranularSidebarShell({
    super.key,
    required this.child,
    required this.selectedRouteIndex,
    required this.onOpenRoute,
    this.additionalRegistrations = const <SidebarRegistration>[],
  });

  @override
  State<FourWayGranularSidebarShell> createState() =>
      _FourWayGranularSidebarShellState();
}

class _FourWayGranularSidebarShellState
    extends State<FourWayGranularSidebarShell> {
  static const double _railSize = 48;
  static const double _horizontalRailSize = 40;

  bool _railsVisible = true;
  String? _openEdge;
  SidebarRegistration? _activeItem;

  List<SidebarRegistration> get _registrations => <SidebarRegistration>[
        ..._defaultRegistrations,
        ...fourWaySidebarRegistry.entries.value,
        ...widget.additionalRegistrations,
      ];

  List<SidebarRegistration> get _defaultRegistrations => <SidebarRegistration>[
        const SidebarRegistration(
            id: 'replay',
            label: 'K线图',
            category: '页面',
            icon: Icons.account_tree,
            edge: SidebarEdge.left,
            routeIndex: 1),
        const SidebarRegistration(
            id: 'scanner',
            label: '扫描器',
            category: '复盘页面',
            icon: Icons.radar,
            edge: SidebarEdge.left,
            routeIndex: 2),
        const SidebarRegistration(
            id: 'promoter',
            label: '级别推进器',
            category: '复盘页面',
            icon: Icons.double_arrow,
            edge: SidebarEdge.left,
            routeIndex: 3),
        const SidebarRegistration(
            id: 'batch',
            label: '批量候选',
            category: '复盘页面',
            icon: Icons.view_list,
            edge: SidebarEdge.left,
            routeIndex: 4),
        const SidebarRegistration(
            id: 'research',
            label: '研究工具',
            category: '研究页面',
            icon: Icons.science_outlined,
            edge: SidebarEdge.left,
            routeIndex: 5),
        const SidebarRegistration(
            id: 'logs',
            label: '运行日志',
            category: '系统页面',
            icon: Icons.receipt_long,
            edge: SidebarEdge.left,
            routeIndex: 7),
        const SidebarRegistration(
            id: 'chips',
            label: '筹码分布',
            category: '研究页面',
            icon: Icons.stacked_bar_chart,
            edge: SidebarEdge.left,
            routeIndex: 8),
        SidebarRegistration(
            id: 'appearance',
            label: 'K图外观',
            category: '显示',
            icon: Icons.palette_outlined,
            edge: SidebarEdge.right,
            panelBuilder: (_) => const _AppearancePanel()),
        const SidebarRegistration(
            id: 'quick-kline',
            label: 'K线图',
            category: '页面快捷方式',
            icon: Icons.candlestick_chart,
            edge: SidebarEdge.bottom,
            routeIndex: 1),
        const SidebarRegistration(
            id: 'quick-research',
            label: '选股/回测',
            category: '页面快捷方式',
            icon: Icons.science,
            edge: SidebarEdge.bottom,
            routeIndex: 5),
        const SidebarRegistration(
            id: 'quick-log',
            label: '运行日志',
            category: '系统快捷方式',
            icon: Icons.receipt_long,
            edge: SidebarEdge.bottom,
            routeIndex: 7),
        SidebarRegistration(
            id: 'runtime',
            label: '运行路径',
            category: '系统快捷方式',
            icon: Icons.route,
            edge: SidebarEdge.bottom,
            panelBuilder: (_) => const _OptionSummaryPanel(
                    title: '运行路径',
                    groups: <String, List<String>>{
                      '后端': <String>['应用托管 Python', '本地桥接', '运行状态']
                    })),
      ];

  bool _isOpen(String edge) => _openEdge == edge;

  @override
  void initState() {
    super.initState();
    fourWaySidebarRegistry.entries.addListener(_handleRegistryChanged);
  }

  @override
  void dispose() {
    fourWaySidebarRegistry.entries.removeListener(_handleRegistryChanged);
    super.dispose();
  }

  void _handleRegistryChanged() {
    if (!mounted) return;
    setState(() {
      final active = _activeItem;
      if (active != null &&
          !_registrations.any((item) => item.id == active.id)) {
        _activeItem = null;
        _openEdge = null;
      }
    });
  }

  void _toggleEdge(String edge) {
    setState(() {
      _activeItem = null;
      _openEdge = _isOpen(edge) ? null : edge;
    });
  }

  void _activate(SidebarRegistration item) {
    if (item.routeIndex != null) {
      widget.onOpenRoute(item.routeIndex!);
      setState(() {
        _activeItem = null;
        _openEdge = null;
      });
      return;
    }
    setState(() {
      _activeItem = item;
      _openEdge = item.edge.name;
    });
  }

  void _toggleRails() {
    setState(() {
      _railsVisible = !_railsVisible;
      if (!_railsVisible) {
        _openEdge = null;
        _activeItem = null;
      }
    });
  }

  void _handleHorizontalSwipe(String edge, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;
    final shouldOpen = edge == 'left' ? velocity > 0 : velocity < 0;
    setState(() => _openEdge = shouldOpen ? edge : null);
  }

  void _handleVerticalSwipe(String edge, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;
    final shouldOpen = edge == 'top' ? velocity > 0 : velocity < 0;
    setState(() => _openEdge = shouldOpen ? edge : null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sidePanelWidth =
          (constraints.maxWidth - 336).clamp(120.0, 280.0).toDouble();
      final horizontalPanelHeight =
          (constraints.maxHeight - 300).clamp(72.0, 112.0).toDouble();
      final left = _railsVisible
          ? _railSize + (_isOpen('left') ? sidePanelWidth : 0)
          : 0.0;
      final right = _railsVisible
          ? _railSize + (_isOpen('right') ? sidePanelWidth : 0)
          : 0.0;
      final top = _railsVisible
          ? _horizontalRailSize + (_isOpen('top') ? horizontalPanelHeight : 0)
          : 0.0;
      final bottom = _railsVisible
          ? _horizontalRailSize +
              (_isOpen('bottom') ? horizontalPanelHeight : 0)
          : 0.0;

      return Stack(children: <Widget>[
        _animatedPositioned(
          key: const ValueKey<String>('content-frame'),
          left: left,
          right: right,
          top: top,
          bottom: bottom,
          child: widget.child,
        ),
        if (_railsVisible && _isOpen('left'))
          _leftPanel(
              left: _railSize, width: sidePanelWidth, top: top, bottom: bottom),
        if (_railsVisible && _isOpen('right'))
          _rightPanel(
              right: _railSize,
              width: sidePanelWidth,
              top: top,
              bottom: bottom),
        if (_railsVisible && _isOpen('top'))
          _topPanel(left: left, right: right, height: horizontalPanelHeight),
        if (_railsVisible && _isOpen('bottom'))
          _bottomPanel(left: left, right: right, height: horizontalPanelHeight),
        if (_railsVisible) ...<Widget>[
          _leftRail(top: top, bottom: bottom),
          _rightRail(top: top, bottom: bottom),
          _topRail(left: left, right: right),
          _bottomRail(left: left, right: right),
        ],
        _visibilityToggle(),
      ]);
    });
  }

  Widget _animatedPositioned({
    Key? key,
    double? left,
    double? right,
    double? top,
    double? bottom,
    double? width,
    double? height,
    required Widget child,
  }) =>
      AnimatedPositioned(
        key: key,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        width: width,
        height: height,
        child: child,
      );

  Widget _leftRail({required double top, required double bottom}) =>
      _animatedPositioned(
        key: const ValueKey<String>('left-rail-position'),
        left: 0,
        top: top,
        bottom: bottom,
        width: _railSize,
        child: _gestureBox(
          key: const ValueKey<String>('left-icon-rail'),
          border: const Border(right: BorderSide(color: Colors.white12)),
          onHorizontalDragEnd: (details) =>
              _handleHorizontalSwipe('left', details),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(children: <Widget>[
                _edgeButton('left', Icons.menu_open, '页面与分类'),
                const Divider(height: 1, color: Colors.white12),
                ..._verticalRailItems(SidebarEdge.left),
              ]),
            ),
          ),
        ),
      );

  Widget _rightRail({required double top, required double bottom}) =>
      _animatedPositioned(
        key: const ValueKey<String>('right-rail-position'),
        right: 0,
        top: top,
        bottom: bottom,
        width: _railSize,
        child: _gestureBox(
          key: const ValueKey<String>('right-icon-rail'),
          border: const Border(left: BorderSide(color: Colors.white12)),
          onHorizontalDragEnd: (details) =>
              _handleHorizontalSwipe('right', details),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(children: <Widget>[
                _edgeButton('right', Icons.tune, '设置面板'),
                const Divider(height: 1, color: Colors.white12),
                ..._verticalRailItems(SidebarEdge.right),
              ]),
            ),
          ),
        ),
      );

  Widget _topRail({required double left, required double right}) =>
      _animatedPositioned(
        key: const ValueKey<String>('top-rail-position'),
        left: left,
        right: right,
        top: 0,
        height: _horizontalRailSize,
        child: _gestureBox(
          key: const ValueKey<String>('top-icon-rail'),
          border: const Border(bottom: BorderSide(color: Colors.white12)),
          onVerticalDragEnd: (details) => _handleVerticalSwipe('top', details),
          child: Row(children: <Widget>[
            _edgeButton('top', Icons.expand_more, '上边栏分类'),
            const VerticalDivider(width: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _horizontalRailItems(SidebarEdge.top),
              ),
            ),
          ]),
        ),
      );

  Widget _bottomRail({required double left, required double right}) =>
      _animatedPositioned(
        key: const ValueKey<String>('bottom-rail-position'),
        left: left,
        right: right,
        bottom: 0,
        height: _horizontalRailSize,
        child: _gestureBox(
          key: const ValueKey<String>('bottom-icon-rail'),
          border: const Border(top: BorderSide(color: Colors.white12)),
          onVerticalDragEnd: (details) =>
              _handleVerticalSwipe('bottom', details),
          child: Row(children: <Widget>[
            _edgeButton('bottom', Icons.expand_less, '下边栏分类'),
            const VerticalDivider(width: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _horizontalRailItems(SidebarEdge.bottom),
              ),
            ),
          ]),
        ),
      );

  Widget _visibilityToggle() {
    final button = Material(
      key: const ValueKey<String>('sidebar-visibility-toggle'),
      color: const Color(0xF01E293B),
      child: InkWell(
        onTap: _toggleRails,
        child: Center(
          child: Text(
            _railsVisible ? '<' : '>',
            style: const TextStyle(
              color: Color(0xFFFFD54F),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
    if (_railsVisible) {
      return Positioned(
        left: 0,
        top: 0,
        width: _railSize,
        height: _horizontalRailSize,
        child: button,
      );
    }
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 28,
      child: Center(
        child: SizedBox(width: 28, height: 58, child: button),
      ),
    );
  }

  Widget _gestureBox({
    required Key key,
    required Widget child,
    Border? border,
    GestureDragEndCallback? onHorizontalDragEnd,
    GestureDragEndCallback? onVerticalDragEnd,
  }) =>
      GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: onHorizontalDragEnd,
        onVerticalDragEnd: onVerticalDragEnd,
        child: _box(child: child, border: border),
      );

  Widget _leftPanel({
    required double left,
    required double width,
    required double top,
    required double bottom,
  }) =>
      _animatedPositioned(
        key: const ValueKey<String>('left-panel-position'),
        left: left,
        width: width,
        top: top,
        bottom: bottom,
        child: _panelBox(
          key: const ValueKey<String>('left-category-panel'),
          child: _edgePanel(SidebarEdge.left),
        ),
      );

  Widget _rightPanel({
    required double right,
    required double width,
    required double top,
    required double bottom,
  }) =>
      _animatedPositioned(
        key: const ValueKey<String>('right-panel-position'),
        right: right,
        width: width,
        top: top,
        bottom: bottom,
        child: _panelBox(
          key: const ValueKey<String>('right-settings-panel'),
          child: _edgePanel(SidebarEdge.right),
        ),
      );

  Widget _topPanel(
          {required double left,
          required double right,
          required double height}) =>
      _animatedPositioned(
        key: const ValueKey<String>('top-panel-position'),
        left: left,
        right: right,
        top: _horizontalRailSize,
        height: height,
        child: _panelBox(
          key: const ValueKey<String>('top-category-panel'),
          child: _edgePanel(SidebarEdge.top),
        ),
      );

  Widget _bottomPanel(
          {required double left,
          required double right,
          required double height}) =>
      _animatedPositioned(
        key: const ValueKey<String>('bottom-panel-position'),
        left: left,
        right: right,
        bottom: _horizontalRailSize,
        height: height,
        child: _panelBox(
          key: const ValueKey<String>('bottom-shortcut-panel'),
          child: _edgePanel(SidebarEdge.bottom),
        ),
      );

  Widget _box({required Widget child, Border? border}) => DecoratedBox(
        decoration:
            BoxDecoration(color: const Color(0xF5131722), border: border),
        child: Material(color: Colors.transparent, child: child),
      );

  Widget _edgeButton(String edge, IconData icon, String label) => IconButton(
        tooltip: _isOpen(edge) ? '收起$label' : '展开$label',
        onPressed: () => _toggleEdge(edge),
        icon: Icon(icon),
        color: const Color(0xFFFFD54F),
      );

  List<SidebarRegistration> _itemsFor(SidebarEdge edge) =>
      _registrations.where((item) => item.edge == edge).toList();

  List<Widget> _verticalRailItems(SidebarEdge edge) {
    final widgets = <Widget>[];
    String? category;
    for (final item in _itemsFor(edge)) {
      if (category != null && category != item.category) {
        widgets.add(const Divider(height: 1, color: Colors.white12));
      }
      category = item.category;
      widgets.add(_registrationIcon(item));
    }
    return widgets;
  }

  List<Widget> _horizontalRailItems(SidebarEdge edge) {
    final widgets = <Widget>[];
    String? category;
    for (final item in _itemsFor(edge)) {
      if (category != null && category != item.category) {
        widgets.add(const VerticalDivider(width: 1, color: Colors.white12));
      }
      category = item.category;
      widgets.add(_registrationIcon(item));
    }
    return widgets;
  }

  Widget _registrationIcon(SidebarRegistration item) => IconButton(
        key: ValueKey<String>('sidebar-entry-${item.id}'),
        tooltip: '${item.category} / ${item.label}',
        icon: Icon(item.icon),
        color: _isSelected(item) ? const Color(0xFFFFD54F) : Colors.white60,
        onPressed: () => _activate(item),
      );

  bool _isSelected(SidebarRegistration item) =>
      _activeItem?.id == item.id ||
      (item.routeIndex != null && item.routeIndex == widget.selectedRouteIndex);

  Widget _edgePanel(SidebarEdge edge) {
    final active = _activeItem;
    if (active != null && active.edge == edge && active.panelBuilder != null) {
      return Column(children: <Widget>[
        _sectionHeader(active.label),
        Expanded(child: active.panelBuilder!(context)),
      ]);
    }
    final grouped = <String, List<SidebarRegistration>>{};
    for (final item in _itemsFor(edge)) {
      grouped
          .putIfAbsent(item.category, () => <SidebarRegistration>[])
          .add(item);
    }
    if (edge == SidebarEdge.top || edge == SidebarEdge.bottom) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: <Widget>[
            for (final entry in grouped.entries) ...<Widget>[
              SizedBox(
                width: (entry.value.length * 112.0).clamp(180.0, 460.0),
                child: Column(children: <Widget>[
                  Text(entry.key,
                      style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  const Divider(height: 8, color: Colors.white24),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        for (final item in entry.value)
                          _categoryChip(
                              item.label, item.icon, () => _activate(item)),
                      ],
                    ),
                  ),
                ]),
              ),
              const VerticalDivider(color: Colors.white12),
            ],
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        for (final entry in grouped.entries) ...<Widget>[
          _sectionHeader(entry.key),
          for (final item in entry.value)
            _panelAction(item.icon, item.label, () => _activate(item)),
        ],
      ],
    );
  }

  Widget _panelBox({required Key key, required Widget child}) => DecoratedBox(
        key: key,
        decoration: const BoxDecoration(
          color: Color(0xF71C2330),
          border: Border.fromBorderSide(BorderSide(color: Colors.white12)),
        ),
        child: Material(color: Colors.transparent, child: child),
      );

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        child: Row(children: <Widget>[
          const Expanded(child: Divider(color: Colors.white24)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(title,
                style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ),
          const Expanded(child: Divider(color: Colors.white24)),
        ]),
      );

  Widget _panelAction(IconData icon, String label, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(children: <Widget>[
              Icon(icon, size: 19, color: Colors.white60),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ]),
          ),
        ),
      );

  Widget _categoryChip(String label, IconData icon, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          avatar: Icon(icon, size: 16),
          label: Text(label),
          onPressed: onPressed,
        ),
      );
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KlineAppearanceSettings>(
      valueListenable: KlineAppearanceController.selected,
      builder: (context, s, _) =>
          ListView(padding: const EdgeInsets.all(12), children: <Widget>[
        _title('K图外观'),
        const Text('复盘分析 / 单股多级别复盘 / K线图 / K图外观',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        _colorLine(
            'K线叠加色', s.klineColor, KlineAppearanceController.setKlineColor),
        const SizedBox(height: 12),
        Text('透明度 ${s.klineOpacity.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Slider(
            value: s.klineOpacity,
            min: 0,
            max: 0.85,
            divisions: 17,
            onChanged: KlineAppearanceController.setKlineOpacity),
        _colorLine('图表背景', s.chartBackgroundColor,
            KlineAppearanceController.setChartBackgroundColor),
        const SizedBox(height: 12),
        _colorLine(
            '主题色', s.appThemeColor, KlineAppearanceController.setAppThemeColor),
        const SizedBox(height: 14),
        OutlinedButton.icon(
            onPressed: KlineAppearanceController.reset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('恢复默认')),
      ]),
    );
  }

  Widget _title(String text) => Text(text,
      style: const TextStyle(
          color: Color(0xFFFFD54F), fontSize: 15, fontWeight: FontWeight.w800));

  Widget _colorLine(
      String label, Color selected, ValueChanged<Color> onSelected) {
    const colors = <Color>[
      Color(0xFFFFD54F),
      Color(0xFF66BB6A),
      Color(0xFFEF5350),
      Color(0xFF42A5F5),
      Color(0xFF131722),
      Color(0xFF0D1117)
    ];
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: <Widget>[
            for (final c in colors)
              InkWell(
                onTap: () => onSelected(c),
                child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: c.toARGB32() == selected.toARGB32()
                                ? Colors.white
                                : Colors.white24,
                            width: 2))),
              ),
          ]),
        ]);
  }
}

class _StockPanel extends StatefulWidget {
  final ValueChanged<int> onOpenRoute;
  const _StockPanel({required this.onOpenRoute});

  @override
  State<_StockPanel> createState() => _StockPanelState();
}

class _StockPanelState extends State<_StockPanel> {
  final _market = TextEditingController(text: 'SH');
  final _symbol = TextEditingController(text: '600340');
  final _start = TextEditingController(text: '2026-01-01');
  final _end = TextEditingController(text: '2026-06-18');
  final _level = TextEditingController(text: 'MIN5');

  @override
  void dispose() {
    _market.dispose();
    _symbol.dispose();
    _start.dispose();
    _end.dispose();
    _level.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(12), children: <Widget>[
        const Text('股票',
            style: TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const Text('复盘分析 / 单股多级别复盘 / K线图 / 股票',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        _field(_market, 'market'),
        _field(_symbol, 'symbol'),
        _field(_start, 'start YYYY-MM-DD'),
        _field(_end, 'end YYYY-MM-DD'),
        _field(_level, 'level'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.play_arrow),
            label: const Text('应用并加载K线图')),
      ]);

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
            controller: c,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
                labelText: label,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)))),
      );

  void _apply() {
    final market = _market.text.trim().toUpperCase();
    final symbol = _symbol.text.trim().toUpperCase();
    final level = _level.text.trim().toUpperCase().isEmpty
        ? 'MIN5'
        : _level.text.trim().toUpperCase();
    if (market.isEmpty || symbol.isEmpty) return;
    widget.onOpenRoute(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReplayAnalysisStore.requestKlineLocation(
          symbol: symbol,
          market: market,
          level: level,
          rawIndex: 0,
          startDate: _date(_start.text),
          endDate: _date(_end.text),
          label: '四向侧边栏股票设置');
    });
  }

  DateTime? _date(String text) {
    try {
      return DateTime.parse(text.trim());
    } catch (_) {
      return null;
    }
  }
}

class _OptionSummaryPanel extends StatelessWidget {
  final String title;
  final Map<String, List<String>> groups;

  const _OptionSummaryPanel({required this.title, required this.groups});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: <Widget>[
          for (final entry in groups.entries) ...<Widget>[
            Row(children: <Widget>[
              const Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(entry.key,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const Expanded(child: Divider(color: Colors.white24)),
            ]),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final option in entry.value)
                  ActionChip(
                    label: Text(option),
                    tooltip: '$title / ${entry.key} / $option',
                    onPressed: () {},
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
}
