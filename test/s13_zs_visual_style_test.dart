import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('base ZS is red border-only and fx circles are hidden', () {
    final source = _read('lib/ui/widgets/origin_kline_chart.dart');

    expect(source, contains('BI-level ZS follows BI line color: red'));
    expect(source, contains('const Color(0xFFE53935).withValues(alpha: 0.88)'));
    expect(source, isNot(contains('canvas.drawRect(area, fill);')));
    expect(source, isNot(contains('canvas.drawCircle(p, 4')));
    expect(source, contains('Do not draw circular top/bottom icons'));
  });

  test('native and recursive segment ZS are border-only and color-aligned', () {
    final source =
        _read('lib/ui/widgets/recursive_seg_origin_kline_chart.dart');

    expect(source, contains('Native segment ZS follows native SEG line color'));
    expect(
        source, contains('colorValue: zs.confirmed ? 0xFF00E676 : 0xFFB2FF59'));
    expect(
        source,
        contains(
            'Recursive segment ZS follows the recursive segment line color'));
    expect(
        source,
        contains(
            '_styleForLayer(layer: layer, isSure: zs.confirmed).strokeWidth'));

    final filledFalseCount =
        RegExp(r'filled:\s*false').allMatches(source).length;
    expect(filledFalseCount, greaterThanOrEqualTo(2));
  });
}
