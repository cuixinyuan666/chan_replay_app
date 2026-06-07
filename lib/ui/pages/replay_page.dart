import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/engine/chan_config.dart';
import '../../core/engine/chan_replay_engine.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';
import '../../data/csv_loader.dart';
import '../../data/tencent_kline_source.dart';
import '../widgets/kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

enum ReplayDisplayMode { full, step }

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  final ChanReplayEngine _engine = ChanReplayEngine();
  final TextEditingController _stockCodeController =
      TextEditingController(text: '000001');
  final TextEditingController _startDateController =
      TextEditingController(text: '2020-01-01');
  final TextEditingController _endDateController = TextEditingController();

  List<RawBar> _allBars = [];
  ChanSnapshot _snapshot = ChanSnapshot.empty();
  int _cursor = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  bool _playing = false;
  bool _showFx = true;
  bool _showFxLine = true;
  bool _showFxText = true;
  bool _showBi = true;
  bool _showBiText = false;
  bool _showSeg = true;
  bool _showSegText = true;
  bool _showZs = true;
  bool _toolbarExpanded = true;
  bool _loadingRemote = false;
  ReplayDisplayMode _displayMode = ReplayDisplayMode.step;
  Timer? _timer;

  ChanConfig _config = ChanConfig.chanPyDefault();
  String _market = 'SZ';
  String _period = 'DAILY';
  String _adjust = 'QFQ';
  int _count = 500;
  String _dataSourceLabel = '示例CSV';

  bool get _isStepMode => _displayMode == ReplayDisplayMode.step;
  int get _effectiveCursor =>
      _displayMode == ReplayDisplayMode.full ? _allBars.length : _cursor;

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stockCodeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
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

  Future<void> _loadTencent() async {
    final code = _stockCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写股票代码')),
      );
      return;
    }

    final startDate = _parseDateInput(_startDateController.text);
    final endDate = _parseDateInput(_endDateController.text);
    if (_startDateController.text.trim().isNotEmpty && startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始日期格式应为 yyyy-MM-dd')),
      );
      return;
    }
    if (_endDateController.text.trim().isNotEmpty && endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束日期格式应为 yyyy-MM-dd')),
      );
      return;
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始日期不能晚于结束日期')),
      );
      return;
    }

    setState(() => _loadingRemote = true);
    final source = TencentKlineSource();
    try {
      final bars = await source.loadKline(
        market: _market,
        code: code,
        period: _period,
        adjust: _adjust,
        count: _count,
        startDate: startDate,
        endDate: endDate,
      );
      if (!mounted) return;
      if (bars.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('腾讯行情未返回有效K线数据，请检查市场、代码、起止时间和K线数量')),
        );
        return;
      }
      setState(() {
        final dateRange = _dateRangeLabel(startDate, endDate);
        _applyBars(
          bars,
          sourceLabel:
              '腾讯行情 $_market$code $_period $_adjust ${bars.length}根$dateRange',
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('腾讯行情加载失败：$e')),
      );
    } finally {
      source.close();
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  void _applyBars(List<RawBar> bars, {required String sourceLabel}) {
    _stopPlay();
    _allBars = bars;
    _cursor = _displayMode == ReplayDisplayMode.full
        ? bars.length
        : math.min(120, bars.length).toInt();
    _dataSourceLabel = sourceLabel;
    _viewEndIndex = null;
    _crosshairIndex = null;
    _priceScale = 1.0;
    _rebuildSnapshot();
  }

  void _rebuildSnapshot() {
    _engine.setConfig(_config);
    final cursor = _effectiveCursor.clamp(0, _allBars.length).toInt();
    _snapshot = _engine.feedMany(_allBars.take(cursor).toList());
    final maxIndex = math.max(0, _snapshot.rawBars.length - 1).toInt();
    _crosshairIndex = _crosshairIndex?.clamp(0, maxIndex).toInt();
    _viewEndIndex = _viewEndIndex?.clamp(0, maxIndex).toInt();
  }

  void _reset() {
    if (!_isStepMode) return;
    setState(() {
      _stopPlay();
      _cursor = math.min(30, _allBars.length).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
      _priceScale = 1.0;
      _rebuildSnapshot();
    });
  }

  void _stepForward() {
    if (!_isStepMode) return;
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
    if (!_isStepMode || _cursor <= 0) return;
    setState(() {
      _cursor -= 1;
      _snapshot = _engine.undo();
      final maxIndex = math.max(0, _snapshot.rawBars.length - 1).toInt();
      _crosshairIndex = _crosshairIndex?.clamp(0, maxIndex).toInt();
      _viewEndIndex = _viewEndIndex?.clamp(0, maxIndex).toInt();
    });
  }

  void _jumpTo(int nextCursor) {
    if (!_isStepMode) return;
    setState(() {
      _cursor = nextCursor.clamp(0, _allBars.length).toInt();
      _viewEndIndex = null;
      _crosshairIndex = null;
      _rebuildSnapshot();
    });
  }

  void _togglePlay() {
    if (!_isStepMode) return;
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

  void _setDisplayMode(ReplayDisplayMode mode) {
    if (_displayMode == mode) return;
    setState(() {
      _stopPlay();
      _displayMode = mode;
      if (mode == ReplayDisplayMode.full) {
        _cursor = _allBars.length;
      } else if (_cursor <= 0 || _cursor > _allBars.length) {
        _cursor = math.min(120, _allBars.length).toInt();
      }
      _viewEndIndex = null;
      _crosshairIndex = null;
      _rebuildSnapshot();
    });
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
    final value = next.clamp(24, 360).toInt();
    if (value == _windowSize) return;
    setState(() => _windowSize = value);
  }

  void _changePriceScale(double next) {
    final value = next.clamp(0.35, 5.0).toDouble();
    if ((value - _priceScale).abs() < 0.001) return;
    setState(() => _priceScale = value);
  }

  void _resetChartZoom() {
    setState(() {
      _windowSize = 90;
      _priceScale = 1.0;
      _viewEndIndex = null;
    });
  }

  void _goToLatest() {
    setState(() {
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
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
                      const Text('当前使用 App 内直连数据源：腾讯行情历史K线'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: market,
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
                              initialValue: period,
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
                              initialValue: adjust,
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
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startDateController,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: '开始日期',
                                hintText: 'yyyy-MM-dd',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _endDateController,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: '结束日期',
                                hintText: '留空为最新',
                                border: OutlineInputBorder(),
                              ),
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
                                      _loadTencent();
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
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var temp = _config;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
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
                      title: const Text('严格分型/严格成笔'),
                      subtitle: const Text('映射到 chan.py bi_strict'),
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
                      subtitle: const Text('映射到 chan.py one_bi_zs'),
                      value: temp.allowOneBiZs,
                      onChanged: (v) => setSheetState(
                          () => temp = temp.copyWith(allowOneBiZs: v)),
                    ),
                    SwitchListTile(
                      title: const Text('允许跨段中枢'),
                      subtitle: const Text('开启后使用全局笔列表扫描中枢'),
                      value: temp.allowCrossSegZs,
                      onChanged: (v) => setSheetState(
                          () => temp = temp.copyWith(allowCrossSegZs: v)),
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
      body: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildLeftToolbar(),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildChartPanel()),
                  ReplayControllerBar(
                    enabled: _isStepMode,
                    playing: _playing,
                    cursor: _effectiveCursor,
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
          ],
        ),
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
          _toolbarButton(
            label: '一次性',
            selected: _displayMode == ReplayDisplayMode.full,
            onTap: () => _setDisplayMode(ReplayDisplayMode.full),
          ),
          _toolbarButton(
            label: '逐K',
            selected: _displayMode == ReplayDisplayMode.step,
            onTap: () => _setDisplayMode(ReplayDisplayMode.step),
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
                  _loadTencent();
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
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
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
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeftToolbar() {
    final width = _toolbarExpanded ? 48.0 : 28.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              _arrowToggle(),
              if (_toolbarExpanded) ...[
                const Divider(height: 12, color: Colors.white12),
                _toolIcon(
                  tooltip: '十字光标',
                  icon: Icons.add,
                  selected: _crosshairIndex != null,
                  onPressed: () => setState(() => _crosshairIndex = null),
                ),
                _toolIcon(
                  tooltip: '显示分型顶底',
                  icon: Icons.trip_origin,
                  selected: _showFx,
                  onPressed: () => setState(() => _showFx = !_showFx),
                ),
                _toolIcon(
                  tooltip: '显示分型顶底文字',
                  icon: Icons.title,
                  selected: _showFxText,
                  onPressed: () => setState(() => _showFxText = !_showFxText),
                ),
                _toolIcon(
                  tooltip: '显示分型顶底连线',
                  icon: Icons.timeline,
                  selected: _showFxLine,
                  onPressed: () => setState(() => _showFxLine = !_showFxLine),
                ),
                _toolIcon(
                  tooltip: '显示笔',
                  icon: Icons.show_chart,
                  selected: _showBi,
                  onPressed: () => setState(() => _showBi = !_showBi),
                ),
                _toolIcon(
                  tooltip: '显示笔端点文字',
                  icon: Icons.text_fields,
                  selected: _showBiText,
                  onPressed: () => setState(() => _showBiText = !_showBiText),
                ),
                _toolIcon(
                  tooltip: '显示线段',
                  icon: Icons.multiline_chart,
                  selected: _showSeg,
                  onPressed: () => setState(() => _showSeg = !_showSeg),
                ),
                _toolIcon(
                  tooltip: '显示线段端点文字',
                  icon: Icons.font_download_outlined,
                  selected: _showSegText,
                  onPressed: () => setState(() => _showSegText = !_showSegText),
                ),
                _toolIcon(
                  tooltip: '显示中枢',
                  icon: Icons.crop_square,
                  selected: _showZs,
                  onPressed: () => setState(() => _showZs = !_showZs),
                ),
                const Divider(height: 18, color: Colors.white12),
                _toolIcon(
                  tooltip: '左右放大：减少可见K线数量',
                  icon: Icons.zoom_in,
                  onPressed: () => _changeWindowSize(_windowSize - 15),
                ),
                _toolIcon(
                  tooltip: '左右缩小：增加可见K线数量',
                  icon: Icons.zoom_out,
                  onPressed: () => _changeWindowSize(_windowSize + 15),
                ),
                _toolIcon(
                  tooltip: '上下放大：压缩价格区间',
                  icon: Icons.keyboard_arrow_up,
                  onPressed: () => _changePriceScale(_priceScale * 1.18),
                ),
                _toolIcon(
                  tooltip: '上下缩小：放大价格区间',
                  icon: Icons.keyboard_arrow_down,
                  onPressed: () => _changePriceScale(_priceScale / 1.18),
                ),
                _toolIcon(
                  tooltip: '重置缩放',
                  icon: Icons.center_focus_strong,
                  onPressed: _resetChartZoom,
                ),
                _toolIcon(
                  tooltip: '回到最新K线',
                  icon: Icons.my_location,
                  onPressed: _goToLatest,
                ),
                const Divider(height: 18, color: Colors.white12),
                _toolIcon(
                  tooltip: '引擎参数',
                  icon: Icons.tune,
                  onPressed: _openSettings,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrowToggle() {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _toolbarExpanded = !_toolbarExpanded),
      child: SizedBox(
        width: _toolbarExpanded ? 36 : 24,
        height: 30,
        child: Center(
          child: Text(
            _toolbarExpanded ? '<-' : '->',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          color: selected ? Colors.white : Colors.white60,
          style: IconButton.styleFrom(
            backgroundColor:
                selected ? const Color(0xFF2962FF) : Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }

  Widget _buildChartPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
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
            showFxLine: _showFxLine,
            showFxText: _showFxText,
            showBi: _showBi,
            showBiText: _showBiText,
            showSeg: _showSeg,
            showSegText: _showSegText,
            showZs: _showZs,
            windowSize: _windowSize,
            priceScale: _priceScale,
            viewEndIndex: _viewEndIndex,
            crosshairIndex: _crosshairIndex,
            onCrosshairChanged: (i) => setState(() => _crosshairIndex = i),
            onPanBars: _panChartByBars,
            onWindowSizeChanged: _changeWindowSize,
            onPriceScaleChanged: _changePriceScale,
          ),
        ),
      ),
    );
  }

  DateTime? _parseDateInput(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final y = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    final d = int.tryParse(match.group(3)!);
    if (y == null || m == null || d == null) return null;
    final parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;
    return parsed;
  }

  String _dateRangeLabel(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    return ' ${_fmtDate(start) ?? '开始'}~${_fmtDate(end) ?? '最新'}';
  }

  String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
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
}
