import 'merged_bar.dart';

enum FxType { top, bottom }

class FX {
  final int index; // 合并K线序号
  final int rawIndex; // 对应原始K线位置，绘图用
  final DateTime time;
  final FxType type;
  final double price;
  final MergedBar left;
  final MergedBar center;
  final MergedBar right;
  final bool confirmed;

  const FX({
    required this.index,
    required this.rawIndex,
    required this.time,
    required this.type,
    required this.price,
    required this.left,
    required this.center,
    required this.right,
    this.confirmed = true,
  });

  bool get isTop => type == FxType.top;
  bool get isBottom => type == FxType.bottom;
}
