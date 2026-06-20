import 'package:flutter/material.dart';

import '../settings/kline_appearance_controller.dart';
import 's13_single_stock_replay_page.dart';

/// Unified K-line chart entry.
///
/// The implementation currently reuses the S13 multi-level replay engine and
/// chart widgets, but route callers should depend on this page instead of the
/// S13-specific page name. This keeps future chart-only, replay, scan-result,
/// and research jumps converged on one K-line entry point.
class KlineChartPage extends StatelessWidget {
  final int currentRouteIndex;
  final ValueChanged<int>? onOpenRoute;

  const KlineChartPage({
    super.key,
    this.currentRouteIndex = 1,
    this.onOpenRoute,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<KlineAppearanceSettings>(
      valueListenable: KlineAppearanceController.selected,
      builder: (context, appearance, _) {
        final baseTheme = Theme.of(context);
        final themed = baseTheme.copyWith(
          scaffoldBackgroundColor: appearance.chartBackgroundColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: appearance.appThemeColor,
            brightness: Brightness.dark,
          ),
          sliderTheme: baseTheme.sliderTheme.copyWith(
            activeTrackColor: appearance.appThemeColor,
            thumbColor: appearance.appThemeColor,
          ),
        );
        return Theme(
          data: themed,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ColoredBox(
                  color: appearance.chartBackgroundColor,
                  child: S13SingleStockReplayPage(
                    currentRouteIndex: currentRouteIndex,
                    onOpenRoute: onOpenRoute,
                  ),
                ),
              ),
              if (appearance.klineOpacity > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: appearance.klineColor.withValues(
                          alpha: appearance.klineOpacity,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
