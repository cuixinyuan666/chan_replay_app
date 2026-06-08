enum BiAlgo { normal, fx }

enum BiFxCheck { strict, loss, half, totally }

enum SegAlgo { chan, onePlusOne, breakAlgo }

enum LeftSegMethod { peak, all }

enum ZsCombineMode { zs, peak }

enum ZsAlgo { normal, overSeg, auto }

class ChanBiConfig {
  /// 对齐 chan.py 的 bi_algo。normal 需要满足成笔跨度；fx 只按分型成笔。
  final BiAlgo biAlgo;

  /// 对齐 chan.py 的 bi_strict。strict 默认成笔跨度 >= 4。
  final bool isStrict;

  /// 对齐 chan.py 的 bi_fx_check：strict/loss/half/totally。
  final BiFxCheck fxCheck;

  /// 对齐 chan.py 的 gap_as_kl。当前 Flutter 引擎尚未实现跳空计数，先保留配置位。
  final bool gapAsKl;

  /// 对齐 chan.py 的 bi_end_is_peak。
  final bool endIsPeak;

  /// 对齐 chan.py 的 bi_allow_sub_peak。当前 Flutter 引擎尚未实现次高低点更新，先保留配置位。
  final bool allowSubPeak;

  /// Flutter 端可调跨度；null 时完全按 chan.py：strict=4，非 strict=3。
  final int? minKlcSpan;

  const ChanBiConfig({
    this.biAlgo = BiAlgo.normal,
    this.isStrict = true,
    this.fxCheck = BiFxCheck.strict,
    this.gapAsKl = false,
    this.endIsPeak = true,
    this.allowSubPeak = true,
    this.minKlcSpan,
  });

  int get effectiveMinKlcSpan => minKlcSpan ?? (isStrict ? 4 : 3);

  ChanBiConfig copyWith({
    BiAlgo? biAlgo,
    bool? isStrict,
    BiFxCheck? fxCheck,
    bool? gapAsKl,
    bool? endIsPeak,
    bool? allowSubPeak,
    int? minKlcSpan,
    bool clearMinKlcSpan = false,
  }) {
    return ChanBiConfig(
      biAlgo: biAlgo ?? this.biAlgo,
      isStrict: isStrict ?? this.isStrict,
      fxCheck: fxCheck ?? this.fxCheck,
      gapAsKl: gapAsKl ?? this.gapAsKl,
      endIsPeak: endIsPeak ?? this.endIsPeak,
      allowSubPeak: allowSubPeak ?? this.allowSubPeak,
      minKlcSpan: clearMinKlcSpan ? null : minKlcSpan ?? this.minKlcSpan,
    );
  }

  factory ChanBiConfig.fromChanPyDefaults() => const ChanBiConfig(
        biAlgo: BiAlgo.normal,
        isStrict: true,
        fxCheck: BiFxCheck.strict,
        gapAsKl: false,
        endIsPeak: true,
        allowSubPeak: true,
        minKlcSpan: null,
      );
}

class ChanSegConfig {
  /// 对齐 chan.py 的 seg_algo。
  final SegAlgo segAlgo;

  /// 对齐 chan.py 的 left_seg_method。
  final LeftSegMethod leftMethod;

  const ChanSegConfig({
    this.segAlgo = SegAlgo.chan,
    this.leftMethod = LeftSegMethod.peak,
  });

  ChanSegConfig copyWith({
    SegAlgo? segAlgo,
    LeftSegMethod? leftMethod,
  }) {
    return ChanSegConfig(
      segAlgo: segAlgo ?? this.segAlgo,
      leftMethod: leftMethod ?? this.leftMethod,
    );
  }

  factory ChanSegConfig.fromChanPyDefaults() => const ChanSegConfig(
        segAlgo: SegAlgo.chan,
        leftMethod: LeftSegMethod.peak,
      );
}

class ChanZsConfig {
  /// 对齐 chan.py 的 zs_combine。
  final bool needCombine;

  /// 对齐 chan.py 的 zs_combine_mode。
  final ZsCombineMode combineMode;

  /// 对齐 chan.py 的 one_bi_zs。
  final bool oneBiZs;

  /// 对齐 chan.py 的 zs_algo。
  final ZsAlgo zsAlgo;

  /// 前端显示过滤：true 时只输出确认中枢。
  /// chan.py 默认不会在 zs_list 层过滤未确认中枢，因此 chanPyDefault 使用 false。
  final bool onlyConfirmed;

  const ChanZsConfig({
    this.needCombine = true,
    this.combineMode = ZsCombineMode.zs,
    this.oneBiZs = false,
    this.zsAlgo = ZsAlgo.normal,
    this.onlyConfirmed = false,
  });

  ChanZsConfig copyWith({
    bool? needCombine,
    ZsCombineMode? combineMode,
    bool? oneBiZs,
    ZsAlgo? zsAlgo,
    bool? onlyConfirmed,
  }) {
    return ChanZsConfig(
      needCombine: needCombine ?? this.needCombine,
      combineMode: combineMode ?? this.combineMode,
      oneBiZs: oneBiZs ?? this.oneBiZs,
      zsAlgo: zsAlgo ?? this.zsAlgo,
      onlyConfirmed: onlyConfirmed ?? this.onlyConfirmed,
    );
  }

  factory ChanZsConfig.fromChanPyDefaults() => const ChanZsConfig(
        needCombine: true,
        combineMode: ZsCombineMode.zs,
        oneBiZs: false,
        zsAlgo: ZsAlgo.normal,
        onlyConfirmed: false,
      );
}

class ChanConfig {
  /// 是否处理包含关系。chan.py 的 KLine_List 默认会做合并处理。
  final bool enableInclude;

  final ChanBiConfig bi;
  final ChanSegConfig seg;
  final ChanZsConfig zs;

  /// 对齐 chan.py CChanConfig 的回放/校验类配置。
  final bool triggerStep;
  final int skipStep;
  final bool klDataCheck;
  final int maxKlMisalignCnt;
  final int maxKlInconsistentCnt;
  final bool autoSkipIllegalSubLv;
  final bool printWarning;
  final bool printErrTime;

  /// 指标配置入口；当前 Flutter 引擎暂不计算 MACD/BOLL/RSI/KDJ，仅保留配置结构。
  final List<int> meanMetrics;
  final List<int> trendMetrics;
  final int bollN;
  final bool calDemark;
  final bool calRsi;
  final bool calKdj;
  final int rsiCycle;
  final int kdjCycle;

  const ChanConfig({
    this.enableInclude = true,
    this.bi = const ChanBiConfig(),
    this.seg = const ChanSegConfig(),
    this.zs = const ChanZsConfig(),
    this.triggerStep = false,
    this.skipStep = 0,
    this.klDataCheck = true,
    this.maxKlMisalignCnt = 2,
    this.maxKlInconsistentCnt = 5,
    this.autoSkipIllegalSubLv = false,
    this.printWarning = true,
    this.printErrTime = true,
    this.meanMetrics = const [],
    this.trendMetrics = const [],
    this.bollN = 20,
    this.calDemark = false,
    this.calRsi = false,
    this.calKdj = false,
    this.rsiCycle = 14,
    this.kdjCycle = 9,
  });

  factory ChanConfig.chanPyDefault() => ChanConfig(
        enableInclude: true,
        bi: ChanBiConfig.fromChanPyDefaults(),
        seg: ChanSegConfig.fromChanPyDefaults(),
        zs: ChanZsConfig.fromChanPyDefaults(),
        triggerStep: false,
        skipStep: 0,
        klDataCheck: true,
        maxKlMisalignCnt: 2,
        maxKlInconsistentCnt: 5,
        autoSkipIllegalSubLv: false,
        printWarning: true,
        printErrTime: true,
        meanMetrics: const [],
        trendMetrics: const [],
        bollN: 20,
        calDemark: false,
        calRsi: false,
        calKdj: false,
        rsiCycle: 14,
        kdjCycle: 9,
      );

  /// 兼容旧 UI 字段：严格分型/严格成笔。
  bool get strictFx => bi.isStrict;

  /// 兼容旧 UI 字段：成笔跨度。
  int get minKCountForBi => bi.effectiveMinKlcSpan;

  /// 兼容旧 UI 字段。
  bool get allowOneBiZs => zs.oneBiZs;

  /// 跨段中枢映射到 zs_algo != normal。
  bool get allowCrossSegZs => zs.zsAlgo != ZsAlgo.normal;

  /// 兼容旧 UI 字段。
  bool get onlyConfirmedZs => zs.onlyConfirmed;

  ChanConfig copyWith({
    bool? enableInclude,
    ChanBiConfig? bi,
    ChanSegConfig? seg,
    ChanZsConfig? zs,
    bool? triggerStep,
    int? skipStep,
    bool? klDataCheck,
    int? maxKlMisalignCnt,
    int? maxKlInconsistentCnt,
    bool? autoSkipIllegalSubLv,
    bool? printWarning,
    bool? printErrTime,
    List<int>? meanMetrics,
    List<int>? trendMetrics,
    int? bollN,
    bool? calDemark,
    bool? calRsi,
    bool? calKdj,
    int? rsiCycle,
    int? kdjCycle,
    bool? strictFx,
    int? minKCountForBi,
    bool? allowOneBiZs,
    bool? allowCrossSegZs,
    bool? onlyConfirmedZs,
  }) {
    final nextBi = (bi ?? this.bi).copyWith(
      isStrict: strictFx,
      minKlcSpan: minKCountForBi,
    );
    final baseZs = zs ?? this.zs;
    final nextZs = baseZs.copyWith(
      oneBiZs: allowOneBiZs,
      zsAlgo: allowCrossSegZs == null
          ? baseZs.zsAlgo
          : allowCrossSegZs
              ? ZsAlgo.overSeg
              : ZsAlgo.normal,
      onlyConfirmed: onlyConfirmedZs,
    );
    return ChanConfig(
      enableInclude: enableInclude ?? this.enableInclude,
      bi: nextBi,
      seg: seg ?? this.seg,
      zs: nextZs,
      triggerStep: triggerStep ?? this.triggerStep,
      skipStep: skipStep ?? this.skipStep,
      klDataCheck: klDataCheck ?? this.klDataCheck,
      maxKlMisalignCnt: maxKlMisalignCnt ?? this.maxKlMisalignCnt,
      maxKlInconsistentCnt: maxKlInconsistentCnt ?? this.maxKlInconsistentCnt,
      autoSkipIllegalSubLv: autoSkipIllegalSubLv ?? this.autoSkipIllegalSubLv,
      printWarning: printWarning ?? this.printWarning,
      printErrTime: printErrTime ?? this.printErrTime,
      meanMetrics: meanMetrics ?? this.meanMetrics,
      trendMetrics: trendMetrics ?? this.trendMetrics,
      bollN: bollN ?? this.bollN,
      calDemark: calDemark ?? this.calDemark,
      calRsi: calRsi ?? this.calRsi,
      calKdj: calKdj ?? this.calKdj,
      rsiCycle: rsiCycle ?? this.rsiCycle,
      kdjCycle: kdjCycle ?? this.kdjCycle,
    );
  }
}
