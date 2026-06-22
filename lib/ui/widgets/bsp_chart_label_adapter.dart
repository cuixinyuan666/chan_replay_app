import 'package:flutter/material.dart';

import '../../core/models/bsp.dart';
import 'chart_label_layout.dart';

/// Converts Python chan.py BSP draw models into UI-only chart labels.
///
/// This adapter intentionally has no chan.py calculation logic. It only maps
/// already-exported BSP points to label text, placement side, priority and
/// display style for Flutter painting.
class BspChartLabelAdapter {
  const BspChartLabelAdapter();

  ChartLabel buildLabel({
    required BspPoint bsp,
    required Offset anchor,
    required bool isSegLevel,
    required Color color,
    int visibleWhenWindowLe = 360,
  }) {
    final text = labelText(bsp: bsp, isSegLevel: isSegLevel);
    return ChartLabel(
      text: text,
      anchor: anchor,
      side: bsp.isSell ? ChartLabelSide.top : ChartLabelSide.bottom,
      priority: ChartLabelPriority.bsp,
      rawIndex: bsp.rawIndex,
      color: color,
      fontSize: isSegLevel ? 10.5 : 9,
      visibleWhenWindowLe: visibleWhenWindowLe,
      forceVisible: isSegLevel || visibleWhenWindowLe <= 120,
    );
  }

  String labelText({required BspPoint bsp, required bool isSegLevel}) {
    final prefix = isSegLevel ? '段' : '笔';
    final suffix = bsp.confirmed ? '' : '?';
    return '$prefix${displayTypeFor(bsp)}$suffix';
  }

  static String labelTextFor({
    required String levelPrefix,
    required BspPoint bsp,
  }) {
    final suffix = bsp.confirmed ? '' : '?';
    return '$levelPrefix${displayTypeFor(bsp)}$suffix';
  }

  /// Display type used by both the near-candle BSP labels and the lower
  /// bottom-band BSP labels.
  ///
  /// Examples:
  /// - `buy3a`, `买3a` -> `B3a`
  /// - `sell2`, `卖2` -> `S2`
  /// - `B3a`, `S2` are preserved.
  static String displayTypeFor(BspPoint bsp) {
    var text = bsp.type.replaceAll('候选轨迹', '').trim();
    if (text.isEmpty) return bsp.isSell ? 'S' : 'B';

    final first = text.characters.isEmpty ? '' : text.characters.first;
    if (first.toLowerCase() == 'b' || first.toLowerCase() == 's') {
      return first.toUpperCase() + text.substring(first.length).trim();
    }

    text = text
        .replaceFirst(RegExp(r'^buy', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^sell', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^买'), '')
        .replaceFirst(RegExp(r'^卖'), '')
        .trim();
    if (text.isEmpty) return bsp.isSell ? 'S' : 'B';
    return '${bsp.isSell ? 'S' : 'B'}$text';
  }

  bool isSegLevel(BspPoint bsp) {
    final level = bsp.level.trim().toLowerCase();
    return level == 'seg' || level == 'segment' || level.contains('seg');
  }

  bool isBiLevel(BspPoint bsp) {
    final level = bsp.level.trim().toLowerCase();
    return level.isEmpty ||
        level == 'bi' ||
        (!level.contains('seg') && level != 'segment');
  }

  Color colorOf(BspPoint bsp) {
    return bsp.isSell ? const Color(0xFFFF7043) : const Color(0xFF00E676);
  }
}
