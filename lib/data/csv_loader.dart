import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';

import '../core/models/raw_bar.dart';

class CsvLoader {
  static Future<List<RawBar>> loadFromAsset(String assetPath) async {
    final text = await rootBundle.loadString(assetPath);
    return parse(text);
  }

  static Future<List<RawBar>?> pickAndLoadCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final bytes = result.files.first.bytes;
    if (bytes == null) return null;
    return parse(utf8.decode(bytes));
  }

  static List<RawBar> parse(String text) {
    final lines = const LineSplitter()
        .convert(text)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    var start = 0;
    final first = _split(lines.first);
    if (first.isNotEmpty && DateTime.tryParse(first[0]) == null) {
      start = 1;
    }

    final bars = <RawBar>[];
    for (var i = start; i < lines.length; i++) {
      final row = _split(lines[i]);
      if (row.length < 5) continue;
      final time = _parseDate(row[0]);
      final open = double.tryParse(row[1]);
      final high = double.tryParse(row[2]);
      final low = double.tryParse(row[3]);
      final close = double.tryParse(row[4]);
      final volume = row.length >= 6 ? double.tryParse(row[5]) ?? 0.0 : 0.0;
      if (time == null ||
          open == null ||
          high == null ||
          low == null ||
          close == null) {
        continue;
      }
      bars.add(RawBar(
        index: bars.length,
        time: time,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      ));
    }
    return bars;
  }

  static List<String> _split(String line) {
    if (line.contains('\t')) {
      return line.split('\t').map((e) => e.trim()).toList();
    }
    return line.split(',').map((e) => e.trim()).toList();
  }

  static DateTime? _parseDate(String s) {
    final direct = DateTime.tryParse(s);
    if (direct != null) return direct;
    final parts = s.split(RegExp(r'[-/]'));
    if (parts.length >= 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) return DateTime(y, m, d);
    }
    return null;
  }
}
