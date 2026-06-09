import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/bsp.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';
import '../../data/python_chan_analysis_source.dart';
import '../widgets/origin_kline_chart.dart';
import '../widgets/replay_controller_bar.dart';

enum _SettingTone { defaultValue, changed, invalid }

class OriginReplayPageV2 extends StatefulWidget {
  const OriginReplayPageV2({super.key});

  @override
  State<OriginReplayPageV2> createState() => _OriginReplayPageV2State();
}

class _OriginReplayPageV2State extends State<OriginReplayPageV2> {
  static final DateTime _defaultStartDate = DateTime(2020, 1, 1);
  static final DateTime _defaultEndDate = DateTime(2026, 6, 6);

  static const List<String> _bspTypes = ['1', '1p', '2', '2s', '3a', '3b'];
  static const List<String> _macdAlgoValues = [
    'area',
    'peak',
    'full_area',
    'diff',
    'slope',
    'amp',
    'volumn',
    'amount',
    'volumn_avg',
    'amount_avg',
    'turnrate_avg',
    'rsi',
  ];

  static const Map<String, Object?> _settingDefaults = {
    'skip_step': 0,
    'bi_algo': 'normal',
    'bi_strict': true,
    'bi_fx_check': 'strict',
    'gap_as_kl': false,
    'bi_end_is_peak': true,
    'bi_allow_sub_peak': true,
    'seg_algo': 'chan',
    'left_seg_method': 'peak',
    'zs_algo': 'normal',
    'zs_combine': true,
    'zs_combine_mode': 'zs',
    'one_bi_zs': false,
    'kl_data_check': true,
    'max_kl_misalgin_cnt': 2,
    'max_kl_inconsistent_cnt': 5,
    'auto_skip_illegal_sub_lv': false,
    'print_warning': true,
    'print_err_time': true,
    'mean_metrics': '',
    'trend_metrics': '',
    'macd_fast': 12,
    'macd_slow': 26,
    'macd_signal': 9,
    'cal_demark': false,
    'cal_rsi': false,
    'cal_kdj': false,
    'rsi_cycle': 14,
    'kdj_cycle': 9,
    'demark_len': 9,
    'demark_setup_bias': 4,
    'demark_countdown_bias': 2,
    'demark_max_countdown': 13,
    'demark_tiaokong_st': true,
    'demark_setup_cmp2close': true,
    'demark_countdown_cmp2close': true,
    'boll_n': 20,
    'bs_type': '1,1p,2,2s,3a,3b',
    'divergence_rate': '1e18',
    'min_zs_cnt': 1,
    'bsp1_only_multibi_zs': true,
    'max_bs2_rate': '0.9999',
    'bs1_peak': true,
    'bsp2_follow_1': true,
    'bsp3_follow_1': true,
    'bsp3_peak': false,
    'bsp2s_follow_2': false,
    'max_bsp2s_lv': '',
    'strict_bsp3': false,
    'bsp3a_max_zs_cnt': 1,
    'macd_algo': 'peak',
  };

  final TextEditingController _stockCodeController =
      TextEditingController(text: '000001');
  final TextEditingController _backendUrlController =
      TextEditingController(text: _defaultBackendBaseUrl);

  ChanSnapshot _snapshot = ChanSnapshot.empty();
  ChanSnapshot _fullSnapshot = ChanSnapshot.empty();
  List<ChanSnapshot> _frames = const [];
  List<RawBar>? _localCsvBars;
  String _localCsvName = '';

  int _cursor = 0;
  int _windowSize = 90;
  double _priceScale = 1.0;
  int? _viewEndIndex;
  int? _crosshairIndex;
  bool _loading = false;
  bool _playing = false;
  bool _toolbarExpanded = true;
  bool _showFx = true;
  bool _showFxLine = true;
  bool _showFxText = true;
  bool _showBi = true;
  bool _showBiText = false;
  bool _showSeg = true;
  bool _showSegText = true;
  bool _showZs = true;
  bool _showBiBsp = true;
  bool _showSegBsp = true;
  bool _showMergedBars = false;
  Timer? _timer;

  String _mode = 'once';
  String _dataSource = 'easy_tdx';
  String _period = 'DAILY';
  String _adjust = 'QFQ';
  DateTime _startDate = _defaultStartDate;
  DateTime _endDate = _defaultEndDate;
  String _status = 'Python chan.py 引擎未加载';

  String _biAlgo = 'normal';
  bool _biStrict = true;
  String _biFxCheck = 'strict';
  bool _gapAsKl = false;
  bool _biEndIsPeak = true;
  bool _biAllowSubPeak = true;
  String _segAlgo = 'chan';
  String _leftSegMethod = 'peak';
  String _zsAlgo = 'normal';
  bool _zsCombine = true;
  String _zsCombineMode = 'zs';
  bool _oneBiZs = false;

  int _skipStep = 0;
  bool _klDataCheck = true;
  int _maxKlMisalginCnt = 2;
  int _maxKlInconsistentCnt = 5;
  bool _autoSkipIllegalSubLv = false;
  bool _printWarning = true;
  bool _printErrTime = true;

  String _meanMetrics = '';
  String _trendMetrics = '';
  int _macdFast = 12;
  int _macdSlow = 26;
  int _macdSignal = 9;
  bool _calDemark = false;
  bool _calRsi = false;
  bool _calKdj = false;
  int _rsiCycle = 14;
  int _kdjCycle = 9;
  int _demarkLen = 9;
  int _demarkSetupBias = 4;
  int _demarkCountdownBias = 2;
  int _demarkMaxCountdown = 13;
  bool _demarkTiaokongSt = true;
  bool _demarkSetupCmp2close = true;
  bool _demarkCountdownCmp2close = true;
  int _bollN = 20;

  String _bsType = '1,1p,2,2s,3a,3b';
  String _divergenceRate = '1e18';
  int _minZsCnt = 1;
  bool _bsp1OnlyMultibiZs = true;
  String _maxBs2Rate = '0.9999';
  bool _bs1Peak = true;
  bool _bsp2Follow1 = true;
  bool _bsp3Follow1 = true;
  bool _bsp3Peak = false;
  bool _bsp2sFollow2 = false;
  String _maxBsp2sLv = '';
  bool _strictBsp3 = false;
  int _bsp3aMaxZsCnt = 1;
  String _macdAlgo = 'peak';

  static bool get _isAndroidApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String get _defaultBackendBaseUrl =>
      _isAndroidApp ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  bool get _isStepMode => _mode == 'step';
  bool get _hasBars => _fullSnapshot.rawBars.isNotEmpty;
  int get _stepTotal =>
      _frames.isNotEmpty ? _frames.length : _fullSnapshot.rawBars.length;
  bool get _hasFx => _fullSnapshot.fxs.isNotEmpty;
  bool get _hasFxLine => _fullSnapshot.fxs.length >= 2;
  bool get _hasBi => _fullSnapshot.bis.isNotEmpty;
  bool get _hasSeg => _fullSnapshot.segs.isNotEmpty;
  bool get _hasZs => _fullSnapshot.zss.isNotEmpty;
  bool get _hasMergedBars => _fullSnapshot.mergedBars.isNotEmpty;
  bool get _hasBiBsp => _fullSnapshot.bsps.any(_isBiBsp);
  bool get _hasSegBsp => _fullSnapshot.bsps.any(_isSegBsp);

  String get _drawingStorageKey {
    final source = _dataSource.trim().isEmpty ? 'source' : _dataSource.trim();
    if (_dataSource == 'csv') {
      final csvName =
          _localCsvName.trim().isEmpty ? 'local_csv' : _localCsvName.trim();
      return _safeStoragePart(
          'drawing_${source}_${csvName}_${_period}_$_adjust');
    }
    final symbol = _parseSymbol(_stockCodeController.text.trim());
    final symbolKey = symbol == null
        ? _stockCodeController.text.trim().toUpperCase()
        : '${symbol.market}${symbol.code}';
    return _safeStoragePart(
        'drawing_${source}_${symbolKey}_${_period}_$_adjust');
  }

  Map<String, dynamic> get _chanConfig => {
        'skip_step': _skipStep,
        'bi_algo': _biAlgo,
        'bi_strict': _biStrict,
        'bi_fx_check': _biFxCheck,
        'gap_as_kl': _gapAsKl,
        'bi_end_is_peak': _biEndIsPeak,
        'bi_allow_sub_peak': _biAllowSubPeak,
        'seg_algo': _segAlgo,
        'left_seg_method': _leftSegMethod,
        'zs_algo': _zsAlgo,
        'zs_combine': _zsCombine,
        'zs_combine_mode': _zsCombineMode,
        'one_bi_zs': _oneBiZs,
        'kl_data_check': _klDataCheck,
        'max_kl_misalgin_cnt': _maxKlMisalginCnt,
        'max_kl_inconsistent_cnt': _maxKlInconsistentCnt,
        'auto_skip_illegal_sub_lv': _autoSkipIllegalSubLv,
        'print_warning': _printWarning,
        'print_err_time': _printErrTime,
        'mean_metrics': _meanMetrics,
        'trend_metrics': _trendMetrics,
        'macd_fast': _macdFast,
        'macd_slow': _macdSlow,
        'macd_signal': _macdSignal,
        'cal_demark': _calDemark,
        'cal_rsi': _calRsi,
        'cal_kdj': _calKdj,
        'rsi_cycle': _rsiCycle,
        'kdj_cycle': _kdjCycle,
        'demark_len': _demarkLen,
        'demark_setup_bias': _demarkSetupBias,
        'demark_countdown_bias': _demarkCountdownBias,
        'demark_max_countdown': _demarkMaxCountdown,
        'demark_tiaokong_st': _demarkTiaokongSt,
        'demark_setup_cmp2close': _demarkSetupCmp2close,
        'demark_countdown_cmp2close': _demarkCountdownCmp2close,
        'boll_n': _bollN,
        'bs_type': _bsType,
        'divergence_rate': _divergenceRate,
        'min_zs_cnt': _minZsCnt,
        'bsp1_only_multibi_zs': _bsp1OnlyMultibiZs,
        'max_bs2_rate': _maxBs2Rate,
        'bs1_peak': _bs1Peak,
        'bsp2_follow_1': _bsp2Follow1,
        'bsp3_follow_1': _bsp3Follow1,
        'bsp3_peak': _bsp3Peak,
        'bsp2s_follow_2': _bsp2sFollow2,
        'max_bsp2s_lv': _maxBsp2sLv,
        'strict_bsp3': _strictBsp3,
        'bsp3a_max_zs_cnt': _bsp3aMaxZsCnt,
        'macd_algo': _macdAlgo,
      };

  @override
  void dispose() {
    _timer?.cancel();
    _stockCodeController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    if (_startDate.isAfter(_endDate)) {
      _showMessage('× 开始日期不能晚于结束日期');
      return;
    }

    final symbol = _parseSymbol(_stockCodeController.text.trim());
    if (_dataSource != 'csv' && symbol == null) {
      _showMessage('× 代码格式错误：请输入 000001 / 600000 / SZ000001 / 600000.SH');
      return;
    }
    if (_dataSource == 'csv' &&
        (_localCsvBars == null || _localCsvBars!.isEmpty)) {
      _showMessage('× 请先选择本地 CSV');
      return;
    }

    setState(() => _loading = true);
    final source =
        PythonChanAnalysisSource(baseUrl: _backendUrlController.text.trim());
    try {
      final analysis = _dataSource == 'csv'
          ? await source.analyzeBars(
              mode: _mode,
              symbol: _localCsvName.isEmpty ? 'local_csv' : _localCsvName,
              market: 'LOCAL',
              period: _period,
              adjust: _adjust,
              bars: _localCsvBars!,
              config: _chanConfig,
            )
          : await source.analyze(
              mode: _mode,
              market: symbol!.market,
              code: symbol.code,
              period: _period,
              adjust: _adjust,
              startDate: _startDate,
              endDate: _endDate,
              config: _chanConfig,
            );
      if (!mounted) return;

      setState(() {
        _stopPlay();
        _fullSnapshot = analysis.snapshot;
        _frames = analysis.frames;
        if (_isStepMode && _frames.isNotEmpty) {
          _cursor = 0;
          _snapshot = _frames.first;
        } else {
          _cursor = _isStepMode
              ? math.min(120, analysis.snapshot.rawBars.length).toInt()
              : analysis.snapshot.rawBars.length;
          _snapshot = _isStepMode
              ? _sliceSnapshot(analysis.snapshot, _cursor)
              : analysis.snapshot;
        }
        _viewEndIndex = null;
        _crosshairIndex = null;
        _priceScale = 1.0;

        final name = _dataSource == 'csv'
            ? (_localCsvName.isEmpty ? '本地CSV' : _localCsvName)
            : '${symbol!.market}${symbol.code}';
        final biBspCnt = _snapshot.bsps.where(_isBiBsp).length;
        final segBspCnt = _snapshot.bsps.where(_isSegBsp).length;
        _status = 'chan.py 获取$name $_periodAdjustLabel '
            'K:${_snapshot.rawBars.length} MB:${_snapshot.mergedBars.length} '
            'FX:${_snapshot.fxs.length} BI:${_snapshot.bis.length} '
            'SEG:${_snapshot.segs.length} ZS:${_snapshot.zss.length} '
            'BSP:${_snapshot.bsps.length} 笔BSP:$biBspCnt 段BSP:$segBspCnt';
      });
      _showMessage('√ $_status');
    } catch (e) {
      if (mounted) _showMessage('× Python chan.py 引擎失败：$e');
    } finally {
      source.close();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('× 读取 CSV 失败：未返回文件内容');
      return;
    }

    try {
      final rows = _parseCsvBars(utf8.decode(bytes, allowMalformed: true));
      if (rows.isEmpty) {
        _showMessage('× CSV 未识别到 K线，请检查列名 time/open/high/low/close');
        return;
      }
      setState(() {
        _dataSource = 'csv';
        _localCsvName = file.name;
        _localCsvBars = rows;
        _status =
            '已读取本地CSV ${file.name}，${rows.length} 根K线，等待 Python chan.py 分析';
      });
      await _load();
    } catch (e) {
      _showMessage('× CSV 解析失败：$e');
    }
  }

  List<RawBar> _parseCsvBars(String text) {
    final lines = const LineSplitter()
        .convert(text)
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final sep = lines.first.contains('\t') ? '\t' : ',';
    final headers =
        lines.first.split(sep).map((e) => e.trim().toLowerCase()).toList();
    int col(List<String> names) => headers.indexWhere((h) => names.contains(h));

    final timeCol = col(['time', 'dt', 'date', 'datetime', 'trade_date']);
    final openCol = col(['open', 'o']);
    final highCol = col(['high', 'h']);
    final lowCol = col(['low', 'l']);
    final closeCol = col(['close', 'c']);
    final volCol = col(['vol', 'volume', 'v']);
    if ([timeCol, openCol, highCol, lowCol, closeCol].any((e) => e < 0))
      return [];

    final bars = <RawBar>[];
    for (var i = 1; i < lines.length; i++) {
      final cells = lines[i].split(sep).map((e) => e.trim()).toList();
      if (cells.length <=
          [timeCol, openCol, highCol, lowCol, closeCol].reduce(math.max))
        continue;

      final time = DateTime.tryParse(
          cells[timeCol].replaceAll('/', '-').replaceFirst(' ', 'T'));
      final open = double.tryParse(cells[openCol].replaceAll(',', ''));
      final high = double.tryParse(cells[highCol].replaceAll(',', ''));
      final low = double.tryParse(cells[lowCol].replaceAll(',', ''));
      final close = double.tryParse(cells[closeCol].replaceAll(',', ''));
      final vol = volCol >= 0 && volCol < cells.length
          ? double.tryParse(cells[volCol].replaceAll(',', '')) ?? 0
          : 0.0;
      if (time == null ||
          open == null ||
          high == null ||
          low == null ||
          close == null) continue;

      bars.add(
        RawBar(
          index: bars.length,
          time: time,
          open: open,
          high: math.max(math.max(open, high), math.max(low, close)),
          low: math.min(math.min(open, high), math.min(low, close)),
          close: close,
          volume: vol,
        ),
      );
    }
    return bars;
  }

  ChanSnapshot _sliceSnapshot(ChanSnapshot source, int cursor) {
    final c = cursor.clamp(0, source.rawBars.length).toInt();
    bool inCursor(int rawIndex) => rawIndex < c;
    return ChanSnapshot(
      rawBars: source.rawBars.take(c).toList(),
      mergedBars: source.mergedBars.where((e) => e.endRawIndex < c).toList(),
      fxs: source.fxs.where((e) => inCursor(e.rawIndex)).toList(),
      bis: source.bis.where((e) => inCursor(e.endRawIndex)).toList(),
      segs: source.segs.where((e) => inCursor(e.endRawIndex)).toList(),
      zss: source.zss.where((e) => inCursor(e.endRawIndex)).toList(),
      bsps: source.bsps.where((e) => inCursor(e.rawIndex)).toList(),
    );
  }

  bool _isSegBsp(BspPoint bsp) {
    final level = bsp.level.trim().toLowerCase();
    return level == 'seg' || level == 'segment' || level.contains('seg');
  }

  bool _isBiBsp(BspPoint bsp) {
    final level = bsp.level.trim().toLowerCase();
    return level.isEmpty ||
        level == 'bi' ||
        (!level.contains('seg') && level != 'segment');
  }

  void _reset() {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _stopPlay();
      _cursor = 0;
      _snapshot =
          _frames.isNotEmpty ? _frames.first : _sliceSnapshot(_fullSnapshot, 0);
      _viewEndIndex = null;
      _crosshairIndex = null;
    });
  }

  void _stepForward() {
    if (!_isStepMode || !_hasBars) return;
    if (_cursor + 1 >= _stepTotal) {
      _stopPlay();
      return;
    }
    setState(() {
      _cursor += 1;
      _snapshot = _frames.isNotEmpty
          ? _frames[_cursor]
          : _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _stepBack() {
    if (!_isStepMode || !_hasBars || _cursor <= 0) return;
    setState(() {
      _cursor -= 1;
      _snapshot = _frames.isNotEmpty
          ? _frames[_cursor]
          : _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _jumpTo(int value) {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _cursor = value.clamp(0, math.max(0, _stepTotal - 1)).toInt();
      _snapshot = _frames.isNotEmpty
          ? _frames[_cursor]
          : _sliceSnapshot(_fullSnapshot, _cursor);
    });
  }

  void _togglePlay() {
    if (!_isStepMode || !_hasBars) return;
    setState(() {
      _playing = !_playing;
      _timer?.cancel();
      _timer = _playing
          ? Timer.periodic(
              const Duration(milliseconds: 450), (_) => _stepForward())
          : null;
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
    if (next != current) setState(() => _viewEndIndex = next);
  }

  Future<void> _openDataPanel() => _showSettingsPanel(initialTab: 0);
  Future<void> _openConfigPanel() => _showSettingsPanel(initialTab: 1);

  Future<void> _showSettingsPanel({required int initialTab}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      builder: (context) {
        var dataSource = _dataSource;
        var mode = _mode;
        var period = _period;
        var adjust = _adjust;
        var start = _startDate;
        var end = _endDate;
        var biAlgo = _biAlgo;
        var biStrict = _biStrict;
        var biFxCheck = _biFxCheck;
        var gapAsKl = _gapAsKl;
        var biEndIsPeak = _biEndIsPeak;
        var biAllowSubPeak = _biAllowSubPeak;
        var segAlgo = _segAlgo;
        var leftSegMethod = _leftSegMethod;
        var zsAlgo = _zsAlgo;
        var zsCombine = _zsCombine;
        var zsCombineMode = _zsCombineMode;
        var oneBiZs = _oneBiZs;
        var skipStep = _skipStep;
        var klDataCheck = _klDataCheck;
        var maxKlMisalginCnt = _maxKlMisalginCnt;
        var maxKlInconsistentCnt = _maxKlInconsistentCnt;
        var autoSkipIllegalSubLv = _autoSkipIllegalSubLv;
        var printWarning = _printWarning;
        var printErrTime = _printErrTime;
        var meanMetrics = _meanMetrics;
        var trendMetrics = _trendMetrics;
        var macdFast = _macdFast;
        var macdSlow = _macdSlow;
        var macdSignal = _macdSignal;
        var calDemark = _calDemark;
        var calRsi = _calRsi;
        var calKdj = _calKdj;
        var rsiCycle = _rsiCycle;
        var kdjCycle = _kdjCycle;
        var demarkLen = _demarkLen;
        var demarkSetupBias = _demarkSetupBias;
        var demarkCountdownBias = _demarkCountdownBias;
        var demarkMaxCountdown = _demarkMaxCountdown;
        var demarkTiaokongSt = _demarkTiaokongSt;
        var demarkSetupCmp2close = _demarkSetupCmp2close;
        var demarkCountdownCmp2close = _demarkCountdownCmp2close;
        var bollN = _bollN;
        var bsType = _bsType;
        var divergenceRate = _divergenceRate;
        var minZsCnt = _minZsCnt;
        var bsp1OnlyMultibiZs = _bsp1OnlyMultibiZs;
        var maxBs2Rate = _maxBs2Rate;
        var bs1Peak = _bs1Peak;
        var bsp2Follow1 = _bsp2Follow1;
        var bsp3Follow1 = _bsp3Follow1;
        var bsp3Peak = _bsp3Peak;
        var bsp2sFollow2 = _bsp2sFollow2;
        var maxBsp2sLv = _maxBsp2sLv;
        var strictBsp3 = _strictBsp3;
        var bsp3aMaxZsCnt = _bsp3aMaxZsCnt;
        var macdAlgo = _macdAlgo;

        return DefaultTabController(
          initialIndex: initialTab,
          length: 2,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Widget intField(String key, String label, int value,
                  ValueChanged<int> onChanged,
                  {int min = 0, String? helper}) {
                final tone = _settingTone(key, value, valid: value >= min);
                return TextFormField(
                  initialValue: '$value',
                  enabled: !_loading,
                  keyboardType: TextInputType.number,
                  decoration: _settingDecoration(label, tone,
                      helper: helper ?? '最小值 $min'),
                  onChanged: (v) => setSheetState(
                      () => onChanged(int.tryParse(v.trim()) ?? value)),
                );
              }

              Widget textField(String key, String label, String value,
                  ValueChanged<String> onChanged,
                  {String? helper, bool valid = true}) {
                final tone = _settingTone(key, value, valid: valid);
                return TextFormField(
                  initialValue: value,
                  enabled: !_loading,
                  decoration: _settingDecoration(label, tone, helper: helper),
                  onChanged: (v) => setSheetState(() => onChanged(v.trim())),
                );
              }

              Widget dropdownSetting(String key, String label, String value,
                  List<String> values, ValueChanged<String?>? onChanged) {
                final tone =
                    _settingTone(key, value, valid: values.contains(value));
                return DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: _settingDecoration(label, tone),
                  items: values
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: _loading ? null : onChanged,
                );
              }

              Widget boolTile(String key, String title, bool value,
                  ValueChanged<bool> onChanged) {
                final tone = _settingTone(key, value);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _toneColor(tone).withValues(alpha: 0.82),
                        width: 1.2),
                  ),
                  child: SwitchListTile(
                    value: value,
                    onChanged: _loading
                        ? null
                        : (v) => setSheetState(() => onChanged(v)),
                    title: Text(title,
                        style: TextStyle(
                            color: _toneColor(tone),
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(_toneText(tone),
                        style: TextStyle(
                            color: _toneColor(tone).withValues(alpha: 0.82),
                            fontSize: 11)),
                  ),
                );
              }

              Widget row2(Widget a, Widget b) => Row(children: [
                    Expanded(child: a),
                    const SizedBox(width: 10),
                    Expanded(child: b)
                  ]);

              Widget bspTypeSelector() {
                final selected = _csvTokens(bsType).toSet();
                final valid = _validBspTypeText(bsType);
                final tone = _settingTone(
                    'bs_type', _normalizeBspTypeText(bsType),
                    valid: valid);
                return InputDecorator(
                  decoration: _settingDecoration(
                    'bs_type',
                    tone,
                    helper: '来自 Vespa BSP_TYPE: 1 / 1p / 2 / 2s / 3a / 3b',
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final type in _bspTypes)
                        FilterChip(
                          label: Text(type),
                          selected: selected.contains(type),
                          selectedColor:
                              _toneColor(tone).withValues(alpha: 0.20),
                          checkmarkColor: _toneColor(tone),
                          side: BorderSide(
                              color: _toneColor(tone).withValues(alpha: 0.70)),
                          onSelected: _loading
                              ? null
                              : (v) => setSheetState(() =>
                                  bsType = _toggleCsvToken(bsType, type, v)),
                        ),
                    ],
                  ),
                );
              }

              void applyAndReload() {
                Navigator.pop(context);
                setState(() {
                  _dataSource = dataSource;
                  _mode = mode;
                  _period = period;
                  _adjust = adjust;
                  _startDate = start;
                  _endDate = end;
                  _biAlgo = biAlgo;
                  _biStrict = biStrict;
                  _biFxCheck = biFxCheck;
                  _gapAsKl = gapAsKl;
                  _biEndIsPeak = biEndIsPeak;
                  _biAllowSubPeak = biAllowSubPeak;
                  _segAlgo = segAlgo;
                  _leftSegMethod = leftSegMethod;
                  _zsAlgo = zsAlgo;
                  _zsCombine = zsCombine;
                  _zsCombineMode = zsCombineMode;
                  _oneBiZs = oneBiZs;
                  _skipStep = skipStep;
                  _klDataCheck = klDataCheck;
                  _maxKlMisalginCnt = maxKlMisalginCnt;
                  _maxKlInconsistentCnt = maxKlInconsistentCnt;
                  _autoSkipIllegalSubLv = autoSkipIllegalSubLv;
                  _printWarning = printWarning;
                  _printErrTime = printErrTime;
                  _meanMetrics = meanMetrics;
                  _trendMetrics = trendMetrics;
                  _macdFast = macdFast;
                  _macdSlow = macdSlow;
                  _macdSignal = macdSignal;
                  _calDemark = calDemark;
                  _calRsi = calRsi;
                  _calKdj = calKdj;
                  _rsiCycle = rsiCycle;
                  _kdjCycle = kdjCycle;
                  _demarkLen = demarkLen;
                  _demarkSetupBias = demarkSetupBias;
                  _demarkCountdownBias = demarkCountdownBias;
                  _demarkMaxCountdown = demarkMaxCountdown;
                  _demarkTiaokongSt = demarkTiaokongSt;
                  _demarkSetupCmp2close = demarkSetupCmp2close;
                  _demarkCountdownCmp2close = demarkCountdownCmp2close;
                  _bollN = bollN;
                  _bsType = _normalizeBspTypeText(bsType);
                  _divergenceRate = divergenceRate;
                  _minZsCnt = minZsCnt;
                  _bsp1OnlyMultibiZs = bsp1OnlyMultibiZs;
                  _maxBs2Rate = maxBs2Rate;
                  _bs1Peak = bs1Peak;
                  _bsp2Follow1 = bsp2Follow1;
                  _bsp3Follow1 = bsp3Follow1;
                  _bsp3Peak = bsp3Peak;
                  _bsp2sFollow2 = bsp2sFollow2;
                  _maxBsp2sLv = maxBsp2sLv;
                  _strictBsp3 = strictBsp3;
                  _bsp3aMaxZsCnt = bsp3aMaxZsCnt;
                  _macdAlgo = macdAlgo;
                });
                _load();
              }

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.84,
                    child: Column(
                      children: [
                        const TabBar(
                            tabs: [Tab(text: '数据'), Tab(text: 'CChanConfig')]),
                        Expanded(
                          child: TabBarView(
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    _dropdown(
                                      '数据源',
                                      dataSource,
                                      const ['easy_tdx', 'csv'],
                                      (v) => setSheetState(
                                          () => dataSource = v ?? dataSource),
                                      labels: const {
                                        'easy_tdx': 'easy-tdx / Python chan.py',
                                        'csv': '本地 CSV / Python chan.py'
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                        controller: _backendUrlController,
                                        enabled: !_loading && !_isAndroidApp,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Windows Python chan.py 服务地址',
                                            border: OutlineInputBorder())),
                                    const SizedBox(height: 10),
                                    TextField(
                                        controller: _stockCodeController,
                                        enabled:
                                            !_loading && dataSource != 'csv',
                                        decoration: const InputDecoration(
                                            labelText: '代码（自动识别市场）',
                                            border: OutlineInputBorder())),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                        onPressed: _loading ? null : _pickCsv,
                                        icon: const Icon(Icons.upload_file),
                                        label: Text(_localCsvName.isEmpty
                                            ? '选择本地 CSV'
                                            : '已选 $_localCsvName')),
                                    const SizedBox(height: 10),
                                    _dropdown(
                                        '模式',
                                        mode,
                                        const ['once', 'step'],
                                        (v) => setSheetState(
                                            () => mode = v ?? mode),
                                        labels: const {
                                          'once': '一次性',
                                          'step':
                                              '严格逐K trigger_step / step_load'
                                        }),
                                    const SizedBox(height: 10),
                                    row2(
                                      _dropdown(
                                          '周期',
                                          period,
                                          const [
                                            'MIN1',
                                            'MIN5',
                                            'MIN15',
                                            'MIN30',
                                            'MIN60',
                                            'DAILY',
                                            'WEEKLY',
                                            'MONTHLY'
                                          ],
                                          (v) => setSheetState(
                                              () => period = v ?? period),
                                          labels: const {
                                            'MIN1': '1分钟',
                                            'MIN5': '5分钟',
                                            'MIN15': '15分钟',
                                            'MIN30': '30分钟',
                                            'MIN60': '60分钟',
                                            'DAILY': '日线',
                                            'WEEKLY': '周线',
                                            'MONTHLY': '月线'
                                          }),
                                      _dropdown(
                                          '复权',
                                          adjust,
                                          const ['QFQ', 'HFQ', 'NONE'],
                                          (v) => setSheetState(
                                              () => adjust = v ?? adjust),
                                          labels: const {
                                            'QFQ': '前复权',
                                            'HFQ': '后复权',
                                            'NONE': '不复权'
                                          }),
                                    ),
                                    const SizedBox(height: 10),
                                    row2(
                                      _dateTile('开始日期', start, !_loading,
                                          () async {
                                        final picked = await _pickDate(start);
                                        if (picked != null)
                                          setSheetState(() => start = picked);
                                      }),
                                      _dateTile('结束日期', end, !_loading,
                                          () async {
                                        final picked = await _pickDate(end);
                                        if (picked != null)
                                          setSheetState(() => end = picked);
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    const Text(
                                        '这些设置直接传给 Python CChanConfig；枚举值来自 Vespa Common/CEnum.py 和各 Config 类。',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 8),
                                    _settingToneLegend(),
                                    const SizedBox(height: 12),
                                    _sectionTitle('回放 / 数据校验'),
                                    intField('skip_step', 'skip_step', skipStep,
                                        (v) => skipStep = v),
                                    boolTile('kl_data_check', 'kl_data_check',
                                        klDataCheck, (v) => klDataCheck = v),
                                    row2(
                                        intField(
                                            'max_kl_misalgin_cnt',
                                            'max_kl_misalgin_cnt',
                                            maxKlMisalginCnt,
                                            (v) => maxKlMisalginCnt = v),
                                        intField(
                                            'max_kl_inconsistent_cnt',
                                            'max_kl_inconsistent_cnt',
                                            maxKlInconsistentCnt,
                                            (v) => maxKlInconsistentCnt = v)),
                                    boolTile(
                                        'auto_skip_illegal_sub_lv',
                                        'auto_skip_illegal_sub_lv',
                                        autoSkipIllegalSubLv,
                                        (v) => autoSkipIllegalSubLv = v),
                                    boolTile('print_warning', 'print_warning',
                                        printWarning, (v) => printWarning = v),
                                    boolTile('print_err_time', 'print_err_time',
                                        printErrTime, (v) => printErrTime = v),
                                    const SizedBox(height: 12),
                                    _sectionTitle('笔 BI'),
                                    row2(
                                        dropdownSetting(
                                            'bi_algo',
                                            'bi_algo',
                                            biAlgo,
                                            const ['normal', 'fx'],
                                            (v) => setSheetState(
                                                () => biAlgo = v ?? biAlgo)),
                                        dropdownSetting(
                                            'bi_fx_check',
                                            'bi_fx_check',
                                            biFxCheck,
                                            const [
                                              'strict',
                                              'loss',
                                              'half',
                                              'totally'
                                            ],
                                            (v) => setSheetState(() =>
                                                biFxCheck = v ?? biFxCheck))),
                                    boolTile('bi_strict', 'bi_strict', biStrict,
                                        (v) => biStrict = v),
                                    boolTile('gap_as_kl', 'gap_as_kl', gapAsKl,
                                        (v) => gapAsKl = v),
                                    boolTile('bi_end_is_peak', 'bi_end_is_peak',
                                        biEndIsPeak, (v) => biEndIsPeak = v),
                                    boolTile(
                                        'bi_allow_sub_peak',
                                        'bi_allow_sub_peak',
                                        biAllowSubPeak,
                                        (v) => biAllowSubPeak = v),
                                    const SizedBox(height: 12),
                                    _sectionTitle('线段 SEG'),
                                    row2(
                                        dropdownSetting(
                                            'seg_algo',
                                            'seg_algo',
                                            segAlgo,
                                            const ['chan', '1+1', 'break'],
                                            (v) => setSheetState(
                                                () => segAlgo = v ?? segAlgo)),
                                        dropdownSetting(
                                            'left_seg_method',
                                            'left_seg_method',
                                            leftSegMethod,
                                            const ['peak', 'all'],
                                            (v) => setSheetState(() =>
                                                leftSegMethod =
                                                    v ?? leftSegMethod))),
                                    const SizedBox(height: 12),
                                    _sectionTitle('中枢 ZS'),
                                    row2(
                                        dropdownSetting(
                                            'zs_algo',
                                            'zs_algo',
                                            zsAlgo,
                                            const [
                                              'normal',
                                              'over_seg',
                                              'auto'
                                            ],
                                            (v) => setSheetState(
                                                () => zsAlgo = v ?? zsAlgo)),
                                        dropdownSetting(
                                            'zs_combine_mode',
                                            'zs_combine_mode',
                                            zsCombineMode,
                                            const ['zs', 'peak'],
                                            (v) => setSheetState(() =>
                                                zsCombineMode =
                                                    v ?? zsCombineMode))),
                                    boolTile('zs_combine', 'zs_combine',
                                        zsCombine, (v) => zsCombine = v),
                                    boolTile('one_bi_zs', 'one_bi_zs', oneBiZs,
                                        (v) => oneBiZs = v),
                                    const SizedBox(height: 12),
                                    _sectionTitle('指标模型'),
                                    row2(
                                        textField(
                                            'mean_metrics',
                                            'mean_metrics',
                                            meanMetrics,
                                            (v) => meanMetrics = v,
                                            helper: '逗号分隔整数，如 5,10,20',
                                            valid:
                                                _validIntListText(meanMetrics)),
                                        textField(
                                            'trend_metrics',
                                            'trend_metrics',
                                            trendMetrics,
                                            (v) => trendMetrics = v,
                                            helper: '逗号分隔整数',
                                            valid: _validIntListText(
                                                trendMetrics))),
                                    row2(
                                        intField('macd_fast', 'macd.fast',
                                            macdFast, (v) => macdFast = v,
                                            min: 1),
                                        intField('macd_slow', 'macd.slow',
                                            macdSlow, (v) => macdSlow = v,
                                            min: 1)),
                                    intField('macd_signal', 'macd.signal',
                                        macdSignal, (v) => macdSignal = v,
                                        min: 1),
                                    row2(
                                        intField('boll_n', 'boll_n', bollN,
                                            (v) => bollN = v, min: 1),
                                        intField('rsi_cycle', 'rsi_cycle',
                                            rsiCycle, (v) => rsiCycle = v,
                                            min: 1)),
                                    intField('kdj_cycle', 'kdj_cycle', kdjCycle,
                                        (v) => kdjCycle = v,
                                        min: 1),
                                    boolTile('cal_demark', 'cal_demark',
                                        calDemark, (v) => calDemark = v),
                                    boolTile('cal_rsi', 'cal_rsi', calRsi,
                                        (v) => calRsi = v),
                                    boolTile('cal_kdj', 'cal_kdj', calKdj,
                                        (v) => calKdj = v),
                                    const SizedBox(height: 12),
                                    _sectionTitle('Demark'),
                                    row2(
                                        intField('demark_len', 'demark_len',
                                            demarkLen, (v) => demarkLen = v,
                                            min: 1),
                                        intField(
                                            'demark_setup_bias',
                                            'setup_bias',
                                            demarkSetupBias,
                                            (v) => demarkSetupBias = v,
                                            min: 1)),
                                    row2(
                                        intField(
                                            'demark_countdown_bias',
                                            'countdown_bias',
                                            demarkCountdownBias,
                                            (v) => demarkCountdownBias = v,
                                            min: 1),
                                        intField(
                                            'demark_max_countdown',
                                            'max_countdown',
                                            demarkMaxCountdown,
                                            (v) => demarkMaxCountdown = v,
                                            min: 1)),
                                    boolTile(
                                        'demark_tiaokong_st',
                                        'tiaokong_st',
                                        demarkTiaokongSt,
                                        (v) => demarkTiaokongSt = v),
                                    boolTile(
                                        'demark_setup_cmp2close',
                                        'setup_cmp2close',
                                        demarkSetupCmp2close,
                                        (v) => demarkSetupCmp2close = v),
                                    boolTile(
                                        'demark_countdown_cmp2close',
                                        'countdown_cmp2close',
                                        demarkCountdownCmp2close,
                                        (v) => demarkCountdownCmp2close = v),
                                    const SizedBox(height: 12),
                                    _sectionTitle('买卖点 BSP'),
                                    bspTypeSelector(),
                                    const SizedBox(height: 10),
                                    row2(
                                        textField(
                                            'divergence_rate',
                                            'divergence_rate',
                                            divergenceRate,
                                            (v) => divergenceRate = v,
                                            valid: _validDoubleText(
                                                divergenceRate)),
                                        textField(
                                            'max_bs2_rate',
                                            'max_bs2_rate',
                                            maxBs2Rate,
                                            (v) => maxBs2Rate = v,
                                            valid: _validDoubleText(maxBs2Rate,
                                                max: 1))),
                                    row2(
                                        intField('min_zs_cnt', 'min_zs_cnt',
                                            minZsCnt, (v) => minZsCnt = v),
                                        intField(
                                            'bsp3a_max_zs_cnt',
                                            'bsp3a_max_zs_cnt',
                                            bsp3aMaxZsCnt,
                                            (v) => bsp3aMaxZsCnt = v,
                                            min: 1)),
                                    row2(
                                        textField(
                                            'max_bsp2s_lv',
                                            'max_bsp2s_lv',
                                            maxBsp2sLv,
                                            (v) => maxBsp2sLv = v,
                                            helper: '空值表示 None',
                                            valid: _validOptionalIntText(
                                                maxBsp2sLv)),
                                        dropdownSetting(
                                            'macd_algo',
                                            'macd_algo',
                                            macdAlgo,
                                            _macdAlgoValues,
                                            (v) => setSheetState(() =>
                                                macdAlgo = v ?? macdAlgo))),
                                    boolTile(
                                        'bsp1_only_multibi_zs',
                                        'bsp1_only_multibi_zs',
                                        bsp1OnlyMultibiZs,
                                        (v) => bsp1OnlyMultibiZs = v),
                                    boolTile('bs1_peak', 'bs1_peak', bs1Peak,
                                        (v) => bs1Peak = v),
                                    boolTile('bsp2_follow_1', 'bsp2_follow_1',
                                        bsp2Follow1, (v) => bsp2Follow1 = v),
                                    boolTile('bsp3_follow_1', 'bsp3_follow_1',
                                        bsp3Follow1, (v) => bsp3Follow1 = v),
                                    boolTile('bsp3_peak', 'bsp3_peak', bsp3Peak,
                                        (v) => bsp3Peak = v),
                                    boolTile('bsp2s_follow_2', 'bsp2s_follow_2',
                                        bsp2sFollow2, (v) => bsp2sFollow2 = v),
                                    boolTile('strict_bsp3', 'strict_bsp3',
                                        strictBsp3, (v) => strictBsp3 = v),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                onPressed: _loading ? null : applyAndReload,
                                icon: _loading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.refresh),
                                label: const Text('应用并重新计算'))),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _dropdown(String label, String value, List<String> values,
      ValueChanged<String?>? onChanged,
      {Map<String, String> labels = const {}}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values
          .map((v) => DropdownMenuItem(value: v, child: Text(labels[v] ?? v)))
          .toList(),
      onChanged: _loading ? null : onChanged,
    );
  }

  Widget _settingToneLegend() {
    Widget item(_SettingTone tone, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: _toneColor(tone), shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          item(_SettingTone.defaultValue, '绿色：默认'),
          item(_SettingTone.changed, '黄色：非默认'),
          item(_SettingTone.invalid, '红色：非法值'),
        ],
      ),
    );
  }

  InputDecoration _settingDecoration(String label, _SettingTone tone,
      {String? helper}) {
    final color = _toneColor(tone);
    final helperText = tone == _SettingTone.invalid
        ? (helper == null || helper.isEmpty ? '非法值' : '$helper；非法值')
        : helper;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      helperText: helperText,
      helperStyle: TextStyle(
          color: tone == _SettingTone.invalid ? color : Colors.white54,
          fontSize: 11),
      border: _toneBorder(tone),
      enabledBorder: _toneBorder(tone),
      focusedBorder: _toneBorder(tone, width: 2),
      suffixIcon: Icon(Icons.circle, color: color, size: 11),
    );
  }

  OutlineInputBorder _toneBorder(_SettingTone tone, {double width = 1.2}) {
    return OutlineInputBorder(
        borderSide: BorderSide(
            color: _toneColor(tone).withValues(alpha: 0.86), width: width));
  }

  _SettingTone _settingTone(String key, Object? value, {bool valid = true}) {
    if (!valid) return _SettingTone.invalid;
    final defaultValue = _settingDefaults[key];
    return value == defaultValue
        ? _SettingTone.defaultValue
        : _SettingTone.changed;
  }

  Color _toneColor(_SettingTone tone) {
    switch (tone) {
      case _SettingTone.defaultValue:
        return const Color(0xFF66BB6A);
      case _SettingTone.changed:
        return const Color(0xFFFFD54F);
      case _SettingTone.invalid:
        return const Color(0xFFEF5350);
    }
  }

  String _toneText(_SettingTone tone) {
    switch (tone) {
      case _SettingTone.defaultValue:
        return '默认';
      case _SettingTone.changed:
        return '非默认';
      case _SettingTone.invalid:
        return '非法值';
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  Widget _dateTile(
      String title, DateTime value, bool enabled, VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: title,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_month)),
          child: Text(_fmtDate(value)),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate(DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      appBar: AppBar(
        toolbarHeight: 40,
        elevation: 0,
        backgroundColor: const Color(0xFF131722),
        title: Text(_status,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white54)),
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
                  if (_isStepMode)
                    ReplayControllerBar(
                      enabled: _hasBars,
                      playing: _playing,
                      cursor: _cursor,
                      total: _stepTotal,
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

  Widget _buildLeftToolbar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: _toolbarExpanded ? 48 : 28,
      color: const Color(0xFF131722),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _toolbarExpanded = !_toolbarExpanded),
              child: SizedBox(
                  width: _toolbarExpanded ? 36 : 24,
                  height: 30,
                  child: Center(
                      child: Text(_toolbarExpanded ? '<-' : '->',
                          style: const TextStyle(color: Colors.white70)))),
            ),
            if (_toolbarExpanded) ...[
              const Divider(height: 12, color: Colors.white12),
              _toolIcon('数据/标的/周期/日期', Icons.search,
                  _loading ? null : _openDataPanel),
              _toolIcon('CChanConfig 设置', Icons.tune,
                  _loading ? null : _openConfigPanel),
              _toolIcon(
                  '本地CSV上传', Icons.upload_file, _loading ? null : _pickCsv),
              _toolIcon(
                  '一次性显示',
                  Icons.fullscreen,
                  _hasBars
                      ? () => setState(() {
                            _mode = 'once';
                            _cursor = _fullSnapshot.rawBars.length;
                            _snapshot = _fullSnapshot;
                          })
                      : null,
                  selected: _mode == 'once'),
              _toolIcon(
                  '严格逐K',
                  Icons.play_circle_outline,
                  _hasBars
                      ? () => setState(() {
                            _mode = 'step';
                            _cursor = 0;
                            _snapshot = _frames.isNotEmpty
                                ? _frames.first
                                : _sliceSnapshot(_fullSnapshot, 0);
                          })
                      : null,
                  selected: _mode == 'step'),
              const Divider(height: 18, color: Colors.white12),
              _toolIcon('显示分型顶底', Icons.trip_origin,
                  _hasFx ? () => setState(() => _showFx = !_showFx) : null,
                  selected: _showFx && _hasFx),
              _toolIcon(
                  '显示分型顶底文字',
                  Icons.title,
                  _hasFx && _showFx
                      ? () => setState(() => _showFxText = !_showFxText)
                      : null,
                  selected: _showFxText && _hasFx && _showFx),
              _toolIcon(
                  '显示分型顶底连线',
                  Icons.timeline,
                  _hasFxLine
                      ? () => setState(() => _showFxLine = !_showFxLine)
                      : null,
                  selected: _showFxLine && _hasFxLine),
              _toolIcon('显示笔', Icons.show_chart,
                  _hasBi ? () => setState(() => _showBi = !_showBi) : null,
                  selected: _showBi && _hasBi),
              _toolIcon(
                  '显示笔端点文字',
                  Icons.text_fields,
                  _hasBi && _showBi
                      ? () => setState(() => _showBiText = !_showBiText)
                      : null,
                  selected: _showBiText && _hasBi && _showBi),
              _toolIcon('显示线段', Icons.multiline_chart,
                  _hasSeg ? () => setState(() => _showSeg = !_showSeg) : null,
                  selected: _showSeg && _hasSeg),
              _toolIcon(
                  '显示线段端点文字',
                  Icons.font_download_outlined,
                  _hasSeg && _showSeg
                      ? () => setState(() => _showSegText = !_showSegText)
                      : null,
                  selected: _showSegText && _hasSeg && _showSeg),
              _toolIcon('显示中枢', Icons.crop_square,
                  _hasZs ? () => setState(() => _showZs = !_showZs) : null,
                  selected: _showZs && _hasZs),
              _toolIcon(
                  '显示笔买卖点',
                  Icons.change_circle,
                  _hasBiBsp
                      ? () => setState(() => _showBiBsp = !_showBiBsp)
                      : null,
                  selected: _showBiBsp && _hasBiBsp),
              _toolIcon(
                  '显示线段买卖点',
                  Icons.timeline,
                  _hasSegBsp
                      ? () => setState(() => _showSegBsp = !_showSegBsp)
                      : null,
                  selected: _showSegBsp && _hasSegBsp),
              _toolIcon(
                  '显示合并K线',
                  Icons.filter_none,
                  _hasMergedBars
                      ? () => setState(() => _showMergedBars = !_showMergedBars)
                      : null,
                  selected: _showMergedBars && _hasMergedBars),
              const Divider(height: 18, color: Colors.white12),
              _toolIcon(
                  '左右放大',
                  Icons.zoom_in,
                  _hasBars
                      ? () => setState(() => _windowSize =
                          (_windowSize - 15).clamp(24, 360).toInt())
                      : null),
              _toolIcon(
                  '左右缩小',
                  Icons.zoom_out,
                  _hasBars
                      ? () => setState(() => _windowSize =
                          (_windowSize + 15).clamp(24, 360).toInt())
                      : null),
              _toolIcon(
                  '上下放大',
                  Icons.keyboard_arrow_up,
                  _hasBars
                      ? () => setState(() => _priceScale =
                          (_priceScale * 1.18).clamp(0.35, 5.0).toDouble())
                      : null),
              _toolIcon(
                  '上下缩小',
                  Icons.keyboard_arrow_down,
                  _hasBars
                      ? () => setState(() => _priceScale =
                          (_priceScale / 1.18).clamp(0.35, 5.0).toDouble())
                      : null),
              _toolIcon(
                  '重置缩放',
                  Icons.center_focus_strong,
                  _hasBars
                      ? () => setState(() {
                            _windowSize = 90;
                            _priceScale = 1.0;
                            _viewEndIndex = null;
                          })
                      : null),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toolIcon(String tooltip, IconData icon, VoidCallback? onPressed,
      {bool selected = false}) {
    return Tooltip(
      message: onPressed == null ? '$tooltip（当前不可用）' : tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        color: selected ? Colors.white : Colors.white60,
        disabledColor: Colors.white24,
        style: IconButton.styleFrom(
            backgroundColor:
                selected ? const Color(0xFF2962FF) : Colors.transparent,
            visualDensity: VisualDensity.compact),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: OriginKlineChart(
            snapshot: _snapshot,
            showFx: _showFx && _hasFx,
            showFxLine: _showFxLine && _hasFxLine,
            showFxText: _showFxText && _hasFx,
            showBi: _showBi && _hasBi,
            showBiText: _showBiText && _hasBi,
            showSeg: _showSeg && _hasSeg,
            showSegText: _showSegText && _hasSeg,
            showZs: _showZs && _hasZs,
            showBiBsp: _showBiBsp && _hasBiBsp,
            showSegBsp: _showSegBsp && _hasSegBsp,
            showMergedBars: _showMergedBars && _hasMergedBars,
            drawingStorageKey: _drawingStorageKey,
            windowSize: _windowSize,
            priceScale: _priceScale,
            viewEndIndex: _viewEndIndex,
            crosshairIndex: _crosshairIndex,
            onCrosshairChanged: (i) => setState(() => _crosshairIndex = i),
            onPanBars: _panChartByBars,
            onWindowSizeChanged: (v) => setState(() => _windowSize = v),
            onPriceScaleChanged: (v) => setState(() => _priceScale = v),
          ),
        ),
      ),
    );
  }

  _Symbol? _parseSymbol(String input) {
    var text = input.trim().toUpperCase();
    if (text.endsWith('.SZ') || text.endsWith('.SH'))
      text = text.substring(0, 6);
    if (text.startsWith('SZ') || text.startsWith('SH'))
      text = text.substring(2);
    if (!RegExp(r'^\d{6}$').hasMatch(text)) return null;
    return _Symbol(
        code: text, market: text.startsWith(RegExp(r'[569]')) ? 'SH' : 'SZ');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  List<String> _csvTokens(String text) =>
      text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  String _toggleCsvToken(String csv, String token, bool selected) {
    final current = _csvTokens(csv).toSet();
    if (selected) {
      current.add(token);
    } else {
      current.remove(token);
    }
    final ordered = [
      for (final item in _bspTypes)
        if (current.contains(item)) item
    ];
    return ordered.isEmpty ? token : ordered.join(',');
  }

  String _normalizeBspTypeText(String text) {
    final current = _csvTokens(text).toSet();
    return [
      for (final item in _bspTypes)
        if (current.contains(item)) item
    ].join(',');
  }

  bool _validBspTypeText(String text) {
    final tokens = _csvTokens(text);
    if (tokens.isEmpty) return false;
    return tokens.toSet().length == tokens.length &&
        tokens.every(_bspTypes.contains);
  }

  bool _validIntListText(String text) {
    return _csvTokens(text).every((token) => int.tryParse(token) != null);
  }

  bool _validDoubleText(String text, {double? max}) {
    final raw = text.trim().toLowerCase();
    if (raw.isEmpty) return false;
    if (raw == 'inf' || raw == 'infinity') return max == null;
    final value = double.tryParse(raw);
    if (value == null) return false;
    return max == null || value <= max;
  }

  bool _validOptionalIntText(String text) {
    final raw = text.trim().toLowerCase();
    return raw.isEmpty ||
        raw == 'none' ||
        raw == 'null' ||
        int.tryParse(raw) != null;
  }

  String get _periodAdjustLabel =>
      '${_periodLabel(_period)} ${_adjustLabel(_adjust)}';

  String _periodLabel(String p) =>
      {
        'MIN1': '1分钟',
        'MIN5': '5分钟',
        'MIN15': '15分钟',
        'MIN30': '30分钟',
        'MIN60': '60分钟',
        'DAILY': '日线',
        'WEEKLY': '周线',
        'MONTHLY': '月线'
      }[p] ??
      p;

  String _adjustLabel(String a) =>
      {'QFQ': '前复权', 'HFQ': '后复权', 'NONE': '不复权'}[a] ?? a;

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _safeStoragePart(String raw) =>
      raw.replaceAll(RegExp('[^a-zA-Z0-9._-]+'), '_');
}

class _Symbol {
  final String code;
  final String market;

  const _Symbol({required this.code, required this.market});
}
