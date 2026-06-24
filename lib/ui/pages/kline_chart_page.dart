import 'package:flutter/material.dart';

import '../../core/services/replay_analysis_store.dart';
import '../settings/kline_appearance_controller.dart';
import 'research_jump_kline_chart_page.dart';
import 's13_single_stock_replay_page.dart';

/// Unified K-line chart entry.
///
/// Normal chart/replay uses the S13 multi-level replay engine. Research result
/// jumps can carry a cached analyze_multi payload; those jumps are rendered by a
/// lightweight chart view to avoid reloading the same research/backtest data.
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
          child: ValueListenableBuilder<KlineLocationRequest?>(
            valueListenable: ReplayAnalysisStore.klineLocation,
            builder: (context, location, _) {
              final cachedJump = location?.analysisPayload != null;
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: ColoredBox(
                      color: appearance.chartBackgroundColor,
                      child: cachedJump
                          ? ResearchJumpKlineChartPage(request: location!)
                          : S13SingleStockReplayPage(
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
              );
            },
          ),
        );
      },
    );
  }
}
