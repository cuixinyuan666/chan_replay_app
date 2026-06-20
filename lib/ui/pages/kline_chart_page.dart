import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => S13SingleStockReplayPage(
        currentRouteIndex: currentRouteIndex,
        onOpenRoute: onOpenRoute,
      );
}
