class ZS {
  final int index;
  final int startBiIndex;
  final int endBiIndex;
  final int startRawIndex;
  final int endRawIndex;

  /// Vespa/chan.py CZS.high：中枢上沿，参与笔 high 的最小值。
  final double zg;

  /// Vespa/chan.py CZS.low：中枢下沿，参与笔 low 的最大值。
  final double zd;

  /// Vespa/chan.py CZS.peak_high：中枢所涉及笔的最高点。
  final double gg;

  /// Vespa/chan.py CZS.peak_low：中枢所涉及笔的最低点。
  final double dd;

  final bool confirmed;

  /// Vespa/chan.py 中枢进入笔 bi_in。
  final int? biInIndex;

  /// Vespa/chan.py 中枢离开笔 bi_out。
  final int? biOutIndex;

  /// normal 模式下同一个中枢应限制在同一线段内。
  final int? startSegIndex;
  final int? endSegIndex;

  const ZS({
    required this.index,
    required this.startBiIndex,
    required this.endBiIndex,
    required this.startRawIndex,
    required this.endRawIndex,
    required this.zg,
    required this.zd,
    required this.gg,
    required this.dd,
    this.confirmed = true,
    this.biInIndex,
    this.biOutIndex,
    this.startSegIndex,
    this.endSegIndex,
  });

  bool get isCrossSeg =>
      startSegIndex != null && endSegIndex != null && startSegIndex != endSegIndex;

  bool get isOneBiZs => startBiIndex == endBiIndex;
}
