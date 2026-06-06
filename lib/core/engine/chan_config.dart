class ChanConfig {
  /// 是否处理包含关系。
  final bool enableInclude;

  /// 严格分型：顶分型要求高点和低点都抬高；底分型反之。
  final bool strictFx;

  /// 成笔最小合并K线间隔。常见取值 3 / 4 / 5。
  final int minKCountForBi;

  /// 是否允许单笔中枢。v0.1 默认关闭。
  final bool allowOneBiZs;

  /// 是否允许跨线段中枢。v0.1 暂不做线段，默认关闭。
  final bool allowCrossSegZs;

  /// 仅绘制已确认中枢。
  final bool onlyConfirmedZs;

  const ChanConfig({
    this.enableInclude = true,
    this.strictFx = true,
    this.minKCountForBi = 4,
    this.allowOneBiZs = false,
    this.allowCrossSegZs = false,
    this.onlyConfirmedZs = true,
  });

  ChanConfig copyWith({
    bool? enableInclude,
    bool? strictFx,
    int? minKCountForBi,
    bool? allowOneBiZs,
    bool? allowCrossSegZs,
    bool? onlyConfirmedZs,
  }) {
    return ChanConfig(
      enableInclude: enableInclude ?? this.enableInclude,
      strictFx: strictFx ?? this.strictFx,
      minKCountForBi: minKCountForBi ?? this.minKCountForBi,
      allowOneBiZs: allowOneBiZs ?? this.allowOneBiZs,
      allowCrossSegZs: allowCrossSegZs ?? this.allowCrossSegZs,
      onlyConfirmedZs: onlyConfirmedZs ?? this.onlyConfirmedZs,
    );
  }
}
