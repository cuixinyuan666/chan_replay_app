import 'chan_snapshot.dart';
import 'level_relation.dart';

class MultiLevelChanSnapshot {
  final String mainLevel;
  final List<String> levels;
  final Map<String, ChanSnapshot> snapshots;
  final List<LevelRelation> relations;
  final Map<String, dynamic> meta;

  const MultiLevelChanSnapshot({
    required this.mainLevel,
    required this.levels,
    required this.snapshots,
    this.relations = const [],
    this.meta = const {},
  });

  factory MultiLevelChanSnapshot.empty() => const MultiLevelChanSnapshot(
        mainLevel: '',
        levels: [],
        snapshots: {},
        relations: [],
        meta: {},
      );

  bool get isEmpty => levels.isEmpty || snapshots.isEmpty;
  bool get isNotEmpty => !isEmpty;

  ChanSnapshot? of(String level) => snapshots[level];

  ChanSnapshot? get mainSnapshot =>
      mainLevel.isEmpty ? null : snapshots[mainLevel];

  String get safeActiveLevel =>
      snapshots.containsKey(mainLevel) ? mainLevel : levels.firstOrNull ?? '';

  List<LevelRelation> relationsFromParent({
    required String parentLevel,
    required String childLevel,
    required int parentRawIndex,
  }) {
    return [
      for (final relation in relations)
        if (relation.parentLevel == parentLevel &&
            relation.childLevel == childLevel &&
            relation.parentRawIndex == parentRawIndex)
          relation,
    ];
  }

  List<LevelRelation> relationsForParentRange({
    required String parentLevel,
    required String childLevel,
    required int startParentRawIndex,
    required int endParentRawIndex,
  }) {
    return [
      for (final relation in relations)
        if (relation.parentLevel == parentLevel &&
            relation.childLevel == childLevel &&
            relation.parentRawIndex >= startParentRawIndex &&
            relation.parentRawIndex <= endParentRawIndex)
          relation,
    ];
  }
}
