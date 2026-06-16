import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/analysis/chip_distribution.dart';
import '../../core/models/chan_snapshot.dart';
import '../../core/models/raw_bar.dart';
import '../../data/easy_tdx_kline_source.dart';
import 's13_chip_distribution_store.dart';

/// S13 chip distribution controller.
///
/// It no longer paints the chip bars as a sibling Stack overlay. Instead it:
/// - lazily calls `/api/tdx/kline` after the user enables the chip layer;
/// - requests a very large easy-tdx count ending at the current displayed K so
///   the effective range is first easy-tdx-available/listing bar -> cutoff bar;
/// - prefers explicit S13 request context when provided, and falls back to the
///   current OriginKlineChart context for backward-compatible page calls;
/// - publishes the calculated result to [S13ChipDistributionStore];
/// - `RecursiveSegOriginKlineChart` converts the result into locked drawing
///   rectangles and feeds them into `OriginKlineChart`, where they are rendered
///   by the native `_OriginChartPainter` drawing-object path.
class S13ChipDistributionPanel extends StatefulWidget {
  final ChanSnapshot? snapshot;
  final bool enabled;
  final String backendBaseUrl;
  final String symbol;
  final String market;
  final String period;
  final bool isStepMode;
  final int stepIndex;
  final int? crosshairIndex;
  final int? visibleRightIndex;
  final int binCount;
  final double ageDecay;
  final int windowSize;
  final double priceScale;
  final bool showEasyTdxIndicators;
  final int easyTdxSubPanelCount;
  final VoidCallback? onClose;

  const S13ChipDistributionPanel({
    super.key,
    required this.snapshot,
    required this.enabled,
    this.backendBaseUrl = 'app-managed bundled Python',
    this.symbol = '',
    this.market = '',
    this.period = '',
    required this.isStepMode,
    required this.stepIndex,
    required this.crosshairIndex,
    required this.visibleRightIndex,
    this.binCount = 80,
    this.ageDecay = 0.0,
    this.windowSize = 90,
    this.priceScale = 1.0,
    this.showEasyTdxIndicators = false,
    this.easyTdxSubPanelCount = 0,
    this.onClose,
  });

  @override
  State<S13ChipDistributionPanel> createState() => _S13ChipDistributionPanelState();
}

class _S13ChipDistributionPanelState extends State<S13ChipDistributionPanel> {
  String? _loadedKey;
  bool _loading = false;
  Object? _loadError;
  _ChipLoadInfo? _loadInfo;
  final Set<String> _announcedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _scheduleLazyLoad();
  }

  @override
  void didUpdateWidget(covariant S13ChipDistributionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleLazyLoad();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      S13ChipDistributionStore.clearForCurrentContext();
      return const SizedBox.shrink();
    }
    _scheduleLazyLoad();
    return Positioned(
      right: 72,
      top: 36,
      child: IgnorePointer(
        ignoring: false,
        child: _statusBadge(),
      ),
    );
  }

  Widget _statusBadge() {
    final info = _loadInfo;
    final error = _loadError;
    final text = _loading
        ? '筹码：独立拉取上市日起数据…'
        : error != null
            ? '筹码加载失败：$error'
            : info == null
                ? '筹码：等待加载'
                : '筹码 ${_fmtDate(info.startDate)}-${_fmtDate(info.endDate)}';
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC0D1117).withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: error == null ? Colors.white24 : const Color(0xFFFFAB91),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              Icon(
                error == null ? Icons.stacked_bar_chart : Icons.error_outline,
                size: 14,
                color: error == null ? Colors.white70 : const Color(0xFFFFAB91),
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: error == null ? Colors.white70 : const Color(0xFFFFAB91),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (widget.onClose != null) ...<Widget>[
              const SizedBox(width: 4),
              InkWell(
                onTap: widget.onClose,
                child: const Icon(Icons.close, size: 14, color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _scheduleLazyLoad() {
    if (!mounted || !widget.enabled) return;
    scheduleMicrotask(_ensureLazyLoaded);
  }

  Future<void> _ensureLazyLoaded() async {
    if (!mounted || !widget.enabled || _loading) return;
    final rawBars = widget.snapshot?.rawBars ?? const <RawBar>[];
    if (rawBars.isEmpty) return;

    final chartContext = S13ChipDistributionStore.context;
    final explicitSymbol = _normalizeSymbol(widget.symbol);
    final explicitMarket = widget.market.trim().toUpperCase();
    final explicitPeriod = widget.period.trim().toUpperCase();
    final symbol = explicitSymbol.isNotEmpty ? explicitSymbol : (chartContext?.symbol ?? '');
    final market = explicitMarket.isNotEmpty ? explicitMarket : (chartContext?.normalizedMarket ?? '');
    final period = explicitPeriod.isNotEmpty ? explicitPeriod : (chartContext?.period.toUpperCase() ?? '');
    if (symbol.isEmpty) {
      setState(() => _loadError = '缺少当前图表 symbol');
      return;
    }
    if (period.isEmpty) {
      setState(() => _loadError = '缺少当前图表 period');
      return;
    }

    final targetIndex = _targetIndex(rawBars.length);
    final cutoff = rawBars[targetIndex].time;
    final key = <Object?>[
      widget.backendBaseUrl.trim(),
      symbol,
      market,
      period,
      cutoff.toIso8601String(),
      widget.binCount,
      widget.ageDecay,
    ].join('|');
    if (_loadedKey == key) return;

    setState(() {
      _loadedKey = key;
      _loading = true;
      _loadError = null;
      _loadInfo = null;
    });

    final source = EasyTdxKlineSource(baseUrl: widget.backendBaseUrl.trim());
    try {
      final listingBars = await source.loadListingChipBars(
        symbol: symbol,
        market: market.isEmpty ? null : market,
        period: period,
        endDate: cutoff,
        adjust: 'QFQ',
        count: 200000,
      );
      final usableBars = listingBars
          .where((bar) => bar.time != null && !bar.time!.isAfter(cutoff))
          .toList(growable: false);
      if (usableBars.isEmpty) {
        throw StateError('easy-tdx 未返回 $cutoff 之前的可用K线');
      }
      final result = const ChipDistributionEngine().calculate(
        usableBars,
        targetIndex: usableBars.length - 1,
        options: ChipDistributionOptions(
          binCount: widget.binCount,
          lookback: 1000000,
          ageDecay: widget.ageDecay,
        ),
      );
      final info = _ChipLoadInfo(
        startDate: usableBars.first.time!,
        endDate: usableBars.last.time!,
        rawBarCount: usableBars.length,
        sourceText: 'easy-tdx $period K线成交量 / 独立拉取首个可得K',
      );
      if (!mounted || _loadedKey != key) return;
      S13ChipDistributionStore.publish(S13ChipDistributionSpec(
        symbol: symbol,
        market: market.isEmpty ? null : market,
        period: period,
        result: result,
        exactBarCount: usableBars.where((bar) => bar.hasExactChipBins).length,
        targetPolicy: _targetPolicy(),
        startDate: info.startDate,
        endDate: info.endDate,
        rawBarCount: info.rawBarCount,
        sourceText: info.sourceText,
        targetRawIndex: rawBars[targetIndex].index,
      ));
      setState(() {
        _loading = false;
        _loadInfo = info;
      });
      _announceLoadedRange(key, info);
    } catch (e) {
      if (!mounted || _loadedKey != key) return;
      S13ChipDistributionStore.clearForCurrentContext();
      setState(() {
        _loading = false;
        _loadError = e;
      });
    } finally {
      source.close();
    }
  }

  int _targetIndex(int total) {
    if (total <= 0) return 0;
    final raw = widget.isStepMode
        ? widget.stepIndex
        : (widget.crosshairIndex ?? widget.visibleRightIndex ?? total - 1);
    return raw.clamp(0, total - 1).toInt();
  }

  String _targetPolicy() {
    if (widget.isStepMode) return 'step';
    if (widget.crosshairIndex != null) return '十字线';
    if (widget.visibleRightIndex != null) return '右侧K';
    return '末K';
  }

  void _announceLoadedRange(String key, _ChipLoadInfo info) {
    if (!_announcedKeys.add(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('筹码分布加载成功'),
          content: Text(
            '筹码分布的获取区间为: ${_fmtDate(info.startDate)}-${_fmtDate(info.endDate)}\n'
            '数据源: ${info.sourceText}\n'
            'K线数量: ${info.rawBarCount}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    });
  }

  static String _normalizeSymbol(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    return text.split('.').first.trim();
  }

  static String _fmtDate(DateTime value) => value.toIso8601String().split('T').first;
}

class _ChipLoadInfo {
  final DateTime startDate;
  final DateTime endDate;
  final int rawBarCount;
  final String sourceText;

  const _ChipLoadInfo({
    required this.startDate,
    required this.endDate,
    required this.rawBarCount,
    required this.sourceText,
  });
}
