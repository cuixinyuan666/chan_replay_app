import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/four_way_granular_sidebar_shell.dart';
import 'ashare_bsp_scanner_page.dart';
import 'chan_settings_page.dart';
import 'chip_distribution_page.dart';
import 'kline_chart_page.dart';
import 'level_promoter_page.dart';
import 'research_backtest_page.dart';
import 'run_log_page.dart';
import 's8_strategy_batch_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const int _removedLegacyReplayIndex = 0;
  static const int _klineChartIndex = 1;
  static const int _settingsIndex = 6;

  late int _index;
  late final Set<int> _visited;

  static int get _initialRouteIndex {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _settingsIndex;
    }
    return _klineChartIndex;
  }

  @override
  void initState() {
    super.initState();
    _index = _initialRouteIndex;
    _visited = <int>{_index};
  }

  void _open(int index) {
    final target =
        index == _removedLegacyReplayIndex ? _klineChartIndex : index;
    if (_index == target) return;
    setState(() {
      _index = target;
      _visited.add(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FourWayGranularSidebarShell(
        selectedRouteIndex: _index,
        onOpenRoute: _open,
        additionalRegistrations: <SidebarRegistration>[
          SidebarRegistration(
            id: 'system-settings',
            label: '系统设置',
            category: '系统页面',
            icon: Icons.settings,
            edge: SidebarEdge.left,
            panelBuilder: (_) => const ChanSettingsPage(compactMode: true),
          ),
        ],
        child: _LazyRouteStack(
          index: _index,
          visited: _visited,
          builders: <_RouteBuilder>[
            const _RouteBuilder(child: SizedBox.shrink()),
            _RouteBuilder(
              child: KlineChartPage(
                currentRouteIndex: _index,
                onOpenRoute: _open,
              ),
            ),
            const _RouteBuilder(child: AshareBspScannerPage()),
            const _RouteBuilder(child: LevelPromoterPage()),
            const _RouteBuilder(child: S8StrategyBatchPage()),
            _RouteBuilder(child: ResearchBacktestPage(onOpenRoute: _open)),
            const _RouteBuilder(child: ChanSettingsPage()),
            const _RouteBuilder(child: RunLogPage()),
            const _RouteBuilder(child: ChipDistributionPage()),
          ],
        ),
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
