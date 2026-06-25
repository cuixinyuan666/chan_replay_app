import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/settings/chan_config_store.dart';
import '../../core/settings/chip_distribution_settings.dart';
import '../settings/kline_appearance_controller.dart';
import 's13_chip_distribution_panel.dart';

enum SidebarEdge { left, right, top, bottom }

enum SidebarCorner { topLeft, topRight, bottomLeft, bottomRight }

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
  final bool compact;
  final Color? accentColor;
  final bool Function()? selectedBuilder;

  const SidebarRegistration({
    required this.id,
    required this.label,
    required this.category,
    required this.icon,
    required this.edge,
    this.routeIndex,
    this.panelBuilder,
    this.onActivate,
    this.compact = false,
    this.accentColor,
    this.selectedBuilder,
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

class SidebarCornerRegistration {
  final String id;
  final SidebarCorner corner;
  final bool visibleWhenRailsHidden;
  final WidgetBuilder builder;

  const SidebarCornerRegistration({
    required this.id,
    required this.corner,
    required this.builder,
    this.visibleWhenRailsHidden = false,
  });
}

class FourWayCornerRegistry {
  final ValueNotifier<List<SidebarCornerRegistration>> entries =
      ValueNotifier<List<SidebarCornerRegistration>>(
          const <SidebarCornerRegistration>[]);
  final Map<Object, List<SidebarCornerRegistration>> _owners =
      <Object, List<SidebarCornerRegistration>>{};

  void register(Object owner, List<SidebarCornerRegistration> registrations) {
    _owners[owner] = registrations;
    _publish();
  }

  void unregister(Object owner) {
    if (_owners.remove(owner) != null) _publish();
  }

  void _publish() {
    entries.value = <SidebarCornerRegistration>[
      for (final owned in _owners.values) ...owned,
    ];
  }
}

final FourWayCornerRegistry fourWayCornerRegistry = FourWayCornerRegistry();

class _RailDisplayItem {
  final SidebarRegistration? registration;

  const _RailDisplayItem.entry(this.registration);
  const _RailDisplayItem.separator() : registration = null;
}

class FourWayGranularSidebarShell extends StatefulWidget {
  final Widget child;
  final int selectedRouteIndex;
  final ValueChanged<int> onOpenRoute;
  final List<SidebarRegistration> additionalRegistrations;
  final List<SidebarCornerRegistration> additionalCornerRegistrations;

  const FourWayGranularSidebarShell({
    super.key,
    required this.child,
    required this.selectedRouteIndex,
    required this.onOpenRoute,
    this.additionalRegistrations = const <SidebarRegistration>[],
    this.additionalCornerRegistrations = const <SidebarCornerRegistration>[],
  });

  @override
  State<FourWayGranularSidebarShell> createState() =>
      _FourWayGranularSidebarShellState();
}

class _FourWayGranularSidebarShellState
    extends State<FourWayGranularSidebarShell> {
  static const double _railSize = 48;
  static const double _horizontalRailSize = 40;
  static const double _panelWidth = 340;
  static const double _panelHeight = 260;

  bool _railsVisible = true;
  SidebarEdge? _openEdge;
  SidebarRegistration? _activeItem;
  int _railRotationOffset = 0;
  int _pendingRailRotationDelta = 0;
  bool _railRotationScheduled = false;
  double _railScrollRemainder = 0;
  List<_RailDisplayItem>? _perimeterItemsCache;

  List<SidebarRegistration> get _registrations => <SidebarRegistration>[
        ..._defaultRegistrations,
        ...fourWaySidebarRegistry.entries.value,
        ...widget.additionalRegistrations,
      ];

  List<SidebarCornerRegistration> get _cornerRegistrations =>
      <SidebarCornerRegistration>[
        ..._defaultCornerRegistrations,
        ...fourWayCornerRegistry.entries.value,
        ...widget.additionalCornerRegistrations,
      ];

  List<SidebarRegistration> get _defaultRegistrations => <SidebarRegistration>[
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
          category: '筹码分布',
          icon: Icons.tune,
          edge: SidebarEdge.left,
          panelBuilder: _PriceBucketCountPanel.new,
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
        for (final group in ChanConfigStore.groups)
          for (final key in group.keys)
            SidebarRegistration(
              id: 'chan-setting-$key',
              label: key,
              category: '系统设置/${group.title}',
              icon: Icons.tune,
              edge: SidebarEdge.top,
              compact: true,
              panelBuilder: (context) => _ChanSettingKeyPanel(
                settingKey: key,
                groupTitle: group.title,
              ),
            ),
      ];

  List<SidebarCornerRegistration> get _defaultCornerRegistrations =>
      <SidebarCornerRegistration>[
        SidebarCornerRegistration(
          id: 'sidebar-visibility',
          corner: SidebarCorner.topLeft,
          visibleWhenRailsHidden: true,
          builder: (_) => _RailToggle(
            visible: _railsVisible,
            onPressed: () => setState(() {
              _railsVisible = !_railsVisible;
              if (!_railsVisible) {
                _openEdge = null;
                _activeItem = null;
              }
            }),
          ),
        ),
        const SidebarCornerRegistration(
          id: 'app-close',
          corner: SidebarCorner.topRight,
          builder: _AppCloseCorner.new,
        ),
        SidebarCornerRegistration(
          id: 'kline-corner',
          corner: SidebarCorner.bottomLeft,
          builder: (_) => _KlineCorner(
            selected: widget.selectedRouteIndex == 1,
            onPressed: () => widget.onOpenRoute(1),
          ),
        ),
      ];

  @override
  void initState() {
    super.initState();
    fourWaySidebarRegistry.entries.addListener(_handleRegistryChanged);
    fourWayCornerRegistry.entries.addListener(_handleRegistryChanged);
  }

  @override
  void dispose() {
    fourWaySidebarRegistry.entries.removeListener(_handleRegistryChanged);
    fourWayCornerRegistry.entries.removeListener(_handleRegistryChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FourWayGranularSidebarShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
          oldWidget.additionalRegistrations,
          widget.additionalRegistrations,
        ) ||
        !identical(
          oldWidget.additionalCornerRegistrations,
          widget.additionalCornerRegistrations,
        )) {
      _perimeterItemsCache = null;
    }
  }

  void _handleRegistryChanged() {
    _perimeterItemsCache = null;
    if (mounted) setState(() {});
  }

  void _activate(SidebarRegistration item, SidebarEdge displayEdge) {
    if (item.onActivate != null) {
      item.onActivate!();
      return;
    }
    if (item.routeIndex != null) {
      setState(() {
        _openEdge = null;
        _activeItem = null;
      });
      widget.onOpenRoute(item.routeIndex!);
      return;
    }
    setState(() {
      _activeItem = item;
      _openEdge = displayEdge;
    });
  }

  List<_RailDisplayItem> _itemsForEdge(SidebarEdge edge) {
    final edgeIndex = _edgeIndex(edge);
    final items = _perimeterItems;
    if (items.isEmpty) return const <_RailDisplayItem>[];
    final total = items.length;
    final offset = _railRotationOffset % total;
    final sizes = _edgeChunkSizes(total);
    var start = 0;
    for (var i = 0; i < edgeIndex; i++) {
      start += sizes[i];
    }
    final count = sizes[edgeIndex];
    if (count <= 0) return const <_RailDisplayItem>[];
    return <_RailDisplayItem>[
      for (var i = 0; i < count; i++) items[(offset + start + i) % total],
    ];
  }

  List<int> _edgeChunkSizes(int total) {
    if (total <= 0) return const <int>[0, 0, 0, 0];
    const weights = <int>[1, 1, 1, 2]; // left, bottom, right, top.
    final sizes = <int>[];
    var used = 0;
    for (var i = 0; i < weights.length; i++) {
      final remaining = total - used;
      final remainingWeight =
          weights.skip(i).fold<int>(0, (sum, weight) => sum + weight);
      final count = i == weights.length - 1
          ? remaining
          : (remaining * weights[i] / remainingWeight).round();
      sizes.add(count);
      used += count;
    }
    return sizes;
  }

  List<_RailDisplayItem> get _perimeterItems {
    final cached = _perimeterItemsCache;
    if (cached != null) return cached;
    final rows = <_RailDisplayItem>[];
    String? lastCategory;
    for (final item in _registrations) {
      if (lastCategory != null && lastCategory != item.category) {
        rows.add(const _RailDisplayItem.separator());
      }
      rows.add(_RailDisplayItem.entry(item));
      lastCategory = item.category;
    }
    return _perimeterItemsCache = rows;
  }

  int _edgeIndex(SidebarEdge edge) => switch (edge) {
        SidebarEdge.left => 0,
        SidebarEdge.bottom => 1,
        SidebarEdge.right => 2,
        SidebarEdge.top => 3,
      };

  void _handleRailPointerSignal(SidebarEdge edge, PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final horizontal = edge == SidebarEdge.top || edge == SidebarEdge.bottom;
    final delta = horizontal
        ? (event.scrollDelta.dx == 0
            ? event.scrollDelta.dy
            : event.scrollDelta.dx)
        : event.scrollDelta.dy;
    final itemCount = _perimeterItems.length;
    if (delta == 0 || itemCount == 0) return;
    _railScrollRemainder += delta / 72;
    final steps = _railScrollRemainder.truncate();
    if (steps == 0) return;
    _railScrollRemainder -= steps;
    _scheduleRailRotation(steps, itemCount);
  }

  void _scheduleRailRotation(int steps, int itemCount) {
    _pendingRailRotationDelta += steps;
    if (_railRotationScheduled) return;
    _railRotationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final delta = _pendingRailRotationDelta;
      _pendingRailRotationDelta = 0;
      _railRotationScheduled = false;
      if (delta == 0) return;
      final total = itemCount;
      if (total == 0) return;
      setState(() {
        _railRotationOffset = (_railRotationOffset + delta) % total;
        if (_railRotationOffset < 0) _railRotationOffset += total;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final contentInsets = _railsVisible
        ? const EdgeInsets.fromLTRB(
            _railSize,
            _horizontalRailSize,
            _railSize,
            _horizontalRailSize,
          )
        : EdgeInsets.zero;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: contentInsets,
              child: SizedBox.expand(child: widget.child),
            ),
          ),
          if (_openEdge != null && _activeItem != null) _panel(_openEdge!),
          if (_railsVisible) ...<Widget>[
            _verticalRail(SidebarEdge.left),
            _verticalRail(SidebarEdge.right),
            _horizontalRail(SidebarEdge.top),
            _horizontalRail(SidebarEdge.bottom),
          ],
          ..._cornerSlots(),
        ],
      ),
    );
  }

  List<Widget> _cornerSlots() => <Widget>[
        for (final corner in SidebarCorner.values)
          if (_cornerSlot(corner) case final slot?) slot,
      ];

  Widget? _cornerSlot(SidebarCorner corner) {
    final entries = _cornerRegistrations
        .where((entry) =>
            entry.corner == corner &&
            (_railsVisible || entry.visibleWhenRailsHidden))
        .toList(growable: false);
    if (entries.isEmpty) return null;
    final child = entries.length == 1
        ? entries.single.builder(context)
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (final entry in entries) entry.builder(context),
            ],
          );
    return Positioned(
      key: ValueKey<String>('sidebar-corner-${corner.name}'),
      left: switch (corner) {
        SidebarCorner.topLeft || SidebarCorner.bottomLeft => 0,
        _ => null,
      },
      right: switch (corner) {
        SidebarCorner.topRight || SidebarCorner.bottomRight => 0,
        _ => null,
      },
      top: switch (corner) {
        SidebarCorner.topLeft || SidebarCorner.topRight => 0,
        _ => null,
      },
      bottom: switch (corner) {
        SidebarCorner.bottomLeft || SidebarCorner.bottomRight => 0,
        _ => null,
      },
      width: _railSize,
      height: _horizontalRailSize,
      child: _CornerSurface(child: child),
    );
  }

  Widget _verticalRail(SidebarEdge edge) {
    final isLeft = edge == SidebarEdge.left;
    final items = _itemsForEdge(edge);
    return Positioned(
      key: ValueKey<String>(isLeft ? 'left-icon-rail' : 'right-icon-rail'),
      top: _horizontalRailSize,
      bottom: _horizontalRailSize,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      width: _railSize,
      child: _RailSurface(
        child: Listener(
          onPointerSignal: (event) => _handleRailPointerSignal(edge, event),
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: <Widget>[
              for (final item in items)
                _railDisplayItem(item, edge: edge, vertical: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topStackRail(List<_RailDisplayItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = items.isEmpty ? 1 : items.length;
        final step = (constraints.maxWidth - 16) / count;
        final overlapStep = step.clamp(28.0, 58.0);
        final visibleCount =
            ((constraints.maxWidth - 6) / overlapStep).ceil() + 1;
        final cappedCount = visibleCount.clamp(0, items.length).toInt();
        return Listener(
          onPointerSignal: (event) =>
              _handleRailPointerSignal(SidebarEdge.top, event),
          child: ClipRect(
            child: Stack(
              children: <Widget>[
                for (var i = 0; i < cappedCount; i++)
                  Positioned(
                    left: 6 + i * overlapStep,
                    top: 0,
                    bottom: 0,
                    child: _railDisplayItem(
                      items[i],
                      edge: SidebarEdge.top,
                      vertical: false,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _horizontalRail(SidebarEdge edge) {
    final isTop = edge == SidebarEdge.top;
    final items = _itemsForEdge(edge);
    return Positioned(
      key: ValueKey<String>(isTop ? 'top-icon-rail' : 'bottom-icon-rail'),
      left: _railSize,
      right: _railSize,
      top: isTop ? 0 : null,
      bottom: isTop ? null : 0,
      height: _horizontalRailSize,
      child: _RailSurface(
        child: isTop
            ? _topStackRail(items)
            : Listener(
                onPointerSignal: (event) =>
                    _handleRailPointerSignal(edge, event),
                child: ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  children: <Widget>[
                    for (final item in items)
                      _railDisplayItem(item, edge: edge, vertical: false),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _railDisplayItem(
    _RailDisplayItem item, {
    required SidebarEdge edge,
    required bool vertical,
  }) {
    final registration = item.registration;
    if (registration == null) return _railSeparator(edge: edge);
    return _itemButton(registration, edge: edge, vertical: vertical);
  }

  Widget _railSeparator({required SidebarEdge edge}) {
    final vertical = edge == SidebarEdge.left || edge == SidebarEdge.right;
    return SizedBox(
      width: vertical ? _railSize : 18,
      height: vertical ? 18 : _horizontalRailSize,
      child: Center(
        child: Text(
          vertical ? '--' : '|',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.32),
            fontSize: vertical ? 11 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Color _categoryAccent(String category) {
    final root = category.split('/').first.trim();
    return switch (root) {
      '周期' || '数据/级别' => const Color(0xFF4DD0E1),
      '指标' || '显示/指标' => const Color(0xFFB388FF),
      '标的数据' || '数据' || '数据/股票' => const Color(0xFFFFD54F),
      '复盘模式' || '复盘' => const Color(0xFF81C784),
      '图层' || '显示/图层' => const Color(0xFF64B5F6),
      '工具' => const Color(0xFFFF8A80),
      '筹码分布' || '筹码' => const Color(0xFF80CBC4),
      '系统' || '系统页面' => const Color(0xFFB0BEC5),
      '页面' || '研究页面' || '复盘页面' => const Color(0xFFFFB74D),
      _ => const Color(0xFF90CAF9),
    };
  }

  Widget _itemButton(
    SidebarRegistration item, {
    required SidebarEdge edge,
    required bool vertical,
  }) {
    final routeOrPanelSelected = _activeItem?.id == item.id ||
        (item.routeIndex != null &&
            item.routeIndex == widget.selectedRouteIndex);
    final selected =
        routeOrPanelSelected || (item.selectedBuilder?.call() ?? false);
    final accent = item.accentColor ?? _categoryAccent(item.category);
    final content = Tooltip(
      message: '${item.category} / ${item.label}',
      waitDuration: const Duration(seconds: 9),
      child: InkWell(
        key: ValueKey<String>('sidebar-entry-${item.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _activate(item, edge),
        child: Container(
          width: vertical ? _railSize : (item.compact ? 62 : 104),
          height: vertical ? 54 : _horizontalRailSize,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.24)
                : accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.82)
                  : accent.withValues(alpha: 0.24),
            ),
          ),
          child: vertical
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      item.icon,
                      size: 17,
                      color: selected ? accent : accent.withValues(alpha: 0.82),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 9.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
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
                      color: selected ? accent : accent.withValues(alpha: 0.82),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
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
      left: edge == SidebarEdge.right
          ? null
          : (horizontal ? _railSize : _railSize + 12),
      right: edge == SidebarEdge.left
          ? null
          : (horizontal ? _railSize : _railSize + 12),
      top: edge == SidebarEdge.bottom
          ? null
          : (horizontal ? _horizontalRailSize + 12 : _horizontalRailSize + 12),
      bottom: edge == SidebarEdge.top
          ? null
          : (horizontal ? _horizontalRailSize + 12 : _horizontalRailSize + 12),
      width: horizontal ? null : _panelWidth,
      height: horizontal ? _panelHeight : null,
      child: _PanelSurface(
        key: const ValueKey<String>('sidebar-open-panel'),
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

class _CornerSurface extends StatelessWidget {
  final Widget child;

  const _CornerSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(child: child),
    );
  }
}

class _AppCloseCorner extends StatelessWidget {
  const _AppCloseCorner(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '关闭',
      waitDuration: const Duration(seconds: 9),
      child: IconButton(
        key: const ValueKey<String>('app-close-corner'),
        icon: const Icon(Icons.close, size: 18),
        color: const Color(0xFFFF8A80),
        onPressed: () async {
          try {
            await windowManager.close();
          } catch (error) {
            assert(() {
              debugPrint('Window close is unavailable in this host: $error');
              return true;
            }());
          }
        },
      ),
    );
  }
}

class _KlineCorner extends StatelessWidget {
  final bool selected;
  final VoidCallback onPressed;

  const _KlineCorner({
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'K线图',
      waitDuration: const Duration(seconds: 9),
      child: IconButton(
        key: const ValueKey<String>('sidebar-corner-kline'),
        icon: const Icon(Icons.candlestick_chart, size: 18),
        color: selected ? Colors.white : Colors.white70,
        onPressed: onPressed,
      ),
    );
  }
}

class _PriceBucketCountPanel extends StatelessWidget {
  const _PriceBucketCountPanel(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChipDistributionSettings>(
      valueListenable: ChipDistributionSettingsController.selected,
      builder: (context, settings, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.tune, color: Color(0xFFFFD54F), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '价格桶数',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${settings.priceBucketCount}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PriceBucketCountControl(
              value: settings.priceBucketCount,
              overlayChrome: false,
            ),
            const SizedBox(height: 8),
            Text(
              settings.toEvidenceText(),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        );
      },
    );
  }
}

class _ChanSettingKeyPanel extends StatefulWidget {
  final String settingKey;
  final String groupTitle;

  const _ChanSettingKeyPanel({
    required this.settingKey,
    required this.groupTitle,
  });

  @override
  State<_ChanSettingKeyPanel> createState() => _ChanSettingKeyPanelState();
}

class _ChanSettingKeyPanelState extends State<_ChanSettingKeyPanel> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _valueText);
  }

  @override
  void didUpdateWidget(covariant _ChanSettingKeyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settingKey != widget.settingKey) {
      _controller.text = _valueText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _valueText => '${ChanConfigStore.values[widget.settingKey] ?? ''}';

  Object? _parseValue(String raw) {
    final defaultValue = ChanConfigStore.defaultValues[widget.settingKey];
    if (defaultValue is int) return int.tryParse(raw.trim());
    return raw.trim();
  }

  void _saveTextValue() {
    final parsed = _parseValue(_controller.text);
    if (!ChanConfigStore.isValidValue(widget.settingKey, parsed)) return;
    ChanConfigStore.setValue(widget.settingKey, parsed);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, Object?>>(
      valueListenable: ChanConfigStore.notifier,
      builder: (context, values, _) {
        final value = values[widget.settingKey];
        final defaultValue = ChanConfigStore.defaultValues[widget.settingKey];
        final options = ChanConfigStore.options[widget.settingKey];
        final valid = ChanConfigStore.isValidValue(widget.settingKey, value);
        if (_controller.text != '$value') {
          _controller.text = '$value';
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: <Widget>[
            Text(
              widget.groupTitle,
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.settingKey,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (defaultValue is bool)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  value == true ? '开启' : '关闭',
                  style: const TextStyle(color: Colors.white70),
                ),
                value: value == true,
                onChanged: (next) =>
                    ChanConfigStore.setValue(widget.settingKey, next),
              )
            else if (options != null)
              DropdownButtonFormField<String>(
                value: '$value',
                dropdownColor: const Color(0xFF111722),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '选项',
                ),
                items: <DropdownMenuItem<String>>[
                  for (final option in options)
                    DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                ],
                onChanged: (next) {
                  if (next != null) {
                    ChanConfigStore.setValue(widget.settingKey, next);
                  }
                },
              )
            else
              TextField(
                controller: _controller,
                minLines: widget.settingKey == 'bsp_advanced' ? 4 : 1,
                maxLines: widget.settingKey == 'bsp_advanced' ? 8 : 1,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: '值',
                  errorText: valid ? null : '当前值不合法',
                ),
                onSubmitted: (_) => _saveTextValue(),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (defaultValue is! bool && options == null)
                  FilledButton.icon(
                    onPressed: () {
                      _saveTextValue();
                      setState(() {});
                    },
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('保存'),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    ChanConfigStore.setValue(widget.settingKey, defaultValue);
                  },
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('默认'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: '${values[widget.settingKey]}'));
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PanelSurface extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final Widget child;

  const _PanelSurface({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      elevation: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF2111722),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: const <BoxShadow>[
            BoxShadow(blurRadius: 18, color: Color(0x66000000)),
          ],
        ),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 42,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
      child: Tooltip(
        message: visible ? '隐藏四向侧边栏' : '显示四向侧边栏',
        waitDuration: const Duration(seconds: 9),
        child: IconButton(
          key: const ValueKey<String>('sidebar-visibility-toggle'),
          icon:
              Icon(visible ? Icons.visibility_off : Icons.visibility, size: 18),
          color: Colors.white70,
          onPressed: onPressed,
        ),
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
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
