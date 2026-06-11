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

  static MultiLevelChanSnapshot? parseFrame(
    Object? rawFrame, {
    required ChanSnapshotParser parseSingleLevelSnapshot,
    Object? baseLevels,
  }) {
    final base = baseLevels is Map ? Map<String, dynamic>.from(baseLevels) : const <String, dynamic>{};
    if (rawFrame is Map<String, dynamic>) {
      return parseSnapshot(
        _inflateCompactFrame(rawFrame, base),
        parseSingleLevelSnapshot: parseSingleLevelSnapshot,
      );
    }
    if (rawFrame is Map) {
      return parseSnapshot(
        _inflateCompactFrame(Map<String, dynamic>.from(rawFrame), base),
        parseSingleLevelSnapshot: parseSingleLevelSnapshot,
      );
    }
    return null;
  }

  static List<MultiLevelChanSnapshot> parseFrames(
    Object? rawFrames, {
    required ChanSnapshotParser parseSingleLevelSnapshot,
    Object? baseLevels,
  }) {
    if (rawFrames is! List) return const [];
    final frames = <MultiLevelChanSnapshot>[];
    for (final frame in rawFrames) {
      final parsed = parseFrame(
        frame,
        baseLevels: baseLevels,
        parseSingleLevelSnapshot: parseSingleLevelSnapshot,
      );
      if (parsed != null) frames.add(parsed);
    }
    return frames;
  }

  static Map<String, dynamic> _inflateCompactFrame(
    Map<String, dynamic> frame,
    Map<String, dynamic> baseLevels,
  ) {
    final rawLevels = frame['levels'];
    if (rawLevels is! Map || baseLevels.isEmpty) return frame;
    final nextFrame = Map<String, dynamic>.from(frame);
    final nextLevels = <String, dynamic>{};
    for (final entry in rawLevels.entries) {
      final level = '${entry.key}'.trim().toUpperCase();
      final rawLevelPayload = entry.value;
      if (rawLevelPayload is! Map) {
        nextLevels[entry.key] = rawLevelPayload;
        continue;
      }
      final levelPayload = Map<String, dynamic>.from(rawLevelPayload);
      final basePayloadRaw = baseLevels[level] ?? baseLevels[entry.key];
      final basePayload = basePayloadRaw is Map ? Map<String, dynamic>.from(basePayloadRaw) : const <String, dynamic>{};
      final visibleCount = _parseVisibleCount(levelPayload);
      final frameBars = levelPayload['bars'];
      if (frameBars is! List && visibleCount != null) {
        final baseBars = basePayload['bars'];
        if (baseBars is List) {
          levelPayload['bars'] = baseBars.take(visibleCount).toList(growable: false);
        }
      }
      final frameIndicators = levelPayload['indicators'];
      if (frameIndicators is! Map && visibleCount != null) {
        final baseIndicators = basePayload['indicators'];
        if (baseIndicators is Map) {
          levelPayload['indicators'] = _clipIndicators(baseIndicators, visibleCount);
        }
      }
      nextLevels[entry.key] = levelPayload;
    }
    nextFrame['levels'] = nextLevels;
    return nextFrame;
  }

  static int? _parseVisibleCount(Map<String, dynamic> levelPayload) {
    final raw = levelPayload['visible_count'] ?? levelPayload['visibleCount'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw');
  }

  static Map<String, dynamic> _clipIndicators(Map raw, int visibleCount) {
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = '${entry.key}';
      final value = entry.value;
      if (value is List) {
        result[key] = _clipIndicatorList(value, visibleCount);
      } else if (value is Map) {
        final nested = <String, dynamic>{};
        for (final nestedEntry in value.entries) {
          final nestedValue = nestedEntry.value;
          nested['${nestedEntry.key}'] = nestedValue is List
              ? _clipIndicatorList(nestedValue, visibleCount)
              : nestedValue;
        }
        result[key] = nested;
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  static List<dynamic> _clipIndicatorList(List rows, int visibleCount) {
    final result = <dynamic>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rawIndex = row is Map ? _int(row['raw_index'] ?? row['rawIndex']) ?? i : i;
      if (rawIndex < visibleCount) result.add(row);
    }
    return result;
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

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
