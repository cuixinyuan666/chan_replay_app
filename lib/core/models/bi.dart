import 'fx.dart';

enum BiDirection { up, down }

class BI {
  final int index;
  final FX start;
  final FX end;
  final BiDirection direction;

  const BI({
    required this.index,
    required this.start,
    required this.end,
    required this.direction,
  });

  int get startRawIndex => start.rawIndex;
  int get endRawIndex => end.rawIndex;
  double get startPrice => start.price;
  double get endPrice => end.price;
  double get high => startPrice > endPrice ? startPrice : endPrice;
  double get low => startPrice < endPrice ? startPrice : endPrice;
  bool get isUp => direction == BiDirection.up;
  bool get isDown => direction == BiDirection.down;
}
