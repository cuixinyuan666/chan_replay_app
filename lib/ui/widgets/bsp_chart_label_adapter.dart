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
    return '$prefix${_displayType(bsp.type)}$suffix';
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

  String _displayType(String rawType) {
    final normalized = rawType.trim();
    if (normalized.isEmpty) return 'BSP';
    return normalized
        .replaceAll('buy', '')
        .replaceAll('Buy', '')
        .replaceAll('BUY', '')
        .replaceAll('sell', '')
        .replaceAll('Sell', '')
        .replaceAll('SELL', '')
        .replaceAll('买', '')
        .replaceAll('卖', '')
        .trim()
        .isEmpty
        ? normalized
        : normalized
            .replaceAll('buy', '')
            .replaceAll('Buy', '')
            .replaceAll('BUY', '')
            .replaceAll('sell', '')
            .replaceAll('Sell', '')
            .replaceAll('SELL', '')
            .replaceAll('买', '')
            .replaceAll('卖', '')
            .trim();
  }
}
