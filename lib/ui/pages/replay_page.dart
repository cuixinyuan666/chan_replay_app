import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/engine/chan_config.dart';
import '../../core/engine/chan_replay_engine.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';
import '../../data/csv_loader.dart';
import '../../data/eastmoney_kline_source.dart';
import '../widgets/kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  final ChanReplayEngine _engine = ChanReplayEngine();
  final TextEditingController _stockCodeController =
      TextEditingController(text: '000001');

  List<RawBar> _allBars = [];
  ChanSnapshot _snapshot = ChanSnapshot.empty();
  int _cursor = 0;
  int _windowSize = 90;
  int? _viewEndIndex;
  int? _crosshairIndex;
  bool _playing = false;
  bool _showFx = true;
  bool _showBi = true;
  bool _showZs = true;
  bool _loadingRemote = false;
  Timer? _timer;

  ChanConfig _config = const ChanConfig();
  String _market = 'SZ';
  String _period = 'DAILY';
  String _adjust = 'QFQ';
  int _count = 500;
  String _dataSourceLabel = '示例CSV';

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stockCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSample() async {
    final bars =
        await CsvLoader.loadFromAsset('assets/sample_data/000001_daily.csv');
    if (!mounted) return;
    setState(() {
      _applyBars(bars, sourceLabel: '示例CSV');
    });
  }

  Future<void> _importCsv() async {
    final bars = await CsvLoader.pickAndLoadCsv();
    if (bars == null || bars.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('未读取到有效CSV数据')));
      return;
    }
    setState(() {
      _applyBars(bars, sourceLabel: '本地CSV');
    });
  }

  Future<void> _loadEastmoney() async {
    final code = _stockCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写股票代码')),
      );
      return;
    }

    setState(() => _loadingRemote = true);
    final source = EastmoneyKlineSource();
    try {
      final bars = await source.loadKline(
        market: _market,
        code: code,
        period: _period,
        adjust: _adjust,
        count: _count,
      );
      if (!mounted) return;
      if (bars.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未返回有效K线数据')),
        );
        return;
      }
      setState(() {
        _applyBars(
          bars,
          sourceLabel: '东方财富 $_market$code $_period $_adjust ${bars.length}根',
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('行情加载失败：$e')),
      );
    } finally {
      source.close();
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  void _applyBars(List<RawBar> bars, {required String sourceLabel}) {
    _stopPlay();
    _allBars = bars;
    _cursor = math.min(120, bars.length).toInt();
    _dataSourceLabel = sourceLabel;
    _viewEndIndex = null;
    _crosshairIndex = null;
    _rebuildSnapshot();
  }

  void _rebuildSnapshot() {
    _engine.setConfig(_config);
    _snapshot = _engine.feedMany(_allBars.take(_cursor).toList());
    final maxIndex = math.max(0, _snapshot.rawBars.length - 1).toInt();
    _crosshairIndex = _crosshairIndex == null
        ? null
        : _crosshairIndex!.clamp(0, maxIndex).toInt();
    _viewEndIndex = _viewEndIndex == null
        ? null
        : _viewEndIndex!.clamp(0, maxIndex).toInt();
  }

  void _reset() {
    setState(() {
      _stopPlay();
      _cursor = math.min(30, _allBars.length).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
      _rebuildSnapshot();
    });
  }

  void _stepForward() {
    if (_cursor >= _allBars.length) {
      _stopPlay();
      return;
    }
    setState(() {
      _cursor += 1;
      _snapshot = _engine.feed(_allBars[_cursor - 1]);
    });
  }

  void _stepBack() {
    if (_cursor <= 0) return;
    setState(() {
      _cursor -= 1;
      _snapshot = _engine.undo();
      final maxIndex = math.max(0, _snapshot.rawBars.length - 1).toInt();
      _crosshairIndex = _crosshairIndex == null
          ? null
          : _crosshairIndex!.clamp(0, maxIndex).toInt();
      _viewEndIndex = _viewEndIndex == null
          ? null
          : _viewEndIndex!.clamp(0, maxIndex).toInt();
    });
  }

  void _jumpTo(int nextCursor) {
    setState(() {
      _cursor = nextCursor.clamp(0, _allBars.length).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
      _rebuildSnapshot();
    });
  }

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _timer?.cancel();
        _timer = Timer.periodic(
            const Duration(milliseconds: 450), (_) => _stepForward());
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void _stopPlay() {
    _playing = false;
    _timer?.cancel();
    _timer = null;
  }

  void _panChartByBars(int bars) {
    if (bars == 0 || _snapshot.rawBars.isEmpty) return;
    final maxEnd = _snapshot.rawBars.length - 1;
    final current = _viewEndIndex ?? maxEnd;
    final next = (current + bars).clamp(0, maxEnd).toInt();
    if (next == current) return;
    setState(() => _viewEndIndex = next);
  }

  void _changeWindowSize(int next) {
    final value = next.clamp(30, 260).toInt();
    if (value == _windowSize) return;
    setState(() => _windowSize = value);
  }

  void _goToLatest() {
    setState(() {
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  RawBar? get _activeBar {
    final bars = _snapshot.rawBars;
    if (bars.isEmpty) return null;
    final cross = _crosshairIndex;
    if (cross != null && cross >= 0 && cross < bars.length) return bars[cross];
    return bars.last;
  }

  void _openDataSourcePanel() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var market = _market;
        var period = _period;
        var adjust = _adjust;
        var count = _count;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('数据源',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('当前使用 App 内直连数据源：东方财富历史K线'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: market,
                              decoration: const InputDecoration(
                                labelText: '市场',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'SZ', child: Text('深市 SZ')),
                                DropdownMenuItem(value: 'SH', child: Text('沪市 SH')),
                              ],
                              onChanged: (v) => setSheetState(
                                  () => market = v ?? market),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _stockCodeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '代码',
                                hintText: '000001',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: period,
                              decoration: const InputDecoration(
                                labelText: '周期',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'MIN1', child: Text('1分钟')),
                                DropdownMenuItem(value: 'MIN5', child: Text('5分钟')),
                                DropdownMenuItem(value: 'MIN15', child: Text('15分钟')),
                                DropdownMenuItem(value: 'MIN30', child: Text('30分钟')),
                                DropdownMenuItem(value: 'MIN60', child: Text('60分钟')),
                                DropdownMenuItem(value: 'DAILY', child: Text('日线')),
                                DropdownMenuItem(value: 'WEEKLY', child: Text('周线')),
                                DropdownMenuItem(value: 'MONTHLY', child: Text('月线')),
                              ],
                              onChanged: (v) => setSheetState(
                                  () => period = v ?? period),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: adjust,
                              decoration: const InputDecoration(
                                labelText: '复权',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'QFQ', child: Text('前复权')),
                                DropdownMenuItem(value: 'HFQ', child: Text('后复权')),
                                DropdownMenuItem(value: 'NONE', child: Text('不复权')),
                              ],
                              onChanged: (v) => setSheetState(
                                  () => adjust = v ?? adjust),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('读取K线数量'),
                        subtitle: Slider(
                          min: 100,
                          max: 2000,
                          divisions: 19,
                          label: '$count',
                          value: count.toDouble().clamp(100.0, 2000.0).toDouble(),
                          onChanged: (v) =>
                              setSheetState(() => count = v.round()),
                        ),
                        trailing: Text('$count'),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _loadSample();
                              },
                              icon: const Icon(Icons.dataset),
                              label: const Text('示例CSV'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _loadingRemote
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      setState(() {
                                        _market = market;
                                        _period = period;
                                        _adjust = adjust;
                                        _count = count;
                                      });
                                      _loadEastmoney();
                                    },
                              icon: _loadingRemote
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.cloud_download),
                              label: const Text('加载行情'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var temp = _config;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('缠论引擎参数',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SwitchListTile(
                      title: const Text('处理包含关系'),
                      value: temp.enableInclude,
                      onChanged: (v) => setSheetState(
                          () => temp = temp.copyWith(enableInclude: v)),
                    ),
                    SwitchListTile(
                      title: const Text('严格分型'),
                      subtitle: const Text('顶分型要求高点、低点同时抬高；底分型反之'),
                      value: temp.strictFx,
                      onChanged: (v) => setSheetState(
                          () => temp = temp.copyWith(strictFx: v)),
                    ),
                    ListTile(
                      title: const Text('成笔最小合并K线间隔'),
                      subtitle: Slider(
                        min: 3,
                        max: 7,
                        divisions: 4,
                        label: '${temp.minKCountForBi}',
                        value: temp.minKCountForBi.toDouble(),
                        onChanged: (v) => setSheetState(() =>
                            temp = temp.copyWith(minKCountForBi: v.round())),
                      ),
                      trailing: Text('${temp.minKCountForBi}'),
                    ),
                    SwitchListTile(
                      title: const Text('允许单笔中枢'),
                      subtitle: const Text('建议关闭；第一版默认只显示三笔及以上重叠中枢'),
                      value: temp.allowOneBiZs,
                      onChanged: (v) => setSheetState(
                          () => temp = temp.copyWith(allowOneBiZs: v)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                _config = temp;
                                _rebuildSnapshot();
                              });
                            },
                            child: const Text('应用'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: AppBar(
          toolbarHeight: 52,
          elevation: 0,
          titleSpacing: 0,
          backgroundColor: const Color(0xFF131722),
          title: _buildTopToolbar(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showRightPanel = constraints.maxWidth >= 760;
          return Row(
            children: [
              _buildLeftToolbar(),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _buildChartPanel()),
                    ReplayControllerBar(
                      playing: _playing,
                      cursor: _cursor,
                      total: _allBars.length,
                      onReset: _reset,
                      onStepBack: _stepBack,
                      onStepForward: _stepForward,
                      onTogglePlay: _togglePlay,
                      onSliderChanged: (v) => _jumpTo(v.round()),
                    ),
                  ],
                ),
              ),
              if (showRightPanel) _buildRightPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopToolbar(BuildContext context) {
    final code = _stockCodeController.text.trim().isEmpty
        ? '000001'
        : _stockCodeController.text.trim();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 8),
          _toolbarButton(
            label: '$_market:$code',
            icon: Icons.search,
            selected: true,
            onTap: _openDataSourcePanel,
          ),
          const SizedBox(width: 6),
          for (final item in const ['MIN5', 'MIN30', 'DAILY', 'WEEKLY'])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _toolbarButton(
                label: _periodLabel(item),
                selected: _period == item,
                onTap: () {
                  setState(() => _period = item);
                  _loadEastmoney();
                },
              ),
            ),
          const SizedBox(width: 4),
          _toolbarButton(
            label: _adjustLabel(_adjust),
            icon: Icons.tune,
            onTap: _openDataSourcePanel,
          ),
          _toolbarButton(
            label: '行情',
            icon: Icons.cloud_download,
            onTap: _openDataSourcePanel,
          ),
          _toolbarButton(
            label: 'CSV',
            icon: Icons.upload_file,
            onTap: _importCsv,
          ),
          _toolbarButton(
            label: '最新',
            icon: Icons.keyboard_double_arrow_right,
            onTap: _goToLatest,
          ),
          _toolbarButton(
            label: '设置',
            icon: Icons.settings,
            onTap: _openSettings,
          ),
          const SizedBox(width: 10),
          Text(
            _dataSourceLabel,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required String label,
    IconData? icon,
    bool selected = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2962FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white70),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftToolbar() {
    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _toolIcon(
              tooltip: '十字光标',
              icon: Icons.add,
              selected: _crosshairIndex != null,
              onPressed: () => setState(() => _crosshairIndex = null),
            ),
            _toolIcon(
              tooltip: '显示分型',
              icon: Icons.trip_origin,
              selected: _showFx,
              onPressed: () => setState(() => _showFx = !_showFx),
            ),
            _toolIcon(
              tooltip: '显示笔',
              icon: Icons.show_chart,
              selected: _showBi,
              onPressed: () => setState(() => _showBi = !_showBi),
            ),
            _toolIcon(
              tooltip: '显示中枢',
              icon: Icons.crop_square,
              selected: _showZs,
              onPressed: () => setState(() => _showZs = !_showZs),
            ),
            const Divider(height: 18, color: Colors.white12),
            _toolIcon(
              tooltip: '放大',
              icon: Icons.zoom_in,
              onPressed: () => _changeWindowSize(_windowSize - 15),
            ),
            _toolIcon(
              tooltip: '缩小',
              icon: Icons.zoom_out,
              onPressed: () => _changeWindowSize(_windowSize + 15),
            ),
            _toolIcon(
              tooltip: '回到最新K线',
              icon: Icons.my_location,
              onPressed: _goToLatest,
            ),
            const Spacer(),
            _toolIcon(
              tooltip: '引擎参数',
              icon: Icons.tune,
              onPressed: _openSettings,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _toolIcon({
    required String tooltip,
    required IconData icon,
    bool selected = false,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          color: selected ? Colors.white : Colors.white60,
          style: IconButton.styleFrom(
            backgroundColor:
                selected ? const Color(0xFF2962FF) : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildChartPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0D10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: KlineChart(
            snapshot: _snapshot,
            showFx: _showFx,
            showBi: _showBi,
            showZs: _showZs,
            windowSize: _windowSize,
            viewEndIndex: _viewEndIndex,
            crosshairIndex: _crosshairIndex,
            onCrosshairChanged: (i) => setState(() => _crosshairIndex = i),
            onPanBars: _panChartByBars,
            onWindowSizeChanged: _changeWindowSize,
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    final bar = _activeBar;
    return Container(
      width: 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('观察列表',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _watchRow('$_market:${_stockCodeController.text.trim()}', _period,
                selected: true),
            _watchRow('SZ:000001', '日线'),
            _watchRow('SH:600000', '日线'),
            const SizedBox(height: 16),
            const Text('缠论结构',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _kv('K线', '${_snapshot.rawBars.length}/${_allBars.length}'),
            _kv('合并K线', '${_snapshot.mergedBars.length}'),
            _kv('分型', '${_snapshot.fxs.length}'),
            _kv('笔', '${_snapshot.bis.length}'),
            _kv('中枢', '${_snapshot.zss.length}'),
            _kv('视窗', '$_windowSize 根'),
            const SizedBox(height: 16),
            const Text('OHLCV',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (bar == null)
              const Text('暂无数据', style: TextStyle(color: Colors.white54))
            else ...[
              _kv('时间', _fmtDate(bar.time)),
              _kv('开', bar.open.toStringAsFixed(2)),
              _kv('高', bar.high.toStringAsFixed(2)),
              _kv('低', bar.low.toStringAsFixed(2)),
              _kv('收', bar.close.toStringAsFixed(2)),
              _kv('量', bar.volume.toStringAsFixed(0)),
            ],
            const Spacer(),
            Text(
              _dataSourceLabel,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _watchRow(String symbol, String sub, {bool selected = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1E3A8A) : const Color(0xFF0B0D10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(symbol,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text(sub, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(key,
                  style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'MIN1':
        return '1m';
      case 'MIN5':
        return '5m';
      case 'MIN15':
        return '15m';
      case 'MIN30':
        return '30m';
      case 'MIN60':
        return '1h';
      case 'DAILY':
        return 'D';
      case 'WEEKLY':
        return 'W';
      case 'MONTHLY':
        return 'M';
      default:
        return period;
    }
  }

  String _adjustLabel(String adjust) {
    switch (adjust) {
      case 'QFQ':
        return '前复权';
      case 'HFQ':
        return '后复权';
      case 'NONE':
        return '不复权';
      default:
        return adjust;
    }
  }

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}
