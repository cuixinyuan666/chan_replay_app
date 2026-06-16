# 筹码分布阶段说明

Branch: `hichanchoumafenbu`

## completed_tasks

- 在 `RootPage` 中新增与“复盘”“单股多级别复盘”同级的“筹码分布”页面入口。
- 新增 `lib/core/analysis/chip_distribution.dart`，作为独立筹码分布计算模块。
- 筹码计算只消费目标 K 线及以前的数据：`bars.sublist(start, safeTarget + 1)`。
- 支持 `a_replay_trainer.py` 风格 `chip_tick_bins: {p,s,b,w}`：
  - `p` 为价格桶；
  - `s` 为卖侧成交量；
  - `b` 为买侧成交量；
  - `w` 为总成交量兼容字段；
  - 当只有 `w` 没有 `s/b` 时，把 `w` 按兼容逻辑归入 buy/right 侧。
- 新增 `ChipTargetResolver`，目标 K 选择优先级为：step 当前 K > 十字线 K > 视觉最右 K > 最后一根 K。
- 页面展示卖侧/买侧筹码权重、平均成本、峰值价位、获利筹码比例。
- 新增 `test/chip_distribution_test.dart` 覆盖防未来、逐价优先、`p/s/b/w` 解析、`w` 兼容、目标 K 优先级。
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

## remaining_risk

- 当前页面已经对齐 `chip_tick_bins(p/s/b/w)` 的前端解析和分布计算，但还没有把真实后端 `analyze_multi` 的 `kline_all/chip_tick_bins` 数据接入页面。
- 仍需下一阶段让后端或数据源下发筹码底座，并让页面消费真实 K 线，而不是 demo K 线。
- 真实图表联动尚未完成：step、十字线、视觉最右 K 的索引源当前已抽象为 `ChipTargetResolver`，但还未与主图交互状态打通。

## next_task

- 在后端响应或 Dart parser 中补齐 `kline_all/chip_tick_bins` 输入链路。
- 将“筹码分布”页面从 demo 数据切换为真实 `analyze_multi` 结果。
- 与主图 step / crosshair / visible-right 索引联动。
