import '../core/models/chan_snapshot.dart';
import '../core/models/level_relation.dart';
import '../core/models/multi_level_chan_snapshot.dart';

typedef ChanSnapshotParser = ChanSnapshot Function(Map<String, dynamic> data);

class MultiLevelChanAnalysisParser {
  const MultiLevelChanAnalysisParser._();

  static MultiLevelChanSnapshot? parseSnapshot(
    Map<String, dynamic> data, {
    required ChanSnapshotParser parseSingleLevelSnapshot,
  }) {
    final rawLevels = data['levels'];
    if (rawLevels is! Map) return null;

    final snapshots = <String, ChanSnapshot>{};
    for (final entry in rawLevels.entries) {
      final level = '${entry.key}'.trim().toUpperCase();
      final value = entry.value;
      if (level.isEmpty || value is! Map) continue;
      snapshots[level] = parseSingleLevelSnapshot(
        Map<String, dynamic>.from(value),
      );
    }
    if (snapshots.isEmpty) return null;

    final meta = data['meta'] is Map
        ? Map<String, dynamic>.from(data['meta'] as Map)
        : const <String, dynamic>{};
    final levels = _parseLevelOrder(data, meta, snapshots);
    final mainLevel = _parseMainLevel(data, meta, levels, snapshots);

    return MultiLevelChanSnapshot(
      mainLevel: mainLevel,
      levels: levels,
      snapshots: snapshots,
      relations: parseRelations(data['relations']),
      meta: meta,
    );
  }

  static List<MultiLevelChanSnapshot> parseFrames(
    Object? rawFrames, {
    required ChanSnapshotParser parseSingleLevelSnapshot,
  }) {
    if (rawFrames is! List) return const [];
    final frames = <MultiLevelChanSnapshot>[];
    for (final frame in rawFrames) {
      if (frame is Map<String, dynamic>) {
        final parsed = parseSnapshot(
          frame,
          parseSingleLevelSnapshot: parseSingleLevelSnapshot,
        );
        if (parsed != null) frames.add(parsed);
      } else if (frame is Map) {
        final parsed = parseSnapshot(
          Map<String, dynamic>.from(frame),
          parseSingleLevelSnapshot: parseSingleLevelSnapshot,
        );
        if (parsed != null) frames.add(parsed);
      }
    }
    return frames;
  }

  static List<LevelRelation> parseRelations(Object? rawRelations) {
    if (rawRelations is! List) return const [];
    final relations = <LevelRelation>[];
    for (final item in rawRelations) {
      if (item is Map<String, dynamic>) {
        relations.add(LevelRelation.fromJson(item));
      } else if (item is Map) {
        relations.add(LevelRelation.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return relations;
  }

  static List<String> _parseLevelOrder(
    Map<String, dynamic> data,
    Map<String, dynamic> meta,
    Map<String, ChanSnapshot> snapshots,
  ) {
    final rawLevels = meta['levels'] ?? data['level_order'] ?? data['levelOrder'];
    if (rawLevels is List) {
      final parsed = [
        for (final item in rawLevels)
          if ('$item'.trim().isNotEmpty) '$item'.trim().toUpperCase(),
      ];
      if (parsed.isNotEmpty) return parsed;
    }
    return snapshots.keys.toList(growable: false);
  }

  static String _parseMainLevel(
    Map<String, dynamic> data,
    Map<String, dynamic> meta,
    List<String> levels,
    Map<String, ChanSnapshot> snapshots,
  ) {
    final raw = '${data['main_level'] ?? data['mainLevel'] ?? meta['main_level'] ?? meta['mainLevel'] ?? ''}'
        .trim()
        .toUpperCase();
    if (raw.isNotEmpty && snapshots.containsKey(raw)) return raw;
    return levels.isNotEmpty ? levels.first : snapshots.keys.first;
  }
}
