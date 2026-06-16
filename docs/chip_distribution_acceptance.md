# 筹码分布阶段说明

Branch: `hichancmfb`

## completed_tasks

- 在 `RootPage` 中保留与“复盘”“单股多级别复盘”同级的既有“筹码分布”页面入口。
- 路由索引继续按追加原则处理，避免影响 S13 工具栏已有页面跳转。
- `lib/core/analysis/chip_distribution.dart` 继续作为独立筹码分布计算模块。
- `lib/core/analysis/chip_online_replay_adapter.dart` 只把在线 `analyze_multi` 返回的 `ChanSnapshot.rawBars` 转为筹码分布输入，不读取离线分笔文件。
- `ChipDistributionPage` 已从 demo 数据切换为在线 `PythonMultiLevelChanAnalysisSource.analyzeMulti` 数据源。
- `lib/ui/widgets/s13_chip_distribution_panel.dart` 已从独立右侧卡片改为 K 线主图内嵌 overlay：使用 `Positioned.fill + IgnorePointer + CustomPaint`，直接画在主图价格区域右侧，不拦截十字线、拖拽、画线工具。
- `S13ChipDistributionPanel` 已改为懒加载：只有用户打开筹码分布开关后才开始转换当前 active level 的 K 线并计算筹码；关闭时不计算、不绘制。
- S13 内嵌筹码默认区间为：当前级别 easy-tdx 首根可用 K 线 -> 当前显示截止 K。step 模式使用当前 step K；非 step 模式优先十字线，其次视觉最右 K。
- S13 内嵌筹码加载成功后会弹窗提示：`筹码分布的获取区间为: yyyy-MM-dd-yyyy-MM-dd`，并显示数据源与 K 线数量。
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
- `tools/validate_chip_distribution_page.py` 做低成本静态验收，并检查懒加载、easy-tdx 来源提示、加载成功弹窗、旧 286×360 卡片不回归。
- `docs/chip_distribution_performance.md` 记录当前计算量、风险和优化路线。

## hichancmfb_delta

本分支针对“当前只是轻量级复刻，未完美复刻 a_replay_trainer.py 筹码分布”的缺口做了最小风险补齐：

- 审计结论：原有轻量版 `ChipDistributionBar.fromJson` 能解析 `chip_tick_bins`，但在线链路 `analyze_multi -> ChanSnapshot.rawBars -> ChipOnlineReplayAdapter -> S13ChipDistributionPanel` 没有真正保留逐价桶。
- `RawBar` 新增 `ChipTickBins chipTickBins`，默认空桶，避免破坏现有 OHLCV 调用方。
- `ChanSnapshotJsonParser._parseRawBar` 新增 `chip_tick_bins / chipTickBins` 解析，将后端逐价桶保留到 `RawBar`。
- `ChipOnlineReplayAdapter.fromSnapshot` 将 `RawBar.chipTickBins.total/sell/buy` 传入 `ChipDistributionBar`，使 S13 在线筹码 overlay 能真正优先消费 `p/s/b/w`。
- `S13ChipDistributionPanel` 增加“精确桶 x/y”覆盖指标，并把说明改为 `chip_tick_bins 优先，OHLCV 兜底`。
- `S13ChipDistributionPanel` 当前不再返回固定宽高的 Material 卡片，而是返回 `Positioned.fill`；绘制器按 K 线主图价格坐标 `priceToY` 对齐筹码横条。
- `S13ChipDistributionPanel` 改为 StatefulWidget，通过 `_scheduleLazyLoad` 在用户打开筹码层后才懒计算当前 active level 筹码。
- 懒加载成功后通过 `showDialog<void>` 提示获取区间、easy-tdx 级别来源和 K 线数量。
- 验证脚本新增 RawBar、JSON parser、adapter、S13 overlay、懒加载、弹窗提示的端到端检查。
- 单元测试新增“online replay adapter preserves backend chip_tick_bins from RawBar”，防止后续合并时再次退化为纯 OHLCV 轻量版。

## deliberate_non_goals

- 当前分支不读取离线分笔文件，不引入额外 I/O，不在 Flutter 侧重算缠论结构。
- 当前分支不移动 S13 大页面的核心复盘逻辑，只保留筹码开关、目标 K 选择和图层挂载。
- 当前分支不要求后端必须提供 `chip_tick_bins`；当在线数据源没有逐价桶时仍自动使用 OHLCV 三角分摊兜底。
- 当前分支没有把筹码分布写入 `OriginKlineChart` 主绘图器内部，而是使用 S13 chart Stack 顶层 overlay，以降低与画线工具、指标副图、K 线主绘图器的合并冲突。
- 当前分支没有大改 S13 页面参数链去让 overlay 独立发起新的 `/api/tdx/kline` 请求；overlay 使用当前复盘已加载的 active level easy-tdx rawBars。

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

- 当前已经完成“在线 analyze_multi -> rawBars -> chip_tick_bins -> K 线图内筹码分布 overlay”的字段保留和显示链路。
- 如果后端没有真实逐笔或逐价 `chip_tick_bins`，S13 overlay 会显示“精确桶 0/N”，并回落到 OHLCV 估算。
- 当前“上市日”在 S13 overlay 中按当前级别 easy-tdx 首根可用 K 线解释；如果复盘本身只加载了较晚 startDate，则弹窗区间会反映当前 snapshot 的首根可用 K，而不是重新独立拉取真实上市日起全量 K。
- 若后续必须强制做到“无论复盘窗口如何设置，都独立从真实上市日起拉取筹码”，建议另开小补丁：把 symbol / market / activeLevel / backend baseUrl 传入 `S13ChipDistributionPanel`，让 overlay 独立请求 `/api/tdx/kline` 并缓存结果。
- 目前 overlay 默认按 S13 现有主图尺寸和价格缩放策略绘制；若后续要让副图数量、窗口大小、价格缩放完全由 `OriginKlineChart` 主绘图器直接传入，可再小范围扩展 `RecursiveSegOriginKlineChart` 参数。
- 若后续要进一步贴近 `a_replay_trainer.py` 的完整体验，可以在后端增加真实逐价桶导出、在 UI 增加成本集中度/压力支撑/区间筹码等指标，但应另开小分支实施，避免一次性大改 S13 页面。
