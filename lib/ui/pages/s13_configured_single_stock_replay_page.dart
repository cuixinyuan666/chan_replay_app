import 'package:flutter/material.dart';

import 's13_single_stock_replay_page.dart';

/// Transitional scaffold for the hichanshezhi branch.
///
/// The real S13 page remains [S13SingleStockReplayPage]. This wrapper exists so
/// follow-up wiring can switch the root route without touching unrelated pages.
class S13ConfiguredSingleStockReplayPage extends StatelessWidget {
  final int currentRouteIndex;
  final ValueChanged<int>? onOpenRoute;

  const S13ConfiguredSingleStockReplayPage({
    super.key,
    this.currentRouteIndex = 1,
    this.onOpenRoute,
  });

  @override
  Widget build(BuildContext context) {
    return S13SingleStockReplayPage(
      currentRouteIndex: currentRouteIndex,
      onOpenRoute: onOpenRoute,
    );
  }
}
