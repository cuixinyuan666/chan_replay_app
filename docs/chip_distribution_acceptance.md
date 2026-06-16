# 筹码分布阶段说明

Branch: `hichanchoumafenbu`

## completed_tasks

- 在 `RootPage` 中新增与“复盘”“单股多级别复盘”同级的“筹码分布”页面入口。
- 修复路由索引隐患：保留原有 `复盘=0 / 单股多级别=1 / 扫描器=2 / S8批量候选=3 / 研究=4`，将 `筹码分布` 追加为 `5`，避免影响 S13 工具栏已有页面跳转。
- 新增 `lib/core/analysis/chip_distribution.dart`，作为独立筹码分布计算模块。
- 新增 `lib/core/analysis/chip_online_replay_adapter.dart`，只把在线 `analyze_multi` 返回的 `ChanSnapshot.rawBars` 转为筹码分布输入，不读取离线分笔文件。
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
- 新增 `test/chip_distribution_test.dart` 覆盖防未来、逐价优先、`p/s/b/w` 解析、`w` 兼容、目标 K 优先级、在线 snapshot 适配。
- 新增 `tools/validate_chip_distribution_page.py` 做低成本静态验收。

## evidence_button

当前阶段没有新增 App 内复制按钮。接收方优先运行命令行验证：

```bash
python tools/validate_chip_distribution_page.py
flutter test test/chip_distribution_test.dart
flutter analyze
```

## validation_result

- 远端已提交代码和测试。
- 当前环境不能运行 Flutter / Python 项目验证，由接收方统一运行。
- 代码层面保持 Flutter/Dart 不计算 FX / BI / SEG / ZS / BSP。
- 当前阶段明确不接入离线分笔文件。

## remaining_risk

- 当前已经完成“在线 analyze_multi -> rawBars -> 筹码分布”的真实在线数据链路。
- 当前还没有把筹码面板嵌入 `S13SingleStockReplayPage` 主图区域内部，原因是为降低与 `hichan` 以及同级分支合并冲突，先保留为追加 route 和独立在线页面。
- 主图真实 crosshair / visible-right 状态尚未直接从 `OriginKlineChart` 透传到筹码面板；当前在线页用同一优先级规则和页面内状态模拟验证该逻辑。
- 如果下一阶段要统一集中到“单股多级别复盘”页，建议只引入 `ChipOnlineReplayAdapter` 和 `ChipDistributionEngine`，再在 S13 工具栏里挂一个可收起的筹码面板，避免改动主图绘制算法。

## next_task

- 在 `S13SingleStockReplayPage` 中增加可收起筹码面板，复用 `ChipOnlineReplayAdapter` 和 `ChipDistributionEngine`。
- 从 `OriginKlineChart` 增加 `onVisibleRangeChanged(start,end)` 或等价回调，用于真实视觉最右 K。
- 将主图 crosshair / step / visible-right 三个索引源统一传给筹码面板。
