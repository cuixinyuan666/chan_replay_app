import 'package:flutter/material.dart';

import '../../core/services/replay_analysis_store.dart';
import '../settings/kline_appearance_controller.dart';

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
  State<FourWayGranularSidebarShell> createState() => _FourWayGranularSidebarShellState();
}

class _FourWayGranularSidebarShellState extends State<FourWayGranularSidebarShell> {
  bool _leftOpen = false, _rightOpen = false, _topOpen = false, _bottomOpen = false;
  String _active = 'appearance';

  double get _left => _leftOpen ? 260 : 48;
  double get _right => _rightOpen ? 320 : 48;
  double get _top => _topOpen ? 76 : 34;
  double get _bottom => _bottomOpen ? 96 : 34;

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      AnimatedPositioned(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        left: _left,
        right: _right,
        top: _top,
        bottom: _bottom,
        child: widget.child,
      ),
      _leftBar(),
      _rightBar(),
      _topBar(),
      _bottomBar(),
    ]);
  }

  Widget _leftBar() => AnimatedPositioned(
        duration: const Duration(milliseconds: 180),
        left: 0,
        top: 0,
        bottom: 0,
        width: _left,
        child: _box(
          border: const Border(right: BorderSide(color: Colors.white12)),
          child: SafeArea(
            child: Column(children: <Widget>[
              _toggle(_leftOpen, () => setState(() => _leftOpen = !_leftOpen), '左侧栏'),
              const Divider(height: 1, color: Colors.white12),
              _nav(1, Icons.account_tree, '单股多级别复盘'),
              _nav(2, Icons.radar, '扫描器'),
              _nav(5, Icons.science_outlined, '研究工具'),
              _nav(6, Icons.tune, '系统设置'),
              if (_leftOpen) ...<Widget>[
                const Divider(color: Colors.white12),
                _item('appearance', Icons.palette_outlined, 'K图外观'),
                _item('stock', Icons.query_stats, '股票'),
                _item('layers', Icons.layers_outlined, '图层显示'),
                _item('rhythm', Icons.show_chart, '节奏线'),
              ],
            ]),
          ),
        ),
      );

  Widget _rightBar() => AnimatedPositioned(
        duration: const Duration(milliseconds: 180),
        right: 0,
        top: 0,
        bottom: 0,
        width: _right,
        child: _box(
          border: const Border(left: BorderSide(color: Colors.white12)),
          child: SafeArea(
            child: _rightOpen
                ? Row(children: <Widget>[
                    SizedBox(
                      width: 48,
                      child: Column(children: <Widget>[
                        _toggle(true, () => setState(() => _rightOpen = false), '右侧栏'),
                        _iconItem('appearance', Icons.palette_outlined, 'K图外观'),
                        _iconItem('stock', Icons.query_stats, '股票'),
                        _iconItem('layers', Icons.layers_outlined, '图层显示'),
                        _iconItem('rhythm', Icons.show_chart, '节奏线'),
                      ]),
                    ),
                    const VerticalDivider(width: 1, color: Colors.white12),
                    Expanded(child: _panel()),
                  ])
                : Column(children: <Widget>[
                    _toggle(false, () => setState(() => _rightOpen = true), '右侧栏'),
                    _iconItem('appearance', Icons.palette_outlined, 'K图外观'),
                    _iconItem('stock', Icons.query_stats, '股票'),
                  ]),
          ),
        ),
      );

  Widget _topBar() => AnimatedPositioned(
        duration: const Duration(milliseconds: 180),
        left: _left,
        right: _right,
        top: 0,
        height: _top,
        child: _box(
          border: const Border(bottom: BorderSide(color: Colors.white12)),
          child: Row(children: <Widget>[
            _toggle(_topOpen, () => setState(() => _topOpen = !_topOpen), '顶部栏'),
            Expanded(child: Text(_breadcrumb, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            if (_topOpen) _pill('选股条件', Icons.filter_alt_outlined),
            if (_topOpen) _pill('系统外观', Icons.display_settings),
          ]),
        ),
      );

  Widget _bottomBar() => AnimatedPositioned(
        duration: const Duration(milliseconds: 180),
        left: _left,
        right: _right,
        bottom: 0,
        height: _bottom,
        child: _box(
          border: const Border(top: BorderSide(color: Colors.white12)),
          child: Row(children: <Widget>[
            _toggle(_bottomOpen, () => setState(() => _bottomOpen = !_bottomOpen), '底部栏'),
            if (_bottomOpen) _routeButton('K线图', Icons.candlestick_chart, 1),
            if (_bottomOpen) _routeButton('选股/回测', Icons.science, 5),
            Expanded(child: Text('当前颗粒度：$_title', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12))),
          ]),
        ),
      );

  Widget _box({required Widget child, Border? border}) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0xF5131722), border: border),
        child: Material(color: Colors.transparent, child: child),
      );

  Widget _toggle(bool open, VoidCallback onPressed, String name) => IconButton(
        tooltip: open ? '收起$name' : '展开$name',
        onPressed: onPressed,
        icon: Icon(open ? Icons.chevron_left : Icons.chevron_right),
        color: const Color(0xFFFFD54F),
      );

  Widget _nav(int route, IconData icon, String label) => ListTile(
        dense: true,
        leading: Icon(icon, color: widget.selectedRouteIndex == route ? const Color(0xFFFFD54F) : Colors.white60),
        title: _leftOpen ? Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)) : null,
        onTap: () => widget.onOpenRoute(route),
      );

  Widget _item(String id, IconData icon, String label) => ListTile(
        dense: true,
        leading: Icon(icon, color: _active == id ? const Color(0xFFFFD54F) : Colors.white60),
        title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        subtitle: const Text('复盘分析 / 单股多级别复盘 / K线图', style: TextStyle(color: Colors.white38, fontSize: 10)),
        onTap: () => setState(() { _active = id; _rightOpen = true; }),
      );

  Widget _iconItem(String id, IconData icon, String label) => IconButton(
        tooltip: label,
        icon: Icon(icon),
        color: _active == id ? const Color(0xFFFFD54F) : Colors.white60,
        onPressed: () => setState(() { _active = id; _rightOpen = true; }),
      );

  Widget _pill(String label, IconData icon) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(avatar: Icon(icon, size: 16), label: Text(label), onPressed: () {}),
      );

  Widget _routeButton(String label, IconData icon, int route) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilledButton.tonalIcon(onPressed: () => widget.onOpenRoute(route), icon: Icon(icon, size: 16), label: Text(label)),
      );

  Widget _panel() {
    if (_active == 'appearance') return const _AppearancePanel();
    if (_active == 'stock') return _StockPanel(onOpenRoute: widget.onOpenRoute);
    return _PlaceholderPanel(title: _title, breadcrumb: _breadcrumb);
  }

  String get _title {
    if (_active == 'stock') return '股票';
    if (_active == 'layers') return '图层显示';
    if (_active == 'rhythm') return '节奏线';
    return 'K图外观';
  }

  String get _breadcrumb => '复盘分析 > 单股多级别复盘 > K线图 > $_title';
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KlineAppearanceSettings>(
      valueListenable: KlineAppearanceController.selected,
      builder: (context, s, _) => ListView(padding: const EdgeInsets.all(12), children: <Widget>[
        _title('K图外观'),
        const Text('复盘分析 / 单股多级别复盘 / K线图 / K图外观', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        _colorLine('K线叠加色', s.klineColor, KlineAppearanceController.setKlineColor),
        const SizedBox(height: 12),
        Text('透明度 ${s.klineOpacity.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Slider(value: s.klineOpacity, min: 0, max: 0.85, divisions: 17, onChanged: KlineAppearanceController.setKlineOpacity),
        _colorLine('图表背景', s.chartBackgroundColor, KlineAppearanceController.setChartBackgroundColor),
        const SizedBox(height: 12),
        _colorLine('主题色', s.appThemeColor, KlineAppearanceController.setAppThemeColor),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: KlineAppearanceController.reset, icon: const Icon(Icons.restart_alt), label: const Text('恢复默认')),
      ]),
    );
  }

  Widget _title(String text) => Text(text, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 15, fontWeight: FontWeight.w800));

  Widget _colorLine(String label, Color selected, ValueChanged<Color> onSelected) {
    const colors = <Color>[Color(0xFFFFD54F), Color(0xFF66BB6A), Color(0xFFEF5350), Color(0xFF42A5F5), Color(0xFF131722), Color(0xFF0D1117)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: <Widget>[
        for (final c in colors)
          InkWell(
            onTap: () => onSelected(c),
            child: Container(width: 30, height: 30, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: c.toARGB32() == selected.toARGB32() ? Colors.white : Colors.white24, width: 2))),
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
  void dispose() { _market.dispose(); _symbol.dispose(); _start.dispose(); _end.dispose(); _level.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: <Widget>[
        const Text('股票', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 15, fontWeight: FontWeight.w800)),
        const Text('复盘分析 / 单股多级别复盘 / K线图 / 股票', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 12),
        _field(_market, 'market'), _field(_symbol, 'symbol'), _field(_start, 'start YYYY-MM-DD'), _field(_end, 'end YYYY-MM-DD'), _field(_level, 'level'),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _apply, icon: const Icon(Icons.play_arrow), label: const Text('应用并加载K线图')),
      ]);

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: label, isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
      );

  void _apply() {
    final market = _market.text.trim().toUpperCase();
    final symbol = _symbol.text.trim().toUpperCase();
    final level = _level.text.trim().toUpperCase().isEmpty ? 'MIN5' : _level.text.trim().toUpperCase();
    if (market.isEmpty || symbol.isEmpty) return;
    widget.onOpenRoute(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReplayAnalysisStore.requestKlineLocation(symbol: symbol, market: market, level: level, rawIndex: 0, startDate: _date(_start.text), endDate: _date(_end.text), label: '四向侧边栏股票设置');
    });
  }

  DateTime? _date(String text) { try { return DateTime.parse(text.trim()); } catch (_) { return null; } }
}

class _PlaceholderPanel extends StatelessWidget {
  final String title;
  final String breadcrumb;
  const _PlaceholderPanel({required this.title, required this.breadcrumb});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(title, style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(breadcrumb, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('该最小颗粒度入口已注册，后续可直接替换为具体设置表单。', style: TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );
}
