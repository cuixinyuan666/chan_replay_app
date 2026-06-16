# 筹码分布阶段说明

Branch: `hichancmfb`

## completed_tasks

- 在 `RootPage` 中保留与“复盘”“单股多级别复盘”同级的既有“筹码分布”页面入口。
- 路由索引继续按追加原则处理，避免影响 S13 工具栏已有页面跳转。
- `lib/core/analysis/chip_distribution.dart` 继续作为独立筹码分布计算模块。
- `lib/core/analysis/chip_online_replay_adapter.dart` 只把在线 `analyze_multi` 返回的 `ChanSnapshot.rawBars` 转为筹码分布输入，不读取离线分笔文件。
- `ChipDistributionPage` 已从 demo 数据切换为在线 `PythonMultiLevelChanAnalysisSource.analyzeMulti` 数据源。
- S13 筹码分布改为懒加载：只有用户打开筹码分布开关后才开始请求和计算；关闭时不请求、不计算，并清理当前图表上下文的筹码绘制结果。
- S13 筹码分布已从“消费当前复盘窗口 rawBars”升级为“独立请求 `/api/tdx/kline`”：
  - 请求参数使用 `symbol / market / period / adjust / count / end`；
  - `count` 默认足够大，当前为 `200000`；
  - `end` 使用当前显示截止 K 的日期；
  - 有效区间为 easy-tdx 返回的首根可用 K / 上市首根可得 K -> 当前显示截止 K。
- S13 筹码加载成功后弹窗提示：`筹码分布的获取区间为: yyyy-MM-dd-yyyy-MM-dd`，并显示数据源与 K 线数量。
- S13 筹码不再由 `S13ChipDistributionPanel` 的 sibling `CustomPaint` overlay 绘制。当前绘制链路为：
  - `S13ChipDistributionPanel` 只负责懒加载、计算、弹窗和状态 badge；
  - `S13ChipDistributionStore` 持有 `S13ChipDistributionSpec`；
  - `RecursiveSegOriginKlineChart` 把筹码分布 bin 转换成锁定的 `DrawingObject.rectangle`；
  - `OriginKlineChart` 在 `_OriginChartPainter.paint()` 中通过 `DrawingObjectPainter.paintObjects(...)` 绘制这些对象。
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
- `tools/validate_chip_distribution_page.py` 做低成本静态验收，并检查独立 easy-tdx 拉取、首个可得 K 到截止 K、加载成功弹窗、Origin 主绘制链注入、旧 sibling chip painter 不回归。
- `docs/chip_distribution_performance.md` 记录当前计算量、风险和优化路线。

## hichancmfb_delta

本分支针对“当前只是轻量级复刻，未完美复刻 a_replay_trainer.py 筹码分布”的缺口做了补齐：

- 审计结论：原有轻量版 `ChipDistributionBar.fromJson` 能解析 `chip_tick_bins`，但在线链路 `analyze_multi -> ChanSnapshot.rawBars -> ChipOnlineReplayAdapter -> S13ChipDistributionPanel` 没有真正保留逐价桶。
- `RawBar` 新增 `ChipTickBins chipTickBins`，默认空桶，避免破坏现有 OHLCV 调用方。
- `ChanSnapshotJsonParser._parseRawBar` 新增 `chip_tick_bins / chipTickBins` 解析，将后端逐价桶保留到 `RawBar`。
- `ChipOnlineReplayAdapter.fromSnapshot` 将 `RawBar.chipTickBins.total/sell/buy` 传入 `ChipDistributionBar`，使在线筹码能真正优先消费 `p/s/b/w`。
- `EasyTdxKlineSource.loadListingChipBars` 新增独立筹码 K 线加载能力，直接调用 `/api/tdx/kline`，并使用 `period` 参数对齐后端接口。
- `S13ChipDistributionPanel` 改为状态控制器，不再承载筹码横条绘制；它负责根据目标 K 的 cutoff 独立拉取 easy-tdx K 线、计算筹码、发布绘制 spec、弹窗提示区间。
- `S13ChipDistributionStore` 新增跨组件绘制 spec 传递能力，避免大改 S13 页面参数链。
- `RecursiveSegOriginKlineChart` 监听筹码 spec，把筹码 bin 转换为锁定的 `DrawingObject.rectangle`，并传入 `OriginKlineChart.drawingObjects`。
- 筹码横条现在进入 `OriginKlineChart` 主绘制链：`_OriginChartPainter.paint()` -> `DrawingObjectPainter.paintObjects(...)`。
- 验证脚本新增 easy-tdx 独立拉取、listing/first-available 区间、Origin 主绘制链、禁止旧 `_ChipOverlayPainter` 的端到端检查。
- 单元测试保留“online replay adapter preserves backend chip_tick_bins from RawBar”，防止后续合并时再次退化为纯 OHLCV 轻量版。

## deliberate_non_goals

- 当前分支不读取离线分笔文件，不引入额外离线 I/O，不在 Flutter 侧重算缠论结构。
- 当前分支不移动 S13 大页面的核心复盘逻辑，只保留筹码开关、目标 K 选择和图层挂载。
- 当前分支不要求后端必须提供 `chip_tick_bins`；当 `/api/tdx/kline` 没有逐价桶时仍自动使用 OHLCV 三角分摊兜底。
- 当前分支没有把 `OriginKlineChart` 改成筹码专用 painter API，而是复用其既有 `DrawingObjectPainter.paintObjects(...)` 主绘制通道。这满足“由 OriginKlineChart 主 painter 绘制”，同时避免对 1700+ 行核心 K 线绘制器做高冲突重构。

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

- 当前已经完成“独立 `/api/tdx/kline` -> 首个可得 K 到显示截止 K -> 筹码计算 -> Origin 主绘制链”的链路。
- 如果后端没有真实逐笔或逐价 `chip_tick_bins`，S13 筹码会显示精确桶覆盖不足，并回落到 OHLCV 估算。
- 当前 `OriginKlineChart` 绘制方式是把筹码 bin 映射为锁定 rectangle drawing objects；如果后续希望完全专用的 `_drawChipDistribution(...)` 方法，可在确认 UI 效果稳定后再做小重构。
- 目前筹码条宽度按目标 K 往左映射为若干 rawIndex span，属于主 painter 坐标系统内绘制；如果后续需要固定屏幕像素宽度的右侧筹码栏，可以再扩展 `OriginKlineChart` 的 painter 参数。
- 若后续要进一步贴近 `a_replay_trainer.py` 的完整体验，可以在后端增加真实逐价桶导出、在 UI 增加成本集中度/压力支撑/区间筹码等指标，但应另开小分支实施，避免一次性大改 S13 页面。
