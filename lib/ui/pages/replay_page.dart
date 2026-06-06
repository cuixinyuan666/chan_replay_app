import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/engine/chan_config.dart';
import '../../core/engine/chan_replay_engine.dart';
import '../../core/models/raw_bar.dart';
import '../../core/models/chan_snapshot.dart';
import '../../data/csv_loader.dart';
import '../widgets/kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key});

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  final ChanReplayEngine _engine = ChanReplayEngine();
  List<RawBar> _allBars = [];
  ChanSnapshot _snapshot = ChanSnapshot.empty();
  int _cursor = 0;
  int _windowSize = 90;
  bool _playing = false;
  bool _showFx = true;
  bool _showBi = true;
  bool _showZs = true;
  Timer? _timer;

  ChanConfig _config = const ChanConfig();

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSample() async {
    final bars =
        await CsvLoader.loadFromAsset('assets/sample_data/000001_daily.csv');
    if (!mounted) return;
    setState(() {
      _allBars = bars;
      _cursor = math.min(120, bars.length);
      _rebuildSnapshot();
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
      _stopPlay();
      _allBars = bars;
      _cursor = math.min(120, bars.length);
      _rebuildSnapshot();
    });
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
        : '当前：$_cursor/${_allBars.length}  分型:${_snapshot.fxs.length}  笔:${_snapshot.bis.length}  中枢:${_snapshot.zss.length}';

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
