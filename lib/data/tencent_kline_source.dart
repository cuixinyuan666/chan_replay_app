import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/models/raw_bar.dart';

class TencentKlineSource {
  TencentKlineSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<RawBar>> loadKline({
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int count = 500,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw const FormatException('股票代码必须是6位数字，例如 000001');
    }

    final symbol = '${_marketPrefix(market)}$normalizedCode';
    final periodValue = _periodValue(period);
    final normalizedAdjust = adjust.trim().toUpperCase();
    final fq = _isMinutePeriod(periodValue) || normalizedAdjust == 'NONE'
        ? ''
        : ',${_fqValue(normalizedAdjust)}';

    final uri = Uri.https(
      'web.ifzq.gtimg.cn',
      '/appstock/app/fqkline/get',
      {'param': '$symbol,$periodValue,,,$count$fq'},
    );

    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
        'Referer': 'https://gu.qq.com/',
      },
    ).timeout(timeout);

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw Exception('腾讯行情请求失败：HTTP ${response.statusCode} $body');
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('腾讯行情返回格式不正确：根节点不是对象');
    }

    final codeValue = decoded['code'];
    if (codeValue is num && codeValue != 0) {
      throw FormatException('腾讯行情返回错误 code=$codeValue：${decoded['msg'] ?? ''}');
    }

    final root = decoded['data'];
    if (root is! Map<String, dynamic>) {
      throw const FormatException('腾讯行情未返回 data');
    }

    final stockNode = root[symbol];
    if (stockNode is! Map<String, dynamic>) {
      throw FormatException('腾讯行情未返回 $symbol 数据，可能是市场或代码错误');
    }

    final rows = _extractRows(stockNode, periodValue, normalizedAdjust);
    final bars = <RawBar>[];
    for (final row in rows) {
      final bar = _parseRow(row, bars.length);
      if (bar != null) bars.add(bar);
    }

    bars.sort((a, b) => a.time.compareTo(b.time));
    return [
      for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i),
    ];
  }

  void close() => _client.close();

  static String _marketPrefix(String market) {
    final upper = market.trim().toUpperCase();
    if (upper == 'SH') return 'sh';
    if (upper == 'SZ') return 'sz';
    throw const FormatException('市场只支持 SH 或 SZ');
  }

  static String _periodValue(String period) {
    switch (period.trim().toUpperCase()) {
      case 'MIN1':
        return 'm1';
      case 'MIN5':
        return 'm5';
      case 'MIN15':
        return 'm15';
      case 'MIN30':
        return 'm30';
      case 'MIN60':
        return 'm60';
      case 'DAILY':
        return 'day';
      case 'WEEKLY':
        return 'week';
      case 'MONTHLY':
        return 'month';
      default:
        throw const FormatException('不支持的周期');
    }
  }

  static String _fqValue(String adjust) {
    switch (adjust) {
      case 'QFQ':
        return 'qfq';
      case 'HFQ':
        return 'hfq';
      default:
        throw const FormatException('腾讯行情复权只支持 NONE、QFQ、HFQ');
    }
  }

  static bool _isMinutePeriod(String periodValue) => periodValue.startsWith('m');

  static List<dynamic> _extractRows(
    Map<String, dynamic> stockNode,
    String periodValue,
    String adjust,
  ) {
    final candidates = <String>[
      if (!_isMinutePeriod(periodValue) && adjust == 'QFQ') 'qfq$periodValue',
      if (!_isMinutePeriod(periodValue) && adjust == 'HFQ') 'hfq$periodValue',
      periodValue,
      'qfq$periodValue',
      'hfq$periodValue',
    ];

    for (final key in candidates) {
      final value = stockNode[key];
      if (value is List) return value;
    }

    for (final entry in stockNode.entries) {
      if (entry.value is List && entry.key.toLowerCase().contains(periodValue)) {
        return entry.value as List<dynamic>;
      }
    }

    throw FormatException('腾讯行情未返回 $periodValue 周期K线');
  }

  static RawBar? _parseRow(dynamic item, int index) {
    if (item is! List || item.length < 6) return null;

    final time = _parseTime(item[0]);
    final open = _parseDouble(item[1]);
    final close = _parseDouble(item[2]);
    final high = _parseDouble(item[3]);
    final low = _parseDouble(item[4]);
    final volume = _parseDouble(item[5]) ?? 0.0;

    if (time == null || open == null || high == null || low == null || close == null) {
      return null;
    }

    return RawBar(
      index: index,
      time: time,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  static DateTime? _parseTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;

    if (RegExp(r'^\d{8}$').hasMatch(text)) {
      return DateTime.tryParse(
        '${text.substring(0, 4)}-${text.substring(4, 6)}-${text.substring(6, 8)}',
      );
    }

    return DateTime.tryParse(text.replaceFirst(' ', 'T')) ?? DateTime.tryParse(text);
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text.toLowerCase() == 'nan') return null;
    return double.tryParse(text);
  }
}
