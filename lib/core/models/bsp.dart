class BspPoint {
  final int index;
  final int rawIndex;
  final int? anchorRawIndex;
  final int? recognizedRawIndex;
  final DateTime? time;
  final double price;
  final String type;
  final String level;
  final int? biIndex;
  final int? segIndex;
  final int? zsIndex;
  final bool confirmed;
  final bool? buy;
  final String source;
  final bool derived;

  const BspPoint({
    required this.index,
    required this.rawIndex,
    this.anchorRawIndex,
    this.recognizedRawIndex,
    required this.price,
    required this.type,
    this.time,
    this.level = '',
    this.biIndex,
    this.segIndex,
    this.zsIndex,
    this.confirmed = true,
    this.buy,
    this.source = '',
    this.derived = false,
  });

  String get _lowerType => type.toLowerCase();
  bool get isBuy =>
      buy ??
      (_lowerType.contains('buy') ||
          type.contains('买') ||
          _lowerType.startsWith('b'));
  bool get isSell => buy == null
      ? (_lowerType.contains('sell') ||
          type.contains('卖') ||
          _lowerType.startsWith('s'))
      : !buy!;
}
