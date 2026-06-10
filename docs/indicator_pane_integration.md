# 指标副图接入说明

本分支的指标副图遵循以下边界：

```text
Python chan.py / backend 输出 indicators
Flutter 只消费 snapshot.indicators 绘图
Flutter 不计算 FX / BI / SEG / ZS / BSP
Flutter 不把指标、ML、回测结果写回 chan.py 结构
```

## 已完成组件

```text
lib/ui/widgets/origin_indicator_pane.dart
lib/ui/widgets/origin_indicator_pane_host.dart
```

当前支持：

1. `VOL` 副图：读取 `snapshot.indicators.vol`。
2. `MACD` 副图：读取 `snapshot.indicators.macd` 的 `dif / dea / hist`。
3. 与主图共享 `windowSize / viewEndIndex / crosshairIndex`。
4. crosshair 命中时显示当前 `VOL / DIF / DEA / HIST`。
5. `OriginIndicatorPaneHost` 负责主图区域与指标副图区域组合，页面接入时只需包裹现有主图。
6. 不在图面常驻堆叠指标数值。

## 组件测试

```text
test/origin_indicator_pane_test.dart
```

测试覆盖：

1. synthetic `ChanSnapshot + EasyTdxIndicators` 可构建 `OriginIndicatorPane`。
2. `VOL + MACD` 同时打开时 widget 可渲染且无 Flutter 异常。
3. `showVol=false / showMacd=false` 时副图折叠，不渲染 `CustomPaint`。

CI 已加入：

```bash
flutter test test/origin_indicator_pane_test.dart
```

## 展示边界审计

```text
tools/audit_indicator_pane_boundary.py
```

该脚本检查 `OriginIndicatorPane` 与 `OriginIndicatorPaneHost` 只能依赖展示模型，禁止引入旧 Dart 缠论算法引擎、backend、HTTP、MethodChannel、Python 运行期胶水和研究训练层字段。

独立 CI workflow：

```text
.github/workflows/indicator_pane_boundary.yml
```

运行：

```bash
python tools/audit_indicator_pane_boundary.py
```

## 页面接入补丁脚本

由于 `lib/ui/pages/origin_replay_page_v2.dart` 体量较大，页面接入通过确定性锚点补丁脚本完成。

先执行只读预检：

```bash
python tools/patch_origin_replay_indicator_panes.py --check-anchors
python tools/dry_run_origin_replay_indicator_panes.py
```

预检通过后再应用：

```bash
python tools/patch_origin_replay_indicator_panes.py
dart format lib/ui/pages/origin_replay_page_v2.dart lib/ui/widgets/origin_indicator_pane.dart lib/ui/widgets/origin_indicator_pane_host.dart
flutter analyze
python tools/patch_origin_replay_indicator_panes.py --check
```

补丁会做以下改动：

1. 在 `OriginReplayPageV2` 引入 `OriginIndicatorPaneHost`。
2. 增加 `_showVolPane / _showMacdPane` 状态。
3. 左侧工具栏增加 `VOL副图 / MACD副图` 开关。
4. 图层状态面板增加 `VOL / MACD` 数据量与显示状态。
5. `_buildChartPanel()` 中用 `OriginIndicatorPaneHost` 包裹现有 `OriginKlineChart`。

## CI 护栏

当前 GitHub Actions 已加入：

```bash
python tools/patch_origin_replay_indicator_panes.py --check-anchors
flutter test test/origin_indicator_pane_test.dart
```

另有独立 workflow：

```bash
python tools/audit_indicator_pane_boundary.py
```

`--check-anchors` 只检查补丁锚点是否仍存在或已被接入，不强制页面已经接入；目的是防止后续大文件改动导致补丁脚本失效。

## 后续验收

页面接入并 format 后，需要验证：

```bash
flutter analyze
python tools/audit_dart_algorithm_usage.py
python tools/audit_global_lazy_loading.py --strict
python tools/audit_indicator_pane_boundary.py
python tools/validate_easy_tdx_indicator_contract.py build/real_analysis.json
```

UI 验收重点：

1. VOL 副图默认可见，MACD 可开关。
2. 缩放、拖动、逐K时副图窗口与主图一致。
3. crosshair 垂线在主图与副图同 rawIndex。
4. 指标数值只在 crosshair / 顶部提示显示，不常驻堆叠在主图。
5. Android MethodChannel 与 Windows HTTP 返回同一指标合同结构。
