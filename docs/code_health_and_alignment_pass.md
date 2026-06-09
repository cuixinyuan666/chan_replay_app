# 代码健康与 Vespa 对齐检查记录

状态：已完成一次检查。

## 已完成的代码健康修复

1. `PythonChanAnalysisSource` 已将合并K线解析拆为两层：
   - `backendMergedBars`：后端真实返回字段，进入 `ChanSnapshot.mergedBars`；
   - `structuralMergedBars`：仅用于内部解析 `fx` / `bi` 锚点。

2. 该拆分避免 UI 把普通 K 线 fallback 误显示成合并K线，降低了前端显示层越界风险。

3. `PythonChanAnalysisSource` 已保留 Android MethodChannel、Windows 自动本地 Python 后端启动、HTTP backend fallback 等原有路径，没有改变 chan.py 计算入口。

## 已发现但未在本次强行大改的健康问题

`lib/ui/pages/origin_replay_page_v2.dart` 在前几次快速提交中有较多压缩成单行的 UI 代码。它目前仍可读性较差，后续应单独做一次纯格式化提交。

本次没有强行整文件重写该页面，原因是当前环境不能运行 `dart format` / `flutter analyze`，直接大规模手工重排 UI 文件风险高。

后续建议在本地执行：

```bash
flutter pub get
dart format lib/ui/pages/origin_replay_page_v2.dart lib/ui/widgets/origin_kline_chart.dart lib/data/python_chan_analysis_source.dart
flutter analyze
```

## Vespa 对齐颗粒度

对齐 Vespa/chan.py 的颗粒度不是在 Flutter 中复刻算法，而是以后端导出的结构字段作为前端最小显示单元：

- `bars`：原始K线；
- `merged_bars`：合并K线；
- `fx`：分型；
- `bi`：笔；
- `seg`：线段；
- `zs`：中枢；
- `bsp`：买卖点。

## 与 Vespa CChan 的关系

Vespa `CChan` 的 `step_load()` 以 `trigger_step` 为前提逐步加载并 yield snapshot；非 step 模式通过 `load()` 完整加载后再计算线段和中枢。

当前后端对齐方式：

- once：调用完整导出；
- step：调用 `step_load()`，每一帧导出同样的结构颗粒度；
- Flutter：只显示帧或完整 snapshot，不做推导。

## 不允许的前端行为

- 前端自行处理包含关系；
- 前端自行识别分型；
- 前端自行生成笔；
- 前端自行生成线段；
- 前端自行生成中枢；
- 前端自行判断买卖点；
- 前端用 fallback 伪造合并K线显示。

## 允许的前端行为

- 对后端字段做开关控制；
- 对后端字段做颜色、文字、大小、透明度区分；
- 不可用入口灰度禁用；
- 手动画线作为 `DrawingObject` 独立持久化，不混入缠论结构字段。
