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

  bool get isBuy => type.toLowerCase().contains('buy') || type.contains('买') || type.startsWith('b');
  bool get isSell => type.toLowerCase().contains('sell') || type.contains('卖') || type.startsWith('s');
}
