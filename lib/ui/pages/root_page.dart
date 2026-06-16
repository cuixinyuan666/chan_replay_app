import 'package:flutter/material.dart';

import '../widgets/unified_draggable_tool_menu.dart';
import 'ashare_bsp_scanner_page.dart';
import 'cache_optimization_page.dart';
import 'chan_settings_page.dart';
import 'chip_distribution_page.dart';
import 'origin_replay_strict_page.dart';
import 'research_backtest_page.dart';
import 's8_strategy_batch_page.dart';
import 's13_single_stock_replay_page.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const int _replayIndex = 0;
  static const int _multiLevelIndex = 1;
  static const int _scannerIndex = 2;
  static const int _s8BatchIndex = 3;
  static const int _researchIndex = 4;
  static const int _settingsIndex = 5;
  static const int _cacheOptimizationIndex = 6;
  static const int _chipDistributionIndex = 7;

  int _index = _multiLevelIndex;
  final Set<int> _visited = <int>{_multiLevelIndex};

  void _open(int index) {
    if (_index == index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
  }

  void _toggleChipDistributionWorkspace(bool enabled) {
    _open(enabled ? _chipDistributionIndex : _multiLevelIndex);
  }

  List<UnifiedToolMenuSection> get _unifiedToolSections =>
      <UnifiedToolMenuSection>[
        UnifiedToolMenuSection(
          title: '标的设置',
          icon: Icons.manage_search,
          description: '股票代码、市场、级别窗口与筹码入口',
          initiallyExpanded: true,
          groups: <UnifiedToolMenuGroup>[
            UnifiedToolMenuGroup(
              title: '单股工作台',
              icon: Icons.account_tree,
              initiallyExpanded: true,
              items: <UnifiedToolMenuItem>[
                const UnifiedToolMenuItem(
                  label: '单股多级别',
                  icon: Icons.account_tree,
                  routeIndex: _multiLevelIndex,
                  description: '主工作台：标的、周期、复盘、图层和图内筹码分布',
                ),
                UnifiedToolMenuItem(
                  label: '筹码分布工作台',
                  icon: Icons.stacked_bar_chart,
                  switchValue: _index == _chipDistributionIndex,
                  onSwitchChanged: _toggleChipDistributionWorkspace,
                  description: '开：独立筹码分布页；关：回到单股多级别主图',
                ),
                const UnifiedToolMenuItem(
                  label: '原始复盘',
                  icon: Icons.candlestick_chart,
                  routeIndex: _replayIndex,
                  description: '基础 K 线复盘入口，保留原始验收路径',
                ),
              ],
            ),
            const UnifiedToolMenuGroup(
              title: '扫描与批量',
              icon: Icons.radar,
              items: <UnifiedToolMenuItem>[
                UnifiedToolMenuItem(
                  label: '扫描器',
                  icon: Icons.radar,
                  routeIndex: _scannerIndex,
                  description: 'A 股买卖点扫描与候选定位',
                ),
                UnifiedToolMenuItem(
                  label: 'S8 批量候选',
                  icon: Icons.view_list,
                  routeIndex: _s8BatchIndex,
                  description: '批量候选与阶段性策略检查',
                ),
              ],
            ),
          ],
        ),
        const UnifiedToolMenuSection(
          title: '缠论设置',
          icon: Icons.tune,
          description: '算法参数、运行路径、缓存与全局配置',
          groups: <UnifiedToolMenuGroup>[
            UnifiedToolMenuGroup(
              title: '配置中心',
              icon: Icons.settings,
              initiallyExpanded: true,
              items: <UnifiedToolMenuItem>[
                UnifiedToolMenuItem(
                  label: '缠论设置',
                  icon: Icons.settings,
                  routeIndex: _settingsIndex,
                  description: '全局缠论参数与页面设置',
                ),
                UnifiedToolMenuItem(
                  label: '缓存优化',
                  icon: Icons.speed,
                  routeIndex: _cacheOptimizationIndex,
                  description: '会话缓存、payload 与性能诊断入口',
                ),
              ],
            ),
            UnifiedToolMenuGroup(
              title: '研究验证',
              icon: Icons.science,
              items: <UnifiedToolMenuItem>[
                UnifiedToolMenuItem(
                  label: '研究',
                  icon: Icons.science,
                  routeIndex: _researchIndex,
                  description: '回测、诊断与研究型验收入口',
                ),
              ],
            ),
          ],
        ),
        const UnifiedToolMenuSection(
          title: '缠论元素设置',
          icon: Icons.layers,
          description: '分型、笔、线段、中枢、买卖点和区间套证据',
          groups: <UnifiedToolMenuGroup>[
            UnifiedToolMenuGroup(
              title: '图层与证据',
              icon: Icons.hub,
              initiallyExpanded: true,
              items: <UnifiedToolMenuItem>[
                UnifiedToolMenuItem(
                  label: '多级别元素',
                  icon: Icons.account_tree,
                  routeIndex: _multiLevelIndex,
                  description: '分型、笔、线段、中枢、BSP、候选轨迹和区间套 marker',
                ),
                UnifiedToolMenuItem(
                  label: '图内筹码叠加',
                  icon: Icons.stacked_bar_chart,
                  enabled: false,
                  description: '根菜单未暴露直连接口；进入单股多级别后用图内工具栏开关',
                ),
                UnifiedToolMenuItem(
                  label: 'BSP 候选轨迹层',
                  icon: Icons.timeline,
                  enabled: false,
                  description: '当前仅在单股多级别图内工具栏提供真实开关',
                ),
                UnifiedToolMenuItem(
                  label: '节奏线 / 1.382 命中',
                  icon: Icons.show_chart,
                  enabled: false,
                  description: '当前仅在单股多级别图内工具栏提供真实开关',
                ),
                UnifiedToolMenuItem(
                  label: '批量候选',
                  icon: Icons.view_list,
                  routeIndex: _s8BatchIndex,
                  description: '批量查看候选买卖点与策略候选池',
                ),
              ],
            ),
          ],
        ),
        const UnifiedToolMenuSection(
          title: '画线 / 图形工具',
          icon: Icons.architecture,
          description: '画线工具、图层开关与对象导入导出',
          groups: <UnifiedToolMenuGroup>[
            UnifiedToolMenuGroup(
              title: '画线工作流',
              icon: Icons.edit_note,
              initiallyExpanded: true,
              items: <UnifiedToolMenuItem>[
                UnifiedToolMenuItem(
                  label: '进入单股画线环境',
                  icon: Icons.architecture,
                  routeIndex: _multiLevelIndex,
                  description: '进入单股多级别后，使用图内工具按钮打开画线工具箱',
                ),
                UnifiedToolMenuItem(
                  label: '直接打开画线面板',
                  icon: Icons.open_in_new,
                  enabled: false,
                  description: '根菜单到图内 openSignal 的直连控制器尚未接入，避免伪动作',
                ),
                UnifiedToolMenuItem(
                  label: '筹码分布适配',
                  icon: Icons.stacked_bar_chart,
                  routeIndex: _chipDistributionIndex,
                  description: '独立筹码页可用于核对成本峰、获利盘和目标 K 优先级',
                ),
              ],
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          _LazyRouteStack(
            index: _index,
            visited: _visited,
            builders: <_RouteBuilder>[
              const _RouteBuilder(child: OriginReplayStrictPage()),
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
          UnifiedDraggableToolMenu(
            currentIndex: _index,
            onOpen: _open,
            sections: _unifiedToolSections,
            initialOffset: const Offset(18, 118),
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
