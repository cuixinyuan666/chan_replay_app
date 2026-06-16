# 筹码分布阶段说明

Branch: `hichancmfb`

## completed_tasks

- 在 `RootPage` 中保留与“复盘”“单股多级别复盘”同级的既有“筹码分布”页面入口。
- 路由索引继续按追加原则处理，避免影响 S13 工具栏已有页面跳转。
- `lib/core/analysis/chip_distribution.dart` 继续作为独立筹码分布计算模块。
- `lib/core/analysis/chip_online_replay_adapter.dart` 只把在线 `analyze_multi` 返回的 `ChanSnapshot.rawBars` 转为筹码分布输入，不读取离线分笔文件。
- `lib/ui/widgets/s13_chip_distribution_panel.dart` 作为可嵌入 `S13SingleStockReplayPage` 主图 Stack 的筹码面板组件。
- `ChipDistributionPage` 已从 demo 数据切换为在线 `PythonMultiLevelChanAnalysisSource.analyzeMulti` 数据源。
- 筹码计算只消费目标 K 线及以前的数据：`bars.sublist(start, safeTarget + 1)`。
- 支持 `a_replay_trainer.py` 风格 `chip_tick_bins: {p,s,b,w}`：
  - `p` 为价格桶；
  - `s` 为卖侧成交量；
  - `b` 为买侧成交量；
  - `w` 为总成交量兼容字段；
  - 当只有 `w` 没有 `s/b` 时，把 `w` 按兼容逻辑归入 buy/right 侧。
- 新增 `ChipTargetResolver`，目标 K 选择优先级为：step 当前 K > 十字线 K > 视觉最右 K > 最后一根 K。
- 在线页面当前提供 step 帧选择和非 step 十字线目标选择；视觉最右 K 逻辑在没有十字线时生效。
- 页面展示卖侧/买侧筹码权重、平均成本、峰值价位、获利筹码比例。
- `test/chip_distribution_test.dart` 覆盖防未来、逐价优先、`p/s/b/w` 解析、`w` 兼容、目标 K 优先级、在线 snapshot 适配。
- `tools/validate_chip_distribution_page.py` 做低成本静态验收。
- `docs/chip_distribution_performance.md` 记录当前计算量、风险和优化路线。

## hichancmfb_delta

本分支针对“当前只是轻量级复刻，未完美复刻 a_replay_trainer.py 筹码分布”的缺口做了最小风险补齐：

- 审计结论：原有轻量版 `ChipDistributionBar.fromJson` 能解析 `chip_tick_bins`，但在线链路 `analyze_multi -> ChanSnapshot.rawBars -> ChipOnlineReplayAdapter -> S13ChipDistributionPanel` 没有真正保留逐价桶。
- `RawBar` 新增 `ChipTickBins chipTickBins`，默认空桶，避免破坏现有 OHLCV 调用方。
- `ChanSnapshotJsonParser._parseRawBar` 新增 `chip_tick_bins / chipTickBins` 解析，将后端逐价桶保留到 `RawBar`。
- `ChipOnlineReplayAdapter.fromSnapshot` 将 `RawBar.chipTickBins.total/sell/buy` 传入 `ChipDistributionBar`，使 S13 在线面板能真正优先消费 `p/s/b/w`。
- `S13ChipDistributionPanel` 增加“精确桶 x/y”覆盖指标，并把说明改为 `chip_tick_bins 优先，OHLCV 兜底`。
- 验证脚本新增 RawBar、JSON parser、adapter、S13 panel 的端到端字段保留检查。
- 单元测试新增“online replay adapter preserves backend chip_tick_bins from RawBar”，防止后续合并时再次退化为纯 OHLCV 轻量版。

## deliberate_non_goals

- 当前分支不读取离线分笔文件，不引入额外 I/O，不在 Flutter 侧重算缠论结构。
- 当前分支不移动 S13 大页面的核心复盘逻辑，只保留筹码面板开关、目标 K 选择和图层挂载。
- 当前分支不要求后端必须提供 `chip_tick_bins`；当在线数据源没有逐价桶时仍自动使用 OHLCV 三角分摊兜底。

## validation_commands

建议本地运行：

```bash
python tools/validate_chip_distribution_page.py
flutter test test/chip_distribution_test.dart
flutter analyze
```

## validation_result

- 远端已提交代码、组件、测试、验证脚本和说明文档。
- 当前环境不能运行 Flutter / Python 项目验证，由接收方统一运行。
- 代码层面保持 Flutter/Dart 不计算 FX / BI / SEG / ZS / BSP。
- 当前阶段明确不接入离线分笔文件。

## remaining_risk

- 当前已经完成“在线 analyze_multi -> rawBars -> chip_tick_bins -> 筹码分布”的字段保留链路。
- 如果后端没有真实逐笔或逐价 `chip_tick_bins`，S13 面板会显示“精确桶 0/N”，并回落到 OHLCV 估算。
- 若后续要进一步贴近 `a_replay_trainer.py` 的完整体验，可以在后端增加真实逐价桶导出、在 UI 增加成本集中度/压力支撑/区间筹码等指标，但应另开小分支实施，避免一次性大改 S13 页面。
