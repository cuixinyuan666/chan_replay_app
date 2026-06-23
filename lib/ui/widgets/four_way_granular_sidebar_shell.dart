import 'package:flutter/material.dart';

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
  SidebarEdge? _openEdge;
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

  void _toggleRails() {
    setState(() {
      _railsVisible = !_railsVisible;
      if (!_railsVisible) {
        _openEdge = null;
        _activeItem = null;
      }
    });
  }

  void _toggleEdge(SidebarEdge edge) {
    setState(() {
      _activeItem = null;
      _openEdge = _openEdge == edge ? null : edge;
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
      _openEdge = item.edge;
    });
  }

  List<SidebarRegistration> _itemsFor(SidebarEdge edge) => _registrations
      .where((item) => item.edge == edge)
      .toList(growable: false);

  bool _isSelected(SidebarRegistration item) =>
      item.routeIndex != null && item.routeIndex == widget.selectedRouteIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sidePanelWidth =
          (constraints.maxWidth - 336).clamp(120.0, 280.0).toDouble();
      final horizontalPanelHeight =
          (constraints.maxHeight - 300).clamp(72.0, 112.0).toDouble();
      final left = _railsVisible
          ? _railSize + (_openEdge == SidebarEdge.left ? sidePanelWidth : 0)
          : 0.0;
      final right = _railsVisible
          ? _railSize + (_openEdge == SidebarEdge.right ? sidePanelWidth : 0)
          : 0.0;
      final top = _railsVisible
          ? _horizontalRailSize +
              (_openEdge == SidebarEdge.top ? horizontalPanelHeight : 0)
          : 0.0;
      final bottom = _railsVisible
          ? _horizontalRailSize +
              (_openEdge == SidebarEdge.bottom ? horizontalPanelHeight : 0)
          : 0.0;

      return Stack(children: <Widget>[
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          left: left,
          right: right,
          top: top,
          bottom: bottom,
          child: widget.child,
        ),
        if (_railsVisible && _openEdge == SidebarEdge.left)
          _sidePanel(SidebarEdge.left,
              left: _railSize,
              top: top,
              bottom: bottom,
              width: sidePanelWidth),
        if (_railsVisible && _openEdge == SidebarEdge.right)
          _sidePanel(SidebarEdge.right,
              right: _railSize,
              top: top,
              bottom: bottom,
              width: sidePanelWidth),
        if (_railsVisible && _openEdge == SidebarEdge.top)
          _horizontalPanel(SidebarEdge.top,
              left: left,
              right: right,
              top: _horizontalRailSize,
              height: horizontalPanelHeight),
        if (_railsVisible && _openEdge == SidebarEdge.bottom)
          _horizontalPanel(SidebarEdge.bottom,
              left: left,
              right: right,
              bottom: _horizontalRailSize,
              height: horizontalPanelHeight),
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

  Widget _leftRail({required double top, required double bottom}) =>
      Positioned(
        left: 0,
        top: top,
        bottom: bottom,
        width: _railSize,
        child: _railBox(
          border: const Border(right: BorderSide(color: Colors.white12)),
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _edgeButton(SidebarEdge.left, Icons.menu_open, '页面与分类'),
                const Divider(height: 1, color: Colors.white12),
                for (final item in _itemsFor(SidebarEdge.left))
                  _verticalRailItem(item),
              ],
            ),
          ),
        ),
      );

  Widget _rightRail({required double top, required double bottom}) =>
      Positioned(
        right: 0,
        top: top,
        bottom: bottom,
        width: _railSize,
        child: _railBox(
          border: const Border(left: BorderSide(color: Colors.white12)),
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _edgeButton(SidebarEdge.right, Icons.tune, '设置面板'),
                const Divider(height: 1, color: Colors.white12),
                for (final item in _itemsFor(SidebarEdge.right))
                  _verticalRailItem(item),
              ],
            ),
          ),
        ),
      );

  Widget _topRail({required double left, required double right}) => Positioned(
        left: left,
        right: right,
        top: 0,
        height: _horizontalRailSize,
        child: _railBox(
          border: const Border(bottom: BorderSide(color: Colors.white12)),
          child: Row(children: <Widget>[
            _edgeButton(SidebarEdge.top, Icons.expand_more, '上边栏分类'),
            const VerticalDivider(width: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final item in _itemsFor(SidebarEdge.top))
                    _horizontalRailItem(item),
                ],
              ),
            ),
          ]),
        ),
      );

  Widget _bottomRail({required double left, required double right}) =>
      Positioned(
        left: left,
        right: right,
        bottom: 0,
        height: _horizontalRailSize,
        child: _railBox(
          border: const Border(top: BorderSide(color: Colors.white12)),
          child: Row(children: <Widget>[
            _edgeButton(SidebarEdge.bottom, Icons.expand_less, '下边栏分类'),
            const VerticalDivider(width: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                children: <Widget>[
                  for (final item in _itemsFor(SidebarEdge.bottom))
                    _horizontalRailItem(item),
                ],
              ),
            ),
          ]),
        ),
      );

  Widget _sidePanel(
    SidebarEdge edge, {
    double? left,
    double? right,
    required double top,
    required double bottom,
    required double width,
  }) =>
      Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        width: width,
        child: _panelBody(edge),
      );

  Widget _horizontalPanel(
    SidebarEdge edge, {
    required double left,
    required double right,
    double? top,
    double? bottom,
    required double height,
  }) =>
      Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        height: height,
        child: _panelBody(edge, horizontal: true),
      );

  Widget _panelBody(SidebarEdge edge, {bool horizontal = false}) {
    final active = _activeItem;
    if (active != null && active.edge == edge && active.panelBuilder != null) {
      return _panelShell(
        title: active.label,
        child: active.panelBuilder!(context),
      );
    }
    return _panelShell(
      title: _edgeTitle(edge),
      child: _RegistrationList(
        items: _itemsFor(edge),
        horizontal: horizontal,
        selectedRouteIndex: widget.selectedRouteIndex,
        onActivate: _activate,
      ),
    );
  }

  Widget _panelShell({required String title, required Widget child}) =>
      DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xF0131722),
          border: Border.symmetric(
            vertical: BorderSide(color: Colors.white12),
            horizontal: BorderSide(color: Colors.white10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 8, 7),
              child: Row(children: <Widget>[
                Expanded(
                  child: Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  color: Colors.white54,
                  onPressed: () => setState(() {
                    _activeItem = null;
                    _openEdge = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
              ]),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(child: child),
          ],
        ),
      );

  Widget _railBox({required Widget child, Border? border}) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF00B0D10),
          border: border,
        ),
        child: child,
      );

  Widget _edgeButton(SidebarEdge edge, IconData icon, String tooltip) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => _toggleEdge(edge),
          child: SizedBox(
            width: _railSize,
            height: _horizontalRailSize,
            child: Icon(icon,
                size: 20,
                color: _openEdge == edge
                    ? const Color(0xFFFFD54F)
                    : Colors.white70),
          ),
        ),
      );

  Widget _verticalRailItem(SidebarRegistration item) => Tooltip(
        message: '${item.category} / ${item.label}',
        child: InkWell(
          onTap: () => _activate(item),
          child: Container(
            width: _railSize,
            height: 44,
            decoration: BoxDecoration(
              color: _isSelected(item)
                  ? const Color(0x332962FF)
                  : Colors.transparent,
            ),
            child: Icon(item.icon,
                size: 20,
                color: _isSelected(item)
                    ? const Color(0xFF8AB4FF)
                    : Colors.white70),
          ),
        ),
      );

  Widget _horizontalRailItem(SidebarRegistration item) => Tooltip(
        message: '${item.category} / ${item.label}',
        child: InkWell(
          onTap: () => _activate(item),
          child: Container(
            width: 48,
            height: _horizontalRailSize,
            decoration: BoxDecoration(
              color: _isSelected(item)
                  ? const Color(0x332962FF)
                  : Colors.transparent,
            ),
            child: Icon(item.icon,
                size: 20,
                color: _isSelected(item)
                    ? const Color(0xFF8AB4FF)
                    : Colors.white70),
          ),
        ),
      );

  String _edgeTitle(SidebarEdge edge) {
    switch (edge) {
      case SidebarEdge.left:
        return '页面与分类';
      case SidebarEdge.right:
        return '设置面板';
      case SidebarEdge.top:
        return '上边栏';
      case SidebarEdge.bottom:
        return '快捷方式';
    }
  }

  Widget _visibilityToggle() => Positioned(
        left: 0,
        top: 0,
        width: _railSize,
        height: _horizontalRailSize,
        child: Material(
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
        ),
      );
}

class _RegistrationList extends StatelessWidget {
  final List<SidebarRegistration> items;
  final bool horizontal;
  final int selectedRouteIndex;
  final ValueChanged<SidebarRegistration> onActivate;

  const _RegistrationList({
    required this.items,
    required this.horizontal,
    required this.selectedRouteIndex,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final categories = <String, List<SidebarRegistration>>{};
    for (final item in items) {
      categories.putIfAbsent(item.category, () => <SidebarRegistration>[]).add(item);
    }
    final children = <Widget>[
      for (final entry in categories.entries) ...<Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(entry.key,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        for (final item in entry.value) _listItem(item),
      ],
    ];
    if (horizontal) {
      return ListView(scrollDirection: Axis.horizontal, children: children);
    }
    return ListView(children: children);
  }

  Widget _listItem(SidebarRegistration item) {
    final selected = item.routeIndex != null && item.routeIndex == selectedRouteIndex;
    return ListTile(
      dense: true,
      leading: Icon(item.icon,
          color: selected ? const Color(0xFF8AB4FF) : Colors.white70),
      title: Text(item.label,
          style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
      subtitle: Text(item.category,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      selected: selected,
      onTap: () => onActivate(item),
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KlineAppearanceSettings>(
      valueListenable: KlineAppearanceController.selected,
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            const Text('K线透明度',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            Slider(
              value: settings.klineOpacity,
              min: 0,
              max: 0.85,
              divisions: 85,
              label: settings.klineOpacity.toStringAsFixed(2),
              onChanged: KlineAppearanceController.setKlineOpacity,
            ),
            const SizedBox(height: 8),
            _ColorRow(
              label: 'K线颜色',
              colors: const <Color>[
                Color(0xFFFFD54F),
                Color(0xFFEF5350),
                Color(0xFF26A69A),
                Color(0xFF8AB4FF),
              ],
              onColor: KlineAppearanceController.setKlineColor,
            ),
            const SizedBox(height: 8),
            _ColorRow(
              label: '图表背景',
              colors: const <Color>[
                Color(0xFF0D1117),
                Color(0xFF0B0D10),
                Color(0xFF131722),
                Color(0xFF101820),
              ],
              onColor: KlineAppearanceController.setChartBackgroundColor,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: KlineAppearanceController.reset,
              icon: const Icon(Icons.restore, size: 16),
              label: const Text('恢复默认'),
            ),
            const SizedBox(height: 8),
            Text(settings.toEvidenceText(),
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        );
      },
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final ValueChanged<Color> onColor;

  const _ColorRow({
    required this.label,
    required this.colors,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final color in colors)
              InkWell(
                onTap: () => onColor(color),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _OptionSummaryPanel extends StatelessWidget {
  final String title;
  final Map<String, List<String>> groups;

  const _OptionSummaryPanel({required this.title, required this.groups});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final entry in groups.entries) ...<Widget>[
          Text(entry.key,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final value in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $value',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
