class EasyIndicatorPoint {
  final DateTime? time;
  final int rawIndex;
  final double? value;

  const EasyIndicatorPoint({required this.time, required this.rawIndex, required this.value});

  factory EasyIndicatorPoint.fromJson(Map<dynamic, dynamic> json, int fallbackIndex) {
    return EasyIndicatorPoint(
      time: _parseTime(json['time'] ?? json['dt'] ?? json['date']),
      rawIndex: _parseInt(json['raw_index'] ?? json['rawIndex']) ?? fallbackIndex,
      value: _parseDouble(json['value']),
    );
  }
}

class EasyNamedIndicatorPoint {
  final DateTime? time;
  final int rawIndex;
  final Map<String, double?> values;

  const EasyNamedIndicatorPoint({required this.time, required this.rawIndex, required this.values});

  factory EasyNamedIndicatorPoint.fromJson(Map<dynamic, dynamic> json, int fallbackIndex) {
    final rawValues = json['values'];
    final values = <String, double?>{};
    if (rawValues is Map) {
      for (final entry in rawValues.entries) {
        values['${entry.key}'] = _parseDouble(entry.value);
      }
    } else {
      for (final entry in json.entries) {
        final key = '${entry.key}';
        if (key == 'time' || key == 'dt' || key == 'date' || key == 'raw_index' || key == 'rawIndex') continue;
        values[key] = _parseDouble(entry.value);
      }
    }
    return EasyNamedIndicatorPoint(
      time: _parseTime(json['time'] ?? json['dt'] ?? json['date']),
      rawIndex: _parseInt(json['raw_index'] ?? json['rawIndex']) ?? fallbackIndex,
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

  const EasyMacdPoint({required this.time, required this.rawIndex, required this.dif, required this.dea, required this.hist});

  factory EasyMacdPoint.fromJson(Map<dynamic, dynamic> json, int fallbackIndex) {
    return EasyMacdPoint(
      time: _parseTime(json['time'] ?? json['dt'] ?? json['date']),
      rawIndex: _parseInt(json['raw_index'] ?? json['rawIndex']) ?? fallbackIndex,
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

  const EasyBollPoint({required this.time, required this.rawIndex, required this.upper, required this.mid, required this.lower});

  factory EasyBollPoint.fromJson(Map<dynamic, dynamic> json, int fallbackIndex) {
    return EasyBollPoint(
      time: _parseTime(json['time'] ?? json['dt'] ?? json['date']),
      rawIndex: _parseInt(json['raw_index'] ?? json['rawIndex']) ?? fallbackIndex,
      upper: _parseDouble(json['upper'] ?? json['BOLL_UPPER']),
      mid: _parseDouble(json['mid'] ?? json['middle'] ?? json['BOLL_MID']),
      lower: _parseDouble(json['lower'] ?? json['BOLL_LOWER']),
    );
  }
}

class EasyTdxIndicators {
  static const Set<String> _knownKeys = {'vol', 'amount', 'turnover', 'ma', 'boll', 'macd'};

  final List<EasyIndicatorPoint> vol;
  final List<EasyIndicatorPoint> amount;
  final List<EasyIndicatorPoint> turnover;
  final Map<int, List<EasyIndicatorPoint>> ma;
  final List<EasyBollPoint> boll;
  final List<EasyMacdPoint> macd;
  final Map<String, List<EasyNamedIndicatorPoint>> namedSeries;

  const EasyTdxIndicators({
    this.vol = const [],
    this.amount = const [],
    this.turnover = const [],
    this.ma = const {},
    this.boll = const [],
    this.macd = const [],
    this.namedSeries = const {},
  });

  bool get isEmpty => vol.isEmpty && amount.isEmpty && turnover.isEmpty && ma.isEmpty && boll.isEmpty && macd.isEmpty && namedSeries.values.every((rows) => rows.isEmpty);

  factory EasyTdxIndicators.empty() => const EasyTdxIndicators();

  factory EasyTdxIndicators.fromJson(Object? value) {
    if (value is! Map) return const EasyTdxIndicators();
    final named = <String, List<EasyNamedIndicatorPoint>>{};
    for (final entry in value.entries) {
      final key = '${entry.key}';
      final lower = key.toLowerCase();
      if (_knownKeys.contains(lower) || entry.value is! List) continue;
      named[_displayName(lower)] = _parseNamedList(entry.value);
    }
    return EasyTdxIndicators(
      vol: _parsePointList(value['vol']),
      amount: _parsePointList(value['amount']),
      turnover: _parsePointList(value['turnover']),
      ma: _parseMa(value['ma']),
      boll: _parseBollList(value['boll']),
      macd: _parseMacdList(value['macd']),
      namedSeries: named,
    );
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

  List<EasyIndicatorPoint> visibleVol(int start, int end) => _visiblePoints(vol, start, end);
  List<EasyIndicatorPoint> visibleAmount(int start, int end) => _visiblePoints(amount, start, end);
  List<EasyIndicatorPoint> visibleTurnover(int start, int end) => _visiblePoints(turnover, start, end);

  List<EasyMacdPoint> visibleMacd(int start, int end) {
    return [
      for (final row in macd)
        if (row.rawIndex >= start && row.rawIndex <= end) row,
    ];
  }

  List<EasyNamedIndicatorPoint> visibleNamed(String key, int start, int end) {
    final rows = namedSeries[key.toUpperCase()] ?? const <EasyNamedIndicatorPoint>[];
    return [
      for (final row in rows)
        if (row.rawIndex >= start && row.rawIndex <= end) row,
    ];
  }

  static List<EasyIndicatorPoint> _visiblePoints(List<EasyIndicatorPoint> rows, int start, int end) {
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

DateTime? _parseTime(Object? value) {
  final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T').replaceAll('/', '-');
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text);
}

double? _parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  final text = '${value ?? ''}'.trim().replaceAll(',', '');
  if (text.isEmpty || text == '-' || text == '--' || text.toLowerCase() == 'nan' || text == 'null') return null;
  return double.tryParse(text);
}

int? _parseInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}'.trim());
}
