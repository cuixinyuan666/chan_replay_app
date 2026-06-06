class ZS {
  final int index;
  final int startBiIndex;
  final int endBiIndex;
  final int startRawIndex;
  final int endRawIndex;
  final double zg; // 中枢上沿：三笔低高点中的最低高点
  final double zd; // 中枢下沿：三笔高低点中的最高低点
  final double gg; // 参与笔最高点
  final double dd; // 参与笔最低点
  final bool confirmed;

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
  });
}
