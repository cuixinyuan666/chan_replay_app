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

  /// 对齐 Vespa/chan.py 的 pre / next 线段引用语义。
  final int? prevIndex;
  final int? nextIndex;

  const SEG({
    required this.index,
    required this.startBi,
    required this.endBi,
    required this.direction,
    required this.isSure,
    required this.reason,
    required this.biList,
    this.prevIndex,
    this.nextIndex,
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
  bool get hasPrev => prevIndex != null;
  bool get hasNext => nextIndex != null;

  BiDirection get biDirection =>
      direction == SegDirection.up ? BiDirection.up : BiDirection.down;

  double get high {
    if (biList.isEmpty) return startPrice > endPrice ? startPrice : endPrice;
    return biList.map((e) => e.high).reduce((a, b) => a >= b ? a : b);
  }

  double get low {
    if (biList.isEmpty) return startPrice < endPrice ? startPrice : endPrice;
    return biList.map((e) => e.low).reduce((a, b) => a <= b ? a : b);
  }

  SEG copyWith({
    BI? startBi,
    BI? endBi,
    List<BI>? biList,
    int? prevIndex,
    bool clearPrevIndex = false,
    int? nextIndex,
    bool clearNextIndex = false,
  }) {
    return SEG(
      index: index,
      startBi: startBi ?? this.startBi,
      endBi: endBi ?? this.endBi,
      direction: direction,
      isSure: isSure,
      reason: reason,
      biList: biList ?? this.biList,
      prevIndex: clearPrevIndex ? null : prevIndex ?? this.prevIndex,
      nextIndex: clearNextIndex ? null : nextIndex ?? this.nextIndex,
    );
  }
}
