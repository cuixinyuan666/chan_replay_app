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
      dif: _parseDouble(json['dif'] ?? json['diff']),
      dea: _parseDouble(json['dea'] ?? json['signal']),
      hist: _parseDouble(json['hist'] ?? json['macd']),
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
      upper: _parseDouble(json['upper']),
      mid: _parseDouble(json['mid'] ?? json['middle']),
      lower: _parseDouble(json['lower']),
    );
  }
}

class EasyTdxIndicators {
  final List<EasyIndicatorPoint> vol;
  final List<EasyIndicatorPoint> amount;
  final List<EasyIndicatorPoint> turnover;
  final Map<int, List<EasyIndicatorPoint>> ma;
  final List<EasyBollPoint> boll;
  final List<EasyMacdPoint> macd;
  final List<EasyNamedIndicatorPoint> kdj;
  final List<EasyNamedIndicatorPoint> rsi;
  final List<EasyNamedIndicatorPoint> dmi;
  final List<EasyNamedIndicatorPoint> atr;
  final List<EasyNamedIndicatorPoint> wr;
  final List<EasyNamedIndicatorPoint> cci;
  final List<EasyNamedIndicatorPoint> bias;
  final List<EasyNamedIndicatorPoint> obv;

  const EasyTdxIndicators({
    this.vol = const [],
    this.amount = const [],
    this.turnover = const [],
    this.ma = const {},
    this.boll = const [],
    this.macd = const [],
    this.kdj = const [],
    this.rsi = const [],
    this.dmi = const [],
    this.atr = const [],
    this.wr = const [],
    this.cci = const [],
    this.bias = const [],
    this.obv = const [],
  });

  bool get isEmpty =>
      vol.isEmpty &&
      amount.isEmpty &&
      turnover.isEmpty &&
      ma.isEmpty &&
      boll.isEmpty &&
      macd.isEmpty &&
      kdj.isEmpty &&
      rsi.isEmpty &&
      dmi.isEmpty &&
      atr.isEmpty &&
      wr.isEmpty &&
      cci.isEmpty &&
      bias.isEmpty &&
      obv.isEmpty;

  Map<String, List<EasyNamedIndicatorPoint>> get namedSeries => {
        'KDJ': kdj,
        'RSI': rsi,
        'DMI': dmi,
        'ATR': atr,
        'WR': wr,
        'CCI': cci,
        'BIAS': bias,
        'OBV': obv,
      };

  factory EasyTdxIndicators.empty() => const EasyTdxIndicators();

  factory EasyTdxIndicators.fromJson(Object? value) {
    if (value is! Map) return const EasyTdxIndicators();
    return EasyTdxIndicators(
      vol: _parsePointList(value['vol']),
      amount: _parsePointList(value['amount']),
      turnover: _parsePointList(value['turnover']),
      ma: _parseMa(value['ma']),
      boll: _parseBollList(value['boll']),
      macd: _parseMacdList(value['macd']),
      kdj: _parseNamedList(value['kdj']),
      rsi: _parseNamedList(value['rsi']),
      dmi: _parseNamedList(value['dmi']),
      atr: _parseNamedList(value['atr']),
      wr: _parseNamedList(value['wr']),
      cci: _parseNamedList(value['cci']),
      bias: _parseNamedList(value['bias']),
      obv: _parseNamedList(value['obv']),
    );
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
