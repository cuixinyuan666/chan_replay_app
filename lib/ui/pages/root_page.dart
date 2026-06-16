import 'package:flutter/material.dart';

import 'ashare_bsp_scanner_page.dart';
import 'cache_optimization_page.dart';
import 'chan_settings_page.dart';
import 'chip_distribution_page.dart';
import 'research_backtest_page.dart';
import 's8_strategy_batch_page.dart';
import 's13_single_stock_replay_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const int _multiLevelIndex = 0;
  static const int _scannerIndex = 1;
  static const int _s8BatchIndex = 2;
  static const int _researchIndex = 3;
  static const int _settingsIndex = 4;
  static const int _cacheOptimizationIndex = 5;
  static const int _chipDistributionIndex = 6;

  int _index = _multiLevelIndex;
  final Set<int> _visited = <int>{_multiLevelIndex};

  void _open(int index) {
    if (_index == index) return;
    setState(() {
      _index = index;
      _visited.add(index);
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
              _RouteBuilder(
                child: S13SingleStockReplayPage(
                  currentRouteIndex: _index,
                  onOpenRoute: _open,
                ),
              ),
              const _RouteBuilder(child: AshareBspScannerPage()),
              const _RouteBuilder(child: S8StrategyBatchPage()),
              const _RouteBuilder(child: ResearchBacktestPage()),
              const _RouteBuilder(child: ChanSettingsPage()),
              const _RouteBuilder(child: CacheOptimizationPage()),
              const _RouteBuilder(child: ChipDistributionPage()),
            ],
          ),
          Positioned(
            left: 3,
            bottom: 18,
            child: Opacity(
              opacity: 0.18,
              child: _RouteToolColumn(currentIndex: _index, onOpen: _open),
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

class _RouteToolColumn extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onOpen;

  const _RouteToolColumn({required this.currentIndex, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _RouteToolButton(
            tooltip: '单股多级别复盘',
            icon: Icons.account_tree,
            selected: currentIndex == _RootPageState._multiLevelIndex,
            onPressed: () => onOpen(_RootPageState._multiLevelIndex),
          ),
          const SizedBox(height: 6),
          _RouteToolButton(
            tooltip: '扫描器',
            icon: Icons.radar,
            selected: currentIndex == _RootPageState._scannerIndex,
            onPressed: () => onOpen(_RootPageState._scannerIndex),
          ),
          const SizedBox(height: 6),
          _RouteToolButton(
            tooltip: 'S8批量候选',
            icon: Icons.view_list,
            selected: currentIndex == _RootPageState._s8BatchIndex,
            onPressed: () => onOpen(_RootPageState._s8BatchIndex),
          ),
          const SizedBox(height: 6),
          _RouteToolButton(
            tooltip: '研究',
            icon: Icons.science,
            selected: currentIndex == _RootPageState._researchIndex,
            onPressed: () => onOpen(_RootPageState._researchIndex),
          ),
          const SizedBox(height: 6),
          _RouteToolButton(
            tooltip: '设置',
            icon: Icons.settings,
            selected: currentIndex == _RootPageState._settingsIndex,
            onPressed: () => onOpen(_RootPageState._settingsIndex),
          ),
          const SizedBox(height: 6),
          _RouteToolButton(
            tooltip: '缓存优化',
            icon: Icons.speed,
            selected: currentIndex == _RootPageState._cacheOptimizationIndex,
            onPressed: () => onOpen(_RootPageState._cacheOptimizationIndex),
          ),
          const SizedBox(height: 6),
          _RouteToolButton(
            tooltip: '筹码分布',
            icon: Icons.stacked_bar_chart,
            selected: currentIndex == _RootPageState._chipDistributionIndex,
            onPressed: () => onOpen(_RootPageState._chipDistributionIndex),
          ),
        ],
      ),
    );
  }
}

class _RouteToolButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _RouteToolButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 42,
        height: 38,
        child: IconButton(
          onPressed: selected ? null : onPressed,
          icon: Icon(icon, size: 19),
          color: selected ? Colors.white : Colors.white70,
          disabledColor: Colors.white,
          style: IconButton.styleFrom(
            backgroundColor:
                selected ? const Color(0xFF2962FF) : const Color(0xEE131722),
            side: BorderSide(
              color: selected ? const Color(0xFF8AB4FF) : Colors.white24,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}
