class RhythmLine {
  final String id;
  final String level;
  final String sourceKind;
  final String sourceLabel;
  final String calcMode;
  final String dir;
  final String displayLabel;
  final String labelLeft;
  final String labelRight;
  final int x1;
  final double y1;
  final int x2;
  final double y2;
  final double threshold;
  final double ratio;
  final double thresholdRatio;
  final int roundCurrent;
  final int roundRef;
  final int layer;

  const RhythmLine({
    required this.id,
    required this.level,
    required this.sourceKind,
    required this.sourceLabel,
    required this.calcMode,
    required this.dir,
    required this.displayLabel,
    required this.labelLeft,
    required this.labelRight,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.threshold,
    required this.ratio,
    required this.thresholdRatio,
    required this.roundCurrent,
    required this.roundRef,
    required this.layer,
  });

  factory RhythmLine.fromJson(Map<String, dynamic> json) {
    final threshold = _num(json['threshold'] ?? json['price'] ?? json['y1']);
    return RhythmLine(
      id: '${json['id'] ?? ''}',
      level: '${json['level'] ?? ''}',
      sourceKind: '${json['source_kind'] ?? json['sourceKind'] ?? ''}',
      sourceLabel: '${json['source_label'] ?? json['sourceLabel'] ?? ''}',
      calcMode: '${json['calc_mode'] ?? json['calcMode'] ?? 'normal'}',
      dir: '${json['dir'] ?? ''}',
      displayLabel: '${json['display_label'] ?? json['displayLabel'] ?? '节奏线'}',
      labelLeft:
          '${json['label_left'] ?? json['labelLeft'] ?? json['display_label'] ?? '节奏线'}',
      labelRight: '${json['label_right'] ?? json['labelRight'] ?? ''}',
      x1: _int(json['x1'] ?? json['start_raw_index'] ?? json['startRawIndex']),
      y1: _num(json['y1'] ?? threshold),
      x2: _int(json['x2'] ?? json['end_raw_index'] ?? json['endRawIndex']),
      y2: _num(json['y2'] ?? threshold),
      threshold: threshold,
      ratio: _num(json['ratio']),
      thresholdRatio:
          _num(json['threshold_ratio'] ?? json['thresholdRatio'] ?? 1.382),
      roundCurrent: _int(json['round_current'] ?? json['roundCurrent']),
      roundRef: _int(json['round_ref'] ?? json['roundRef']),
      layer: _int(json['layer'], fallback: 1),
    );
  }

  bool get isValid => id.isNotEmpty && x1 >= 0 && x2 >= 0;
}

class RhythmHit {
  final String id;
  final String lineId;
  final String level;
  final String sourceKind;
  final int rawIndex;
  final DateTime? time;
  final double price;
  final double threshold;
  final String dir;
  final String displayLabel;
  final String detail;

  const RhythmHit({
    required this.id,
    required this.lineId,
    required this.level,
    required this.sourceKind,
    required this.rawIndex,
    required this.time,
    required this.price,
    required this.threshold,
    required this.dir,
    required this.displayLabel,
    required this.detail,
  });

  factory RhythmHit.fromJson(Map<String, dynamic> json) {
    return RhythmHit(
      id: '${json['id'] ?? ''}',
      lineId: '${json['line_id'] ?? json['lineId'] ?? ''}',
      level: '${json['level'] ?? ''}',
      sourceKind: '${json['source_kind'] ?? json['sourceKind'] ?? ''}',
      rawIndex: _int(json['raw_index'] ?? json['rawIndex']),
      time: _time(json['time']),
      price: _num(json['price']),
      threshold: _num(json['threshold']),
      dir: '${json['dir'] ?? ''}',
      displayLabel:
          '${json['display_label'] ?? json['displayLabel'] ?? '1382'}',
      detail: '${json['detail'] ?? ''}',
    );
  }

  bool get isValid => id.isNotEmpty && rawIndex >= 0;
}

List<RhythmLine> parseRhythmLines(Object? value) {
  if (value is! List) return const [];
  final result = <RhythmLine>[];
  for (final row in value) {
    if (row is Map) {
      final parsed = RhythmLine.fromJson(Map<String, dynamic>.from(row));
      if (parsed.isValid) result.add(parsed);
    }
  }
  return result;
}

List<RhythmHit> parseRhythmHits(Object? value) {
  if (value is! List) return const [];
  final result = <RhythmHit>[];
  for (final row in value) {
    if (row is Map) {
      final parsed = RhythmHit.fromJson(Map<String, dynamic>.from(row));
      if (parsed.isValid) result.add(parsed);
    }
  }
  return result;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}'.trim()) ?? fallback;
}

double _num(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.trim()) ?? fallback;
}

DateTime? _time(Object? value) {
  final text =
      '${value ?? ''}'.trim().replaceFirst(' ', 'T').replaceAll('/', '-');
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text);
}
