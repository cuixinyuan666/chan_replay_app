import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  bool _settingsOpen = false;
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

  void _closeSettings() {
    if (!_settingsOpen) return;
    setState(() => _settingsOpen = false);
  }

  void _open(int index) {
    final target =
        index == _removedLegacyReplayIndex ? _klineChartIndex : index;
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
          Positioned.fill(
            left: 54,
            child: Stack(
              children: <Widget>[
                _LazyRouteStack(
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
          ),
          _CascadingSideNavigation(
            selectedIndex: _settingsOpen ? _settingsIndex : _index,
            onOpen: _open,
          ),
        ],
      ),
    );
  }
}

class _NavLeaf {
  final String label;
  final IconData icon;
  final int routeIndex;

  const _NavLeaf(this.label, this.icon, this.routeIndex);
}

class _NavBranch {
  final String label;
  final IconData icon;
  final List<_NavLeaf> children;

  const _NavBranch(this.label, this.icon, this.children);
}

class _CascadingSideNavigation extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onOpen;

  const _CascadingSideNavigation({
    required this.selectedIndex,
    required this.onOpen,
  });

  @override
  State<_CascadingSideNavigation> createState() =>
      _CascadingSideNavigationState();
}

class _CascadingSideNavigationState extends State<_CascadingSideNavigation> {
  static const _branches = <_NavBranch>[
    _NavBranch('复盘分析', Icons.candlestick_chart, <_NavLeaf>[
      _NavLeaf('单股多级别复盘', Icons.account_tree, 1),
      _NavLeaf('扫描器', Icons.radar, 2),
      _NavLeaf('级别推进器', Icons.double_arrow, 3),
      _NavLeaf('S8 批量候选', Icons.view_list, 4),
    ]),
    _NavBranch('研究工具', Icons.science, <_NavLeaf>[
      _NavLeaf('研究', Icons.science_outlined, 5),
      _NavLeaf('筹码分布', Icons.stacked_bar_chart, 8),
    ]),
    _NavBranch('系统', Icons.settings, <_NavLeaf>[
      _NavLeaf('设置', Icons.tune, 6),
      _NavLeaf('运行日志', Icons.receipt_long, 7),
    ]),
  ];

  bool _open = false;
  int? _branchIndex;

  void _openRoot() => setState(() {
        _open = true;
        _branchIndex = null;
      });

  void _openBranch(int index) => setState(() {
        _open = true;
        _branchIndex = index;
      });

  void _close() => setState(() {
        _open = false;
        _branchIndex = null;
      });

  void _selectLeaf(_NavLeaf leaf) {
    widget.onOpen(leaf.routeIndex);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: _open ? 310 : 54,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: <Widget>[
            _rail(),
            if (_open)
              Positioned(
                left: 54,
                top: 0,
                bottom: 0,
                width: 256,
                child: _cascadePanel(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _rail() => Container(
        width: 54,
        decoration: const BoxDecoration(
          color: Color(0xF5131722),
          border: Border(right: BorderSide(color: Colors.white12)),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              IconButton(
                tooltip: _open ? '关闭导航' : '打开导航',
                onPressed: _open ? _close : _openRoot,
                icon: Icon(_open ? Icons.close : Icons.menu),
                color: const Color(0xFFFFD54F),
              ),
              const Divider(color: Colors.white12, height: 12),
              for (var i = 0; i < _branches.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: IconButton(
                    tooltip: _branches[i].label,
                    onPressed: () => _openBranch(i),
                    icon: Icon(_branches[i].icon),
                    color:
                        _branchContainsRoute(_branches[i], widget.selectedIndex)
                            ? const Color(0xFFFFD54F)
                            : Colors.white60,
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _cascadePanel() {
    final branch = _branchIndex == null ? null : _branches[_branchIndex!];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xF21C2330),
        border: Border(right: BorderSide(color: Colors.white12)),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Color(0x66000000), blurRadius: 18, offset: Offset(5, 0)),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              leading: branch == null
                  ? const Icon(Icons.apps, color: Color(0xFFFFD54F))
                  : IconButton(
                      tooltip: '返回上一级',
                      onPressed: _openRoot,
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white70,
                    ),
              title: Text(branch?.label ?? '页面导航',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              trailing: IconButton(
                tooltip: '收起导航',
                onPressed: _close,
                icon: const Icon(Icons.chevron_left),
                color: Colors.white54,
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: branch == null
                    ? <Widget>[
                        for (var i = 0; i < _branches.length; i++)
                          ListTile(
                            leading:
                                Icon(_branches[i].icon, color: Colors.white70),
                            title: Text(_branches[i].label,
                                style: const TextStyle(color: Colors.white70)),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.white38),
                            onTap: () => _openBranch(i),
                          ),
                      ]
                    : <Widget>[
                        for (final leaf in branch.children)
                          ListTile(
                            selected: widget.selectedIndex == leaf.routeIndex,
                            selectedTileColor: const Color(0x332962FF),
                            leading: Icon(leaf.icon,
                                color: widget.selectedIndex == leaf.routeIndex
                                    ? const Color(0xFF8AB4FF)
                                    : Colors.white60),
                            title: Text(leaf.label,
                                style: TextStyle(
                                    color:
                                        widget.selectedIndex == leaf.routeIndex
                                            ? const Color(0xFF8AB4FF)
                                            : Colors.white70)),
                            trailing: widget.selectedIndex == leaf.routeIndex
                                ? const Icon(Icons.check,
                                    size: 17, color: Color(0xFF8AB4FF))
                                : null,
                            onTap: () => _selectLeaf(leaf),
                          ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _branchContainsRoute(_NavBranch branch, int route) =>
      branch.children.any((leaf) => leaf.routeIndex == route);
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
