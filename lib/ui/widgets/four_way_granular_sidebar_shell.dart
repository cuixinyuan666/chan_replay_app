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
          routeIndex: 1,
        ),
        const SidebarRegistration(
          id: 'scanner',
          label: '扫描器',
          category: '复盘页面',
          icon: Icons.radar,
          edge: SidebarEdge.left,
          routeIndex: 2,
        ),
        const SidebarRegistration(
          id: 'promoter',
          label: '级别推进器',
          category: '复盘页面',
          icon: Icons.double_arrow,
          edge: SidebarEdge.left,
          routeIndex: 3,
        ),
        const SidebarRegistration(
          id: 'batch',
          label: '批量候选',
          category: '复盘页面',
          icon: Icons.view_list,
          edge: SidebarEdge.left,
          routeIndex: 4,
        ),
        const SidebarRegistration(
          id: 'research',
          label: '研究工具',
          category: '研究页面',
          icon: Icons.science_outlined,
          edge: SidebarEdge.left,
          routeIndex: 5,
        ),
        const SidebarRegistration(
          id: 'logs',
          label: '运行日志',
          category: '系统页面',
          icon: Icons.receipt_long,
          edge: SidebarEdge.left,
          routeIndex: 7,
        ),
        const SidebarRegistration(
          id: 'chips',
          label: '价格桶数',
          category: '研究页面',
          icon: Icons.tune,
          edge: SidebarEdge.left,
          routeIndex: 8,
        ),
        const SidebarRegistration(
          id: 'appearance',
          label: 'K图外观',
          category: 'K线图',
          icon: Icons.palette_outlined,
          edge: SidebarEdge.right,
          panelBuilder: _AppearancePanel.new,
        ),
        const SidebarRegistration(
          id: 'shortcuts',
          label: '快捷方式',
          category: '系统',
          icon: Icons.keyboard_command_key,
          edge: SidebarEdge.bottom,
          panelBuilder: _ShortcutPanel.new,
        ),
        const SidebarRegistration(
          id: 'runtime',
          label: '运行路径',
          category: '系统',
          icon: Icons.speed,
          edge: SidebarEdge.bottom,
          panelBuilder: _RuntimePathPanel.new,
        ),
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
    if (mounted) setState(() {});
  }

  void _activate(SidebarRegistration item) {
    if (item.onActivate != null) {
      item.onActivate!();
      return;
    }
    if (item.routeIndex != null) {
      widget.onOpenRoute(item.routeIndex!);
      return;
    }
    setState(() {
      _activeItem = item;
      _openEdge = item.edge;
    });
  }

  void _toggleEdge(SidebarEdge edge) {
    setState(() {
      if (_openEdge == edge) {
        _openEdge = null;
        _activeItem = null;
      } else {
        _openEdge = edge;
        _activeItem = _firstForEdge(edge);
      }
    });
  }

  SidebarRegistration? _firstForEdge(SidebarEdge edge) {
    final items = _itemsForEdge(edge);
    if (items.isEmpty) return null;
    return items.first;
  }

  List<SidebarRegistration> _itemsForEdge(SidebarEdge edge) =>
      _registrations.where((item) => item.edge == edge).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: widget.child),
          if (_openEdge != null && _activeItem != null) _panel(_openEdge!),
          if (_railsVisible) ...<Widget>[
            _verticalRail(SidebarEdge.left),
            _verticalRail(SidebarEdge.right),
            _horizontalRail(SidebarEdge.top),
            _horizontalRail(SidebarEdge.bottom),
          ],
          Positioned(
            top: 10,
            left: 10,
            child: _RailToggle(
              visible: _railsVisible,
              onPressed: () => setState(() => _railsVisible = !_railsVisible),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalRail(SidebarEdge edge) {
    final isLeft = edge == SidebarEdge.left;
    final items = _itemsForEdge(edge);
    return Positioned(
      top: _horizontalRailSize,
      bottom: _horizontalRailSize,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      width: _railSize,
      child: _RailSurface(
        child: Column(
          children: <Widget>[
            _edgeButton(edge),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: <Widget>[
                  for (final item in items) _itemButton(item, vertical: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _horizontalRail(SidebarEdge edge) {
    final isTop = edge == SidebarEdge.top;
    final items = _itemsForEdge(edge);
    return Positioned(
      left: _railSize,
      right: _railSize,
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      height: _horizontalRailSize,
      child: _RailSurface(
        child: Row(
          children: <Widget>[
            _edgeButton(edge),
            const VerticalDivider(color: Colors.white12, width: 1),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                children: <Widget>[
                  for (final item in items) _itemButton(item, vertical: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _edgeButton(SidebarEdge edge) {
    final selected = _openEdge == edge;
    final icon = switch (edge) {
      SidebarEdge.left => Icons.keyboard_arrow_right,
      SidebarEdge.right => Icons.keyboard_arrow_left,
      SidebarEdge.top => Icons.keyboard_arrow_down,
      SidebarEdge.bottom => Icons.keyboard_arrow_up,
    };
    return IconButton(
      key: ValueKey<String>('sidebar-edge-${edge.name}'),
      tooltip: selected ? '收起' : '展开',
      icon: Icon(icon, size: 18),
      color: selected ? Colors.lightBlueAccent : Colors.white70,
      onPressed: () => _toggleEdge(edge),
    );
  }

  Widget _itemButton(SidebarRegistration item, {required bool vertical}) {
    final selected = _activeItem?.id == item.id ||
        (item.routeIndex != null && item.routeIndex == widget.selectedRouteIndex);
    final content = Tooltip(
      message: '${item.category} / ${item.label}',
      waitDuration: const Duration(milliseconds: 250),
      child: InkWell(
        key: ValueKey<String>('sidebar-entry-${item.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _activate(item),
        child: Container(
          width: vertical ? _railSize : 104,
          height: vertical ? 54 : _horizontalRailSize,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: vertical
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      item.icon,
                      size: 17,
                      color: selected ? Colors.lightBlueAccent : Colors.white70,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.lightBlueAccent : Colors.white54,
                        fontSize: 9.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      item.icon,
                      size: 16,
                      color: selected ? Colors.lightBlueAccent : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.lightBlueAccent : Colors.white54,
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: vertical ? 3 : 2,
        vertical: vertical ? 2 : 3,
      ),
      child: content,
    );
  }

  Widget _panel(SidebarEdge edge) {
    final item = _activeItem;
    if (item == null) return const SizedBox.shrink();
    final content = item.panelBuilder?.call(context) ??
        _OptionSummaryPanel(title: item.label, category: item.category);
    final horizontal = edge == SidebarEdge.top || edge == SidebarEdge.bottom;
    return Positioned(
      left: edge == SidebarEdge.right ? null : _railSize,
      right: edge == SidebarEdge.left ? null : _railSize,
      top: edge == SidebarEdge.bottom ? null : _horizontalRailSize,
      bottom: edge == SidebarEdge.top ? null : _horizontalRailSize,
      width: horizontal ? null : 320,
      height: horizontal ? 220 : null,
      child: _PanelSurface(
        title: '${item.category} / ${item.label}',
        onClose: () => setState(() {
          _openEdge = null;
          _activeItem = null;
        }),
        child: content,
      ),
    );
  }
}

class _RailSurface extends StatelessWidget {
  final Widget child;

  const _RailSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

class _PanelSurface extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;

  const _PanelSurface({
    required this.title,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      elevation: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12),
          boxShadow: const <BoxShadow>[
            BoxShadow(blurRadius: 16, color: Color(0x66000000)),
          ],
        ),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 38,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.white54,
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailToggle extends StatelessWidget {
  final bool visible;
  final VoidCallback onPressed;

  const _RailToggle({required this.visible, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.50),
      borderRadius: BorderRadius.circular(10),
      child: IconButton(
        tooltip: visible ? '隐藏四向侧边栏' : '显示四向侧边栏',
        icon: Icon(visible ? Icons.visibility_off : Icons.visibility, size: 18),
        color: Colors.white70,
        onPressed: onPressed,
      ),
    );
  }
}

class _OptionSummaryPanel extends StatelessWidget {
  final String title;
  final String category;

  const _OptionSummaryPanel({required this.title, required this.category});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$category / $title\n此项为页面跳转入口或外部注册项。',
      style: const TextStyle(color: Colors.white70, height: 1.4),
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KlineAppearanceSettings>(
      valueListenable: KlineAppearanceController.selected,
      builder: (context, settings, _) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _SettingCaption('整体透明度'),
              Slider(
                value: settings.klineOpacity,
                min: 0,
                max: 1,
                divisions: 20,
                label: settings.klineOpacity.toStringAsFixed(2),
                onChanged: KlineAppearanceController.setKlineOpacity,
              ),
              const SizedBox(height: 12),
              const _SettingCaption('K线颜色'),
              const SizedBox(height: 8),
              const _ColorRow(
                label: 'K线颜色',
                colors: <Color>[
                  Color(0xFF26A69A),
                  Color(0xFFEF5350),
                  Color(0xFFFFB74D),
                  Color(0xFF64B5F6),
                ],
                onPicked: _noopColorPick,
              ),
              const SizedBox(height: 12),
              const _SettingCaption('背景'),
              const SizedBox(height: 8),
              const _ColorRow(
                label: '图表背景',
                colors: <Color>[
                  Color(0xFF0B0D10),
                  Color(0xFF111722),
                  Color(0xFF101010),
                  Color(0xFF17202A),
                ],
                onPicked: _noopColorPick,
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('恢复默认'),
                onPressed: KlineAppearanceController.reset,
              ),
            ],
          ),
        );
      },
    );
  }
}

void _noopColorPick(Color color) {}

class _SettingCaption extends StatelessWidget {
  final String text;

  const _SettingCaption(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
}

class _ColorRow extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final ValueChanged<Color> onPicked;

  const _ColorRow({
    required this.label,
    required this.colors,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final color in colors)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onPicked(color),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutPanel extends StatelessWidget {
  const _ShortcutPanel(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return const Text(
      'F5 刷新\n空格 播放 / 暂停\n方向键 单步复盘\n鼠标滚轮 缩放 / 平移',
      style: TextStyle(color: Colors.white70, height: 1.6),
    );
  }
}

class _RuntimePathPanel extends StatelessWidget {
  const _RuntimePathPanel(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return const Text(
      '运行路径用于区分 high_speed / training 等后端路线。当前页面仍以 Python 后端为缠论计算权威。',
      style: TextStyle(color: Colors.white70, height: 1.5),
    );
  }
}
