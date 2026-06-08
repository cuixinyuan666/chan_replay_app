class BspPoint {
  final int index;
  final int rawIndex;
  final DateTime? time;
  final double price;
  final String type;
  final String level;
  final int? biIndex;
  final int? segIndex;
  final int? zsIndex;
  final bool confirmed;

  const BspPoint({
    required this.index,
    required this.rawIndex,
    required this.price,
    required this.type,
    this.time,
    this.level = '',
    this.biIndex,
    this.segIndex,
    this.zsIndex,
    this.confirmed = true,
  });

  String get _lowerType => type.toLowerCase();
  bool get isBuy => _lowerType.contains('buy') || type.contains('买') || _lowerType.startsWith('b');
  bool get isSell => _lowerType.contains('sell') || type.contains('卖') || _lowerType.startsWith('s');
}
