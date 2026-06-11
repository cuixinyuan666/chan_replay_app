import 'signal_visibility_state.dart';

class IntervalNestSignal {
  final String direction;
  final String highLevel;
  final String? midLevel;
  final String lowLevel;
  final String highPattern;
  final String? midPattern;
  final String lowTrigger;
  final int highRawIndex;
  final int? midRawIndex;
  final int? lowRawIndex;
  final double score;
  final SignalVisibilityState state;
  final List<String> reasons;
  final List<String> warnings;
  final int? observedAtCursor;
  final int? confirmedAtCursor;
  final int? invalidatedAtCursor;
  final Map<String, dynamic> meta;

  const IntervalNestSignal({
    required this.direction,
    required this.highLevel,
    this.midLevel,
    required this.lowLevel,
    required this.highPattern,
    this.midPattern,
    required this.lowTrigger,
    required this.highRawIndex,
    this.midRawIndex,
    this.lowRawIndex,
    this.score = 0,
    this.state = SignalVisibilityState.candidate,
    this.reasons = const [],
    this.warnings = const [],
    this.observedAtCursor,
    this.confirmedAtCursor,
    this.invalidatedAtCursor,
    this.meta = const {},
  });

  factory IntervalNestSignal.fromJson(Map<String, dynamic> json) {
    return IntervalNestSignal(
      direction: '${json['direction'] ?? ''}',
      highLevel: '${json['high_level'] ?? json['highLevel'] ?? ''}',
      midLevel: _optionalString(json['mid_level'] ?? json['midLevel']),
      lowLevel: '${json['low_level'] ?? json['lowLevel'] ?? ''}',
      highPattern: '${json['high_pattern'] ?? json['highPattern'] ?? ''}',
      midPattern: _optionalString(json['mid_pattern'] ?? json['midPattern']),
      lowTrigger: '${json['low_trigger'] ?? json['lowTrigger'] ?? ''}',
      highRawIndex: _int(json['high_raw_index'] ?? json['highRawIndex']),
      midRawIndex: _nullableInt(json['mid_raw_index'] ?? json['midRawIndex']),
      lowRawIndex: _nullableInt(json['low_raw_index'] ?? json['lowRawIndex']),
      score: _double(json['score']),
      state: SignalVisibilityStateX.fromWireName(json['state']),
      reasons: _stringList(json['reasons']),
      warnings: _stringList(json['warnings']),
      observedAtCursor:
          _nullableInt(json['observed_at_cursor'] ?? json['observedAtCursor']),
      confirmedAtCursor:
          _nullableInt(json['confirmed_at_cursor'] ?? json['confirmedAtCursor']),
      invalidatedAtCursor:
          _nullableInt(json['invalidated_at_cursor'] ?? json['invalidatedAtCursor']),
      meta: json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'direction': direction,
        'high_level': highLevel,
        if (midLevel != null) 'mid_level': midLevel,
        'low_level': lowLevel,
        'high_pattern': highPattern,
        if (midPattern != null) 'mid_pattern': midPattern,
        'low_trigger': lowTrigger,
        'high_raw_index': highRawIndex,
        if (midRawIndex != null) 'mid_raw_index': midRawIndex,
        if (lowRawIndex != null) 'low_raw_index': lowRawIndex,
        'score': score,
        'state': state.wireName,
        'reasons': reasons,
        'warnings': warnings,
        if (observedAtCursor != null) 'observed_at_cursor': observedAtCursor,
        if (confirmedAtCursor != null) 'confirmed_at_cursor': confirmedAtCursor,
        if (invalidatedAtCursor != null)
          'invalidated_at_cursor': invalidatedAtCursor,
        if (meta.isNotEmpty) 'meta': meta,
      };

  bool get isBuy => direction.toLowerCase() == 'buy';
  bool get isSell => direction.toLowerCase() == 'sell';
  bool get isNoFutureSafe => state.isNoFutureSafe;
  bool get isTradableAtCursor => state.isTradableAtCursor;

  static String? _optionalString(Object? value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) return [for (final item in value) '$item'];
    return const [];
  }

  static int _int(Object? value) => _nullableInt(value) ?? 0;

  static int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;
    return int.tryParse(text);
  }

  static double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}'.trim()) ?? 0;
  }
}
