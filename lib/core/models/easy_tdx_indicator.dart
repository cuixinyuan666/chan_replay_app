class EasyIndicatorPoint {
  final DateTime? time;
  final int rawIndex;
  final double? value;

  const EasyIndicatorPoint(
      {required this.time, required this.rawIndex, required this.value});

  factory EasyIndicatorPoint.fromJson(
      Map<dynamic, dynamic> json, int fallbackIndex) {
    return EasyIndicatorPoint(
      time: _parseTime(json['time'] ?? json['dt'] ?? json['date']),
      rawIndex:
          _parseInt(json['raw_index'] ?? json['rawIndex']) ?? fallbackIndex,
      value: _parseDouble(json['value']),
    );
  }
}

class EasyNamedIndicatorPoint {
  final DateTime? time;
  final int rawIndex;
  final Map<String, double?> values;

  const EasyNamedIndicatorPoint(
      {required this.time, required this.rawIndex, required this.values});

  factory EasyNamedIndicatorPoint.fromJson(
      Map<dynamic, dynamic> json, int fallbackIndex) {
    final rawValues = json['values'];
    final values = <String, double?>{};
    if (rawValues is Map) {
      for (final entry in rawValues.entries) {
        values['${entry.key}'] = _parseDouble(entry.value);
      }
    } else {
      for (final entry in json.entries) {
        final key = '${entry.key}';
        if (key == 'time' ||
            key == 'dt' ||
            key == 'date' ||
            key == 'raw_index' ||
            key == 'rawIndex') continue;
        values[key] = _parseDouble(entry.value);
      }
    }
    return EasyNamedIndicatorPoint(
      time: _parseTime(json['time'] ?? json['dt'] ?? json['date']),
      rawIndex:
          _parseInt(json['raw_index'] ?? json['rawIndex']) ?? fallbackIndex,
      values: values,
    );
  }
}

class EasyMacdPoint {
  final DateTime? time;
  final int rawIndex;
  final double? dif;
  final double? dea;
  final double? hist;

  const EasyMacdPoint(
      {required this.time,
      required this.rawIndex,
      required this.dif,
      required this.dea,
      required this.hist});

  factory EasyMacdPoint.fromJson(
      Map<dynamic, dynamic> json, int fallbackIndex) {
    return EasyMacdPoint(
      time: _parseTime(json['time'] ?? json['dt'] ?? json['date']),
      rawIndex:
          _parseInt(json['raw_index'] ?? json['rawIndex']) ?? fallbackIndex,
      dif: _parseDouble(json['dif'] ?? json['diff'] ?? json['MACD_DIF']),
      dea: _parseDouble(json['dea'] ?? json['signal'] ?? json['MACD_DEA']),
      hist: _parseDouble(json['hist'] ?? json['macd'] ?? json['MACD_HIST']),
    );
  }
}

class EasyBollPoint {
  final DateTime? time;
  final int rawIndex;
  final double? upper;
  final double? mid;
  final double? lower;

  const EasyBollPoint(
      {required this.time,
      required this.rawIndex,
      required this.upper,
      required this.mid,
      required this.lower});

  factory EasyBollPoint.fromJson(
      Map<dynamic, dynamic> json, int fallbackIndex) {
    return EasyBollPoint(
      time: _parseTime(json['time'] ?? json['dt'] ?? json['date']),
      rawIndex:
          _parseInt(json['raw_index'] ?? json['rawIndex']) ?? fallbackIndex,
      upper: _parseDouble(json['upper'] ?? json['BOLL_UPPER']),
      mid: _parseDouble(json['mid'] ?? json['middle'] ?? json['BOLL_MID']),
      lower: _parseDouble(json['lower'] ?? json['BOLL_LOWER']),
    );
  }
}

class EasyTdxIndicators {
  static const Set<String> _knownKeys = {
    'vol',
    'amount',
    'turnover',
    'ma',
    'boll',
    'macd'
  };

  final List<EasyIndicatorPoint> _vol;
  final List<EasyIndicatorPoint> _amount;
  final List<EasyIndicatorPoint> _turnover;
  final Map<int, List<EasyIndicatorPoint>> _ma;
  final List<EasyBollPoint> _boll;
  final List<EasyMacdPoint> _macd;
  final Map<String, List<EasyNamedIndicatorPoint>> _namedSeries;
  final _EasyTdxIndicatorLazyStore? _lazy;

  const EasyTdxIndicators({
    List<EasyIndicatorPoint> vol = const [],
    List<EasyIndicatorPoint> amount = const [],
    List<EasyIndicatorPoint> turnover = const [],
    Map<int, List<EasyIndicatorPoint>> ma = const {},
    List<EasyBollPoint> boll = const [],
    List<EasyMacdPoint> macd = const [],
    Map<String, List<EasyNamedIndicatorPoint>> namedSeries = const {},
  })  : _vol = vol,
        _amount = amount,
        _turnover = turnover,
        _ma = ma,
        _boll = boll,
        _macd = macd,
        _namedSeries = namedSeries,
        _lazy = null;

  EasyTdxIndicators._lazy(Map<dynamic, dynamic> raw)
      : _vol = const [],
        _amount = const [],
        _turnover = const [],
        _ma = const {},
        _boll = const [],
        _macd = const [],
        _namedSeries = const {},
        _lazy = _EasyTdxIndicatorLazyStore(raw);

  List<EasyIndicatorPoint> get vol => _lazy?.vol ?? _vol;
  List<EasyIndicatorPoint> get amount => _lazy?.amount ?? _amount;
  List<EasyIndicatorPoint> get turnover => _lazy?.turnover ?? _turnover;
  Map<int, List<EasyIndicatorPoint>> get ma => _lazy?.ma ?? _ma;
  List<EasyBollPoint> get boll => _lazy?.boll ?? _boll;
  List<EasyMacdPoint> get macd => _lazy?.macd ?? _macd;
  Map<String, List<EasyNamedIndicatorPoint>> get namedSeries =>
      _lazy?.namedSeries ?? _namedSeries;

  bool get isEmpty {
    final lazy = _lazy;
    if (lazy != null) return lazy.isEmpty;
    return vol.isEmpty &&
        amount.isEmpty &&
        turnover.isEmpty &&
        ma.isEmpty &&
        boll.isEmpty &&
        macd.isEmpty &&
        namedSeries.values.every((rows) => rows.isEmpty);
  }

  factory EasyTdxIndicators.empty() => const EasyTdxIndicators();

  factory EasyTdxIndicators.fromJson(Object? value) {
    if (value is! Map) return const EasyTdxIndicators();
    // F1k: keep the raw payload and parse each indicator series only when a
    // chart or panel actually asks for it. This avoids paying the full
    // indicator parse cost during top snapshot parsing.
    return EasyTdxIndicators._lazy(Map<dynamic, dynamic>.from(value));
  }

  Map<int, List<EasyIndicatorPoint>> visibleMa(int start, int end) {
    final result = <int, List<EasyIndicatorPoint>>{};
    for (final entry in ma.entries) {
      final rows = _visiblePoints(entry.value, start, end);
      if (rows.isNotEmpty) result[entry.key] = rows;
    }
    return result;
  }

  List<EasyBollPoint> visibleBoll(int start, int end) {
    return [
      for (final row in boll)
        if (row.rawIndex >= start && row.rawIndex <= end) row,
    ];
  }

  List<EasyIndicatorPoint> visibleVol(int start, int end) =>
      _visiblePoints(vol, start, end);
  List<EasyIndicatorPoint> visibleAmount(int start, int end) =>
      _visiblePoints(amount, start, end);
  List<EasyIndicatorPoint> visibleTurnover(int start, int end) =>
      _visiblePoints(turnover, start, end);

  List<EasyMacdPoint> visibleMacd(int start, int end) {
    return [
      for (final row in macd)
        if (row.rawIndex >= start && row.rawIndex <= end) row,
    ];
  }

  List<EasyNamedIndicatorPoint> visibleNamed(String key, int start, int end) {
    final rows =
        namedSeries[key.toUpperCase()] ?? const <EasyNamedIndicatorPoint>[];
    return [
      for (final row in rows)
        if (row.rawIndex >= start && row.rawIndex <= end) row,
    ];
  }

  static List<EasyIndicatorPoint> _visiblePoints(
      List<EasyIndicatorPoint> rows, int start, int end) {
    return [
      for (final row in rows)
        if (row.rawIndex >= start && row.rawIndex <= end) row,
    ];
  }

  static String _displayName(String key) {
    if (key == 'bias_signal') return 'BIAS_SIGNAL';
    return key.toUpperCase();
  }

  static List<EasyIndicatorPoint> _parsePointList(Object? value) {
    if (value is! List) return const [];
    final result = <EasyIndicatorPoint>[];
    for (var i = 0; i < value.length; i++) {
      final row = value[i];
      if (row is Map) result.add(EasyIndicatorPoint.fromJson(row, i));
    }
    return result;
  }

  static List<EasyNamedIndicatorPoint> _parseNamedList(Object? value) {
    if (value is! List) return const [];
    final result = <EasyNamedIndicatorPoint>[];
    for (var i = 0; i < value.length; i++) {
      final row = value[i];
      if (row is Map) result.add(EasyNamedIndicatorPoint.fromJson(row, i));
    }
    return result;
  }

  static Map<int, List<EasyIndicatorPoint>> _parseMa(Object? value) {
    if (value is! Map) return const {};
    final result = <int, List<EasyIndicatorPoint>>{};
    for (final entry in value.entries) {
      final period = _parseInt(entry.key);
      if (period == null) continue;
      result[period] = _parsePointList(entry.value);
    }
    return result;
  }

  static List<EasyBollPoint> _parseBollList(Object? value) {
    if (value is! List) return const [];
    final result = <EasyBollPoint>[];
    for (var i = 0; i < value.length; i++) {
      final row = value[i];
      if (row is Map) result.add(EasyBollPoint.fromJson(row, i));
    }
    return result;
  }

  static List<EasyMacdPoint> _parseMacdList(Object? value) {
    if (value is! List) return const [];
    final result = <EasyMacdPoint>[];
    for (var i = 0; i < value.length; i++) {
      final row = value[i];
      if (row is Map) result.add(EasyMacdPoint.fromJson(row, i));
    }
    return result;
  }
}

class _EasyTdxIndicatorLazyStore {
  final Map<dynamic, dynamic> raw;
  List<EasyIndicatorPoint>? _vol;
  List<EasyIndicatorPoint>? _amount;
  List<EasyIndicatorPoint>? _turnover;
  Map<int, List<EasyIndicatorPoint>>? _ma;
  List<EasyBollPoint>? _boll;
  List<EasyMacdPoint>? _macd;
  Map<String, List<EasyNamedIndicatorPoint>>? _namedSeries;

  _EasyTdxIndicatorLazyStore(this.raw);

  List<EasyIndicatorPoint> get vol =>
      _vol ??= EasyTdxIndicators._parsePointList(raw['vol']);
  List<EasyIndicatorPoint> get amount =>
      _amount ??= EasyTdxIndicators._parsePointList(raw['amount']);
  List<EasyIndicatorPoint> get turnover =>
      _turnover ??= EasyTdxIndicators._parsePointList(raw['turnover']);
  Map<int, List<EasyIndicatorPoint>> get ma =>
      _ma ??= EasyTdxIndicators._parseMa(raw['ma']);
  List<EasyBollPoint> get boll =>
      _boll ??= EasyTdxIndicators._parseBollList(raw['boll']);
  List<EasyMacdPoint> get macd =>
      _macd ??= EasyTdxIndicators._parseMacdList(raw['macd']);

  Map<String, List<EasyNamedIndicatorPoint>> get namedSeries {
    final cached = _namedSeries;
    if (cached != null) return cached;
    final named = <String, List<EasyNamedIndicatorPoint>>{};
    for (final entry in raw.entries) {
      final key = '${entry.key}';
      final lower = key.toLowerCase();
      if (EasyTdxIndicators._knownKeys.contains(lower) || entry.value is! List) {
        continue;
      }
      named[EasyTdxIndicators._displayName(lower)] =
          EasyTdxIndicators._parseNamedList(entry.value);
    }
    _namedSeries = named;
    return named;
  }

  bool get isEmpty {
    if (raw.isEmpty) return true;
    for (final key in EasyTdxIndicators._knownKeys) {
      final value = raw[key];
      if (value is List && value.isNotEmpty) return false;
      if (value is Map && value.isNotEmpty) return false;
    }
    for (final entry in raw.entries) {
      final lower = '${entry.key}'.toLowerCase();
      if (EasyTdxIndicators._knownKeys.contains(lower)) continue;
      final value = entry.value;
      if (value is List && value.isNotEmpty) return false;
    }
    return true;
  }
}

DateTime? _parseTime(Object? value) {
  final text =
      '${value ?? ''}'.trim().replaceFirst(' ', 'T').replaceAll('/', '-');
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text);
}

double? _parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  final text = '${value ?? ''}'.trim().replaceAll(',', '');
  if (text.isEmpty ||
      text == '-' ||
      text == '--' ||
      text.toLowerCase() == 'nan' ||
      text == 'null') return null;
  return double.tryParse(text);
}

int? _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}'.trim());
}
