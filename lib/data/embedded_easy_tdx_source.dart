import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../core/models/raw_bar.dart';

class EmbeddedEasyTdxSource {
  static const MethodChannel _channel = MethodChannel('chan_replay_app/python_easy_tdx');

  Future<List<RawBar>> loadKline({
    required String market,
    required String code,
    String period = 'DAILY',
    String adjust = 'QFQ',
    int count = 800,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('内置 Python easy-tdx 目前只支持 Android；Windows 请使用 easy-tdx 后端模式');
    }

    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw const FormatException('股票代码必须是6位数字，例如 000001');
    }
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw const FormatException('开始日期不能晚于结束日期');
    }

    final payload = jsonEncode({
      'symbol': normalizedCode,
      'market': market.trim().toUpperCase(),
      'period': period.trim().toUpperCase(),
      'adjust': adjust.trim().toUpperCase(),
      'count': count,
      if (startDate != null) 'start': _fmtDate(startDate),
      if (endDate != null) 'end': _fmtDate(endDate),
    });

    final raw = await _channel.invokeMethod<String>('loadKline', {'payload': payload});
    if (raw == null || raw.trim().isEmpty) {
      throw const FormatException('内置 Python 未返回数据');
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('内置 Python 返回结构不是 JSON 对象');
    }
    if (decoded['ok'] == false) {
      throw Exception(decoded['error'] ?? '内置 easy-tdx 获取失败');
    }
    final rows = decoded['bars'];
    if (rows is! List) {
      throw const FormatException('内置 Python 未返回 bars 数组');
    }

    final bars = <RawBar>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final bar = _parseBar(row, bars.length);
      if (bar == null) continue;
      bars.add(bar.copyWith(index: bars.length));
    }
    bars.sort((a, b) => a.time.compareTo(b.time));
    return [
      for (var i = 0; i < bars.length; i++) bars[i].copyWith(index: i),
    ];
  }

  RawBar? _parseBar(Map row, int index) {
    final time = _parseTime(row['dt'] ?? row['datetime'] ?? row['date'] ?? row['time']);
    final open = _parseDouble(row['open'] ?? row['o']);
    final high = _parseDouble(row['high'] ?? row['h']);
    final low = _parseDouble(row['low'] ?? row['l']);
    final close = _parseDouble(row['close'] ?? row['c']);
    final volume = _parseDouble(row['vol'] ?? row['volume'] ?? row['v']) ?? 0.0;

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

  String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  DateTime? _parseTime(Object? value) {
    final text = '${value ?? ''}'.trim().replaceFirst(' ', 'T');
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  double? _parseDouble(Object? value) {
    if (value is num) return value.toDouble();
    final text = '${value ?? ''}'.trim().replaceAll(',', '');
    if (text.isEmpty || text == '-' || text.toLowerCase() == 'nan') return null;
    return double.tryParse(text);
  }
}
