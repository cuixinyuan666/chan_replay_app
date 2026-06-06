import 'bi.dart';

enum SegDirection { up, down }

class SEG {
  final int index;
  final BI startBi;
  final BI endBi;
  final SegDirection direction;
  final bool isSure;
  final String reason;
  final List<BI> biList;

  const SEG({
    required this.index,
    required this.startBi,
    required this.endBi,
    required this.direction,
    required this.isSure,
    required this.reason,
    required this.biList,
  });

  int get startBiIndex => startBi.index;
  int get endBiIndex => endBi.index;
  int get startRawIndex => startBi.startRawIndex;
  int get endRawIndex => endBi.endRawIndex;
  double get startPrice => startBi.startPrice;
  double get endPrice => endBi.endPrice;
  bool get isUp => direction == SegDirection.up;
  bool get isDown => direction == SegDirection.down;
  int get biCount => endBiIndex - startBiIndex + 1;

  double get high {
    if (biList.isEmpty) return startPrice > endPrice ? startPrice : endPrice;
    return biList.map((e) => e.high).reduce((a, b) => a >= b ? a : b);
  }

  double get low {
    if (biList.isEmpty) return startPrice < endPrice ? startPrice : endPrice;
    return biList.map((e) => e.low).reduce((a, b) => a <= b ? a : b);
  }
}
