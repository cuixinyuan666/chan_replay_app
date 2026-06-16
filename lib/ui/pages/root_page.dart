import 'package:flutter/material.dart';

import 'ashare_bsp_scanner_page.dart';
import 'cache_optimization_page.dart';
import 'chan_settings_page.dart';
import 'chip_distribution_page.dart';
import 'origin_replay_strict_page.dart';
import 'research_backtest_page.dart';
import 's8_strategy_batch_page.dart';
import 's13_single_stock_replay_page.dart';
import 'stock_selection_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const int _replayIndex = 0;
  static const int _multiLevelIndex = 1;
  static const int _scannerIndex = 2;
  static const int _stockSelectionIndex = 3;
  static const int _s8BatchIndex = 4;
  static const int _researchIndex = 5;
  static const int _settingsIndex = 6;
  static const int _cacheOptimizationIndex = 7;
  static const int _chipDistributionIndex = 8;

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
    final routes = <Widget>[
      const OriginReplayStrictPage(),
      S13SingleStockReplayPage(currentRouteIndex: _index, onOpenRoute: _open),
      const AshareBspScannerPage(),
      const StockSelectionPage(),
      const S8StrategyBatchPage(),
      const ResearchBacktestPage(),
      const ChanSettingsPage(),
      const CacheOptimizationPage(),
      const ChipDistributionPage(),
    ];
    return Scaffold(
      body: Stack(
        children: <Widget>[
          for (var i = 0; i < routes.length; i++)
            Offstage(
              offstage: _index != i,
              child: TickerMode(
                enabled: _index == i,
                child: _visited.contains(i)
                    ? KeyedSubtree(key: ValueKey<String>('root-route-$i'), child: routes[i])
                    : const SizedBox.shrink(),
              ),
            ),
          Positioned(
            left: 3,
            bottom: 18,
            child: Opacity(opacity: 0.18, child: _RouteToolColumn(currentIndex: _index, onOpen: _open)),
          ),
        ],
      ),
    );
  }
}

class _RouteToolColumn extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onOpen;

  const _RouteToolColumn({required this.currentIndex, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    const buttons = <_RouteSpec>[
      _RouteSpec('复盘', Icons.candlestick_chart, _RootPageState._replayIndex),
      _RouteSpec('单股多级别复盘', Icons.account_tree, _RootPageState._multiLevelIndex),
      _RouteSpec('扫描器', Icons.radar, _RootPageState._scannerIndex),
      _RouteSpec('选股', Icons.filter_alt, _RootPageState._stockSelectionIndex),
      _RouteSpec('S8批量候选', Icons.view_list, _RootPageState._s8BatchIndex),
      _RouteSpec('研究', Icons.science, _RootPageState._researchIndex),
      _RouteSpec('设置', Icons.settings, _RootPageState._settingsIndex),
      _RouteSpec('缓存优化', Icons.speed, _RootPageState._cacheOptimizationIndex),
      _RouteSpec('筹码分布', Icons.stacked_bar_chart, _RootPageState._chipDistributionIndex),
    ];
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in buttons) ...[
            _RouteToolButton(
              tooltip: item.tooltip,
              icon: item.icon,
              selected: currentIndex == item.index,
              onPressed: () => onOpen(item.index),
            ),
            if (item.index != buttons.last.index) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _RouteSpec {
  final String tooltip;
  final IconData icon;
  final int index;
  const _RouteSpec(this.tooltip, this.icon, this.index);
}

class _RouteToolButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _RouteToolButton({required this.tooltip, required this.icon, required this.selected, required this.onPressed});

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
            backgroundColor: selected ? const Color(0xFF2962FF) : const Color(0xEE131722),
            side: BorderSide(color: selected ? const Color(0xFF8AB4FF) : Colors.white24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}
