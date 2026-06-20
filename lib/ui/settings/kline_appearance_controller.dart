import 'package:flutter/material.dart';

class KlineAppearanceSettings {
  final Color klineColor;
  final double klineOpacity;
  final Color chartBackgroundColor;
  final Color appThemeColor;

  const KlineAppearanceSettings({
    this.klineColor = const Color(0xFFFFD54F),
    this.klineOpacity = 0.0,
    this.chartBackgroundColor = const Color(0xFF0D1117),
    this.appThemeColor = const Color(0xFFFFD54F),
  });

  KlineAppearanceSettings copyWith({
    Color? klineColor,
    double? klineOpacity,
    Color? chartBackgroundColor,
    Color? appThemeColor,
  }) {
    return KlineAppearanceSettings(
      klineColor: klineColor ?? this.klineColor,
      klineOpacity: (klineOpacity ?? this.klineOpacity).clamp(0.0, 0.85),
      chartBackgroundColor: chartBackgroundColor ?? this.chartBackgroundColor,
      appThemeColor: appThemeColor ?? this.appThemeColor,
    );
  }

  String colorText(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  String toEvidenceText() =>
      'kline_color=${colorText(klineColor)} kline_opacity=${klineOpacity.toStringAsFixed(2)} '
      'chart_background=${colorText(chartBackgroundColor)} app_theme=${colorText(appThemeColor)}';
}

class KlineAppearanceController {
  static final ValueNotifier<KlineAppearanceSettings> selected =
      ValueNotifier<KlineAppearanceSettings>(const KlineAppearanceSettings());

  static KlineAppearanceSettings get current => selected.value;

  static void setKlineColor(Color color) {
    selected.value = selected.value.copyWith(klineColor: color);
  }

  static void setKlineOpacity(double opacity) {
    selected.value = selected.value.copyWith(klineOpacity: opacity);
  }

  static void setChartBackgroundColor(Color color) {
    selected.value = selected.value.copyWith(chartBackgroundColor: color);
  }

  static void setAppThemeColor(Color color) {
    selected.value = selected.value.copyWith(appThemeColor: color);
  }

  static void reset() {
    selected.value = const KlineAppearanceSettings();
  }
}
