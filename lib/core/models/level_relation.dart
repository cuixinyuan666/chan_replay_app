class LevelRelation {
  final String parentLevel;
  final int parentRawIndex;
  final String childLevel;
  final int childStartRawIndex;
  final int childEndRawIndex;

  const LevelRelation({
    required this.parentLevel,
    required this.parentRawIndex,
    required this.childLevel,
    required this.childStartRawIndex,
    required this.childEndRawIndex,
  });

  factory LevelRelation.fromJson(Map<String, dynamic> json) {
    return LevelRelation(
      parentLevel: '${json['parent_level'] ?? json['parentLevel'] ?? ''}',
      parentRawIndex: _int(json['parent_raw_index'] ?? json['parentRawIndex']),
      childLevel: '${json['child_level'] ?? json['childLevel'] ?? ''}',
      childStartRawIndex:
          _int(json['child_start_raw_index'] ?? json['childStartRawIndex']),
      childEndRawIndex:
          _int(json['child_end_raw_index'] ?? json['childEndRawIndex']),
    );
  }

  Map<String, dynamic> toJson() => {
        'parent_level': parentLevel,
        'parent_raw_index': parentRawIndex,
        'child_level': childLevel,
        'child_start_raw_index': childStartRawIndex,
        'child_end_raw_index': childEndRawIndex,
      };

  bool coversParentRawIndex(int rawIndex) => rawIndex == parentRawIndex;

  bool coversChildRawIndex(int rawIndex) =>
      rawIndex >= childStartRawIndex && rawIndex <= childEndRawIndex;

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }
}
