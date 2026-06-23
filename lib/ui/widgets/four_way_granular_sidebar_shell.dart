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
  final VoidCallback? onActivate;

  const SidebarRegistration({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    required this.edge,
    this.routeIndex,
    this.panelBuilder,
    this.onActivate,
  }) : assert(
          routeIndex != null || panelBuilder != null || onActivate != null,
        );
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
            label: '筹码分布/价格桶数',
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
    if (item.onActivate != null) {
      item.onActivate!();
      setState(() {
        _activeItem = null;
        _openEdge = null;
      });
      return;
    }
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
}
