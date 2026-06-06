import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/engine/chan_config.dart';
import '../../core/engine/chan_replay_engine.dart';
import '../../core/models/raw_bar.dart';
import '../../core/models/chan_snapshot.dart';
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
    _cursor = math.min(120, bars.length);
    _dataSourceLabel = sourceLabel;
    _rebuildSnapshot();
  }

  void _rebuildSnapshot() {
    _engine.setConfig(_config);
    _snapshot = _engine.feedMany(_allBars.take(_cursor).toList());
  }

  void _reset() {
    setState(() {
      _stopPlay();
      _cursor = math.min(30, _allBars.length);
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
    });
  }

  void _jumpTo(int nextCursor) {
    setState(() {
      _cursor = nextCursor.clamp(0, _allBars.length);
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

  void _openDataSourcePanel() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
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
                          value: count.toDouble().clamp(100, 2000),
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
                              label: const Text('恢复示例CSV'),
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
    final subtitle = _allBars.isEmpty
        ? '暂无数据'
        : '$_dataSourceLabel  当前：$_cursor/${_allBars.length}  分型:${_snapshot.fxs.length}  笔:${_snapshot.bis.length}  中枢:${_snapshot.zss.length}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('缠论K线复盘'),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '数据源',
            onPressed: _openDataSourcePanel,
            icon: const Icon(Icons.cloud_sync),
          ),
          IconButton(
            tooltip: '导入CSV',
            onPressed: _importCsv,
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: '引擎参数',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTogglePanel(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0D10),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: KlineChart(
                    snapshot: _snapshot,
                    showFx: _showFx,
                    showBi: _showBi,
                    showZs: _showZs,
                    windowSize: _windowSize,
                  ),
                ),
              ),
            ),
          ),
          _buildWindowSlider(),
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
    );
  }

  Widget _buildTogglePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            label: const Text('分型'),
            selected: _showFx,
            onSelected: (v) => setState(() => _showFx = v),
          ),
          FilterChip(
            label: const Text('笔'),
            selected: _showBi,
            onSelected: (v) => setState(() => _showBi = v),
          ),
          FilterChip(
            label: const Text('中枢'),
            selected: _showZs,
            onSelected: (v) => setState(() => _showZs = v),
          ),
          const SizedBox(width: 6),
          Text('窗口: $_windowSize根',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildWindowSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Text('缩放'),
          Expanded(
            child: Slider(
              min: 40,
              max: 180,
              divisions: 14,
              value: _windowSize.toDouble().clamp(40, 180),
              onChanged: (v) => setState(() => _windowSize = v.round()),
            ),
          ),
        ],
      ),
    );
  }
}
