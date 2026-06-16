# 筹码分布阶段说明

Branch: `hichanchoumafenbu`

## completed_tasks

- 在 `RootPage` 中新增与“复盘”“单股多级别复盘”同级的“筹码分布”页面入口。
- 修复路由索引隐患：保留原有 `复盘=0 / 单股多级别=1 / 扫描器=2 / S8批量候选=3 / 研究=4`，将 `筹码分布` 追加为 `5`，避免影响 S13 工具栏已有页面跳转。
- 新增 `lib/core/analysis/chip_distribution.dart`，作为独立筹码分布计算模块。
- 新增 `lib/core/analysis/chip_online_replay_adapter.dart`，只把在线 `analyze_multi` 返回的 `ChanSnapshot.rawBars` 转为筹码分布输入，不读取离线分笔文件。
- 新增 `lib/ui/widgets/s13_chip_distribution_panel.dart`，作为可嵌入 `S13SingleStockReplayPage` 主图 Stack 的筹码面板组件。
- 新增 `tools/apply_s13_chip_panel_patch.py`，用于在本地 checkout 对 1300+ 行 S13 大文件做受保护的小范围 patch：
  - 添加 `s13_chip_distribution_panel.dart` import；
  - 添加 `_showChipDistribution` 开关；
  - 在浮动工具栏添加筹码按钮；
  - 在 `_chartPanel` 的 Stack 内挂 `S13ChipDistributionPanel`。
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
- 新增 `docs/chip_distribution_performance.md` 记录当前计算量、风险和优化路线。

## apply_s13_panel

当前 GitHub 写入接口只能整文件替换，`S13SingleStockReplayPage` 又是 1300+ 行核心页。为避免误覆盖，已提交受保护 patch 脚本。接收方可在当前分支本地运行：

```bash
python tools/apply_s13_chip_panel_patch.py
flutter analyze
flutter test test/chip_distribution_test.dart
```

脚本会检查每个替换点只有 1 个匹配，匹配失败则直接退出，不会盲改。

## evidence_button

当前阶段没有新增 App 内复制按钮。接收方优先运行命令行验证：

```bash
python tools/validate_chip_distribution_page.py
python tools/apply_s13_chip_panel_patch.py
flutter test test/chip_distribution_test.dart
flutter analyze
```

## validation_result

- 远端已提交代码、组件、测试、验证脚本和 S13 patch helper。
- 当前环境不能运行 Flutter / Python 项目验证，由接收方统一运行。
- 代码层面保持 Flutter/Dart 不计算 FX / BI / SEG / ZS / BSP。
- 当前阶段明确不接入离线分笔文件。

## remaining_risk

- 当前已经完成“在线 analyze_multi -> rawBars -> 筹码分布”的真实在线数据链路。
- `S13ChipDistributionPanel` 已准备好嵌入 S13 主图 Stack；受限于远端整文件写入风险，S13 大文件本身通过本地 patch helper 应用。
- 主图 crosshair 已有 `_crosshairIndex` 状态；视觉最右 K 由 `_viewEndIndex ?? lastBar` 表示。若后续需要更精细的可见区间，可再从 `OriginKlineChart` 增加 `onVisibleRangeChanged(start,end)`。

## next_task

- 本地运行 `python tools/apply_s13_chip_panel_patch.py` 后提交生成的 S13 小范围 diff。
- 运行 `flutter analyze` 检查 import、clamp 类型和 Widget 参数。
- 根据实际 UI 体验决定是否给筹码面板增加缓存 / debounce。
