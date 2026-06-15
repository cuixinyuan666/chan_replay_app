enum RecursiveSegDirection { up, down, unknown }

class RecursiveSEG {
  final int layer;
  final int inputLayer;
  final int index;
  final int? startParentIndex;
  final int? endParentIndex;
  final int startRawIndex;
  final int endRawIndex;
  final double startPrice;
  final double endPrice;
  final String? startTimeText;
  final String? endTimeText;
  final RecursiveSegDirection direction;
  final bool isSure;

  const RecursiveSEG({
    required this.layer,
    required this.inputLayer,
    required this.index,
    required this.startRawIndex,
    required this.endRawIndex,
    required this.startPrice,
    required this.endPrice,
    required this.direction,
    required this.isSure,
    this.startParentIndex,
    this.endParentIndex,
    this.startTimeText,
    this.endTimeText,
  });

  bool get isUp => direction == RecursiveSegDirection.up;
  bool get isDown => direction == RecursiveSegDirection.down;
  bool get isVisibleRangeValid => endRawIndex >= startRawIndex;
}
