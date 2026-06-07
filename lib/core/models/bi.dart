import 'fx.dart';

enum BiDirection { up, down }

class BI {
  final int index;
  final FX start;
  final FX end;
  final BiDirection direction;

  /// 对齐 Vespa/chan.py 的 pre / next 引用语义。
  /// Dart 端使用索引引用，避免 BI / SEG 对象循环引用造成状态难以维护。
  final int? prevIndex;
  final int? nextIndex;

  /// 对齐 Vespa/chan.py 的 parent_seg / seg_idx 语义。
  final int? parentSegIndex;
  final BiDirection? parentSegDirection;
  final bool? parentSegIsSure;
  final int? parentSegStartBiIndex;
  final int? parentSegEndBiIndex;

  /// 对齐 Vespa CBi.is_sure。当前笔由已确认分型生成，默认视为确认。
  final bool isSure;

  const BI({
    required this.index,
    required this.start,
    required this.end,
    required this.direction,
    this.prevIndex,
    this.nextIndex,
    this.parentSegIndex,
    this.parentSegDirection,
    this.parentSegIsSure,
    this.parentSegStartBiIndex,
    this.parentSegEndBiIndex,
    this.isSure = true,
  });

  int get startRawIndex => start.rawIndex;
  int get endRawIndex => end.rawIndex;
  double get startPrice => start.price;
  double get endPrice => end.price;
  double get high => startPrice > endPrice ? startPrice : endPrice;
  double get low => startPrice < endPrice ? startPrice : endPrice;
  bool get isUp => direction == BiDirection.up;
  bool get isDown => direction == BiDirection.down;

  int? get segIdx => parentSegIndex;
  bool get hasPrev => prevIndex != null;
  bool get hasNext => nextIndex != null;
  bool get hasParentSeg => parentSegIndex != null;
  bool get parentSegIsUp => parentSegDirection == BiDirection.up;
  bool get parentSegIsDown => parentSegDirection == BiDirection.down;

  BI copyWith({
    int? prevIndex,
    bool clearPrevIndex = false,
    int? nextIndex,
    bool clearNextIndex = false,
    int? parentSegIndex,
    bool clearParentSegIndex = false,
    BiDirection? parentSegDirection,
    bool clearParentSegDirection = false,
    bool? parentSegIsSure,
    bool clearParentSegIsSure = false,
    int? parentSegStartBiIndex,
    bool clearParentSegStartBiIndex = false,
    int? parentSegEndBiIndex,
    bool clearParentSegEndBiIndex = false,
    bool? isSure,
  }) {
    return BI(
      index: index,
      start: start,
      end: end,
      direction: direction,
      prevIndex: clearPrevIndex ? null : prevIndex ?? this.prevIndex,
      nextIndex: clearNextIndex ? null : nextIndex ?? this.nextIndex,
      parentSegIndex: clearParentSegIndex
          ? null
          : parentSegIndex ?? this.parentSegIndex,
      parentSegDirection: clearParentSegDirection
          ? null
          : parentSegDirection ?? this.parentSegDirection,
      parentSegIsSure: clearParentSegIsSure
          ? null
          : parentSegIsSure ?? this.parentSegIsSure,
      parentSegStartBiIndex: clearParentSegStartBiIndex
          ? null
          : parentSegStartBiIndex ?? this.parentSegStartBiIndex,
      parentSegEndBiIndex: clearParentSegEndBiIndex
          ? null
          : parentSegEndBiIndex ?? this.parentSegEndBiIndex,
      isSure: isSure ?? this.isSure,
    );
  }
}
