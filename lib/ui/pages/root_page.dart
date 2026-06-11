import 'package:flutter/material.dart';

import 'ashare_bsp_scanner_page.dart';
import 'multi_level_replay_page.dart';
import 'origin_replay_page_v2.dart';
import 'research_backtest_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const int _replayIndex = 0;
  static const int _multiLevelIndex = 1;
  static const int _scannerIndex = 2;
  static const int _researchIndex = 3;

  int _index = _replayIndex;
  final Set<int> _visited = {_replayIndex};

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
        children: [
          _LazyRouteStack(
            index: _index,
            visited: _visited,
            builders: const [
              _RouteBuilder(child: OriginReplayPageV2()),
              _RouteBuilder(child: MultiLevelReplayPage()),
              _RouteBuilder(child: AshareBspScannerPage()),
              _RouteBuilder(child: ResearchBacktestPage()),
            ],
          ),
          _RouteToolColumn(
            currentIndex: _index,
            onOpen: _open,
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
      children: [
        for (var i = 0; i < builders.length; i++)
          Offstage(
            offstage: index != i,
            child: TickerMode(
              enabled: index == i,
              child: visited.contains(i)
                  ? KeyedSubtree(
                      key: ValueKey('root-route-$i'),
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
    return Positioned(
      left: 3,
      bottom: 18,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RouteToolButton(
              tooltip: '复盘',
              icon: Icons.candlestick_chart,
              selected: currentIndex == _RootPageState._replayIndex,
              onPressed: () => onOpen(_RootPageState._replayIndex),
            ),
            const SizedBox(height: 6),
            _RouteToolButton(
              tooltip: '多级别',
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
              tooltip: '研究 / 回测',
              icon: Icons.science,
              selected: currentIndex == _RootPageState._researchIndex,
              onPressed: () => onOpen(_RootPageState._researchIndex),
            ),
          ],
        ),
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
            backgroundColor: selected
                ? const Color(0xFF2962FF)
                : const Color(0xEE131722),
            side: BorderSide(
              color: selected
                  ? const Color(0xFF8AB4FF)
                  : Colors.white.withValues(alpha: 0.10),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}
