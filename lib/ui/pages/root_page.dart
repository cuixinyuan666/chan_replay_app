import 'package:flutter/material.dart';

import 'ashare_bsp_scanner_page.dart';
import 'chan_settings_page.dart';
import 'chip_distribution_page.dart';
import 'level_promoter_page.dart';
import 'research_backtest_page.dart';
import 'run_log_page.dart';
import 's8_strategy_batch_page.dart';
import 's13_single_stock_replay_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const int _removedLegacyReplayIndex = 0;
  static const int _multiLevelIndex = 1;
  static const int _settingsIndex = 6;

  int _index = _multiLevelIndex;
  bool _settingsOpen = false;
  final Set<int> _visited = <int>{_multiLevelIndex};

  void _closeSettings() {
    if (!_settingsOpen) return;
    setState(() => _settingsOpen = false);
  }

  void _open(int index) {
    final target =
        index == _removedLegacyReplayIndex ? _multiLevelIndex : index;
    if (target == _settingsIndex) {
      setState(() => _settingsOpen = !_settingsOpen);
      return;
    }
    if (_index == target && !_settingsOpen) return;
    setState(() {
      _settingsOpen = false;
      _index = target;
      _visited.add(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          _LazyRouteStack(
            index: _index,
            visited: _visited,
            builders: <_RouteBuilder>[
              const _RouteBuilder(child: SizedBox.shrink()),
              _RouteBuilder(
                child: S13SingleStockReplayPage(
                  currentRouteIndex: _index,
                  onOpenRoute: _open,
                ),
              ),
              const _RouteBuilder(child: AshareBspScannerPage()),
              const _RouteBuilder(child: LevelPromoterPage()),
              const _RouteBuilder(child: S8StrategyBatchPage()),
              const _RouteBuilder(child: ResearchBacktestPage()),
              const _RouteBuilder(child: ChanSettingsPage()),
              const _RouteBuilder(child: RunLogPage()),
              const _RouteBuilder(child: ChipDistributionPage()),
            ],
          ),
          if (_settingsOpen)
            Positioned.fill(
              child: ChanSettingsPage(
                overlayMode: true,
                onClose: _closeSettings,
              ),
            ),
        ],
      ),
    );
  }
}

class _RouteBuilder {
  final Widget child;
  const _RouteBuilder({required this.child});
}

class _LazyRouteStack extends StatelessWidget {
  final int index;
  final Set<int> visited;
  final List<_RouteBuilder> builders;

  const _LazyRouteStack({
    required this.index,
    required this.visited,
    required this.builders,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        for (var i = 0; i < builders.length; i++)
          Offstage(
            offstage: index != i,
            child: TickerMode(
              enabled: index == i,
              child: visited.contains(i)
                  ? KeyedSubtree(
                      key: ValueKey<String>('root-route-$i'),
                      child: builders[i].child,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
