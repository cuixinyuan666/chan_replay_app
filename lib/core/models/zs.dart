class ZS {
  final int index;
  final int startBiIndex;
  final int endBiIndex;
  final int startRawIndex;
  final int endRawIndex;
  final double zg; // 中枢上沿：参与笔高点中的最低高点
  final double zd; // 中枢下沿：参与笔低点中的最高低点
  final double gg; // 参与笔最高点
  final double dd; // 参与笔最低点
  final bool confirmed;

  /// 线段感知字段。normal 模式下同一个中枢应当限制在同一线段内。
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
    this.startSegIndex,
    this.endSegIndex,
  });

  bool get isCrossSeg =>
      startSegIndex != null && endSegIndex != null && startSegIndex != endSegIndex;
}
