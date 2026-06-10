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
```

当前支持：

1. `VOL` 副图：读取 `snapshot.indicators.vol`。
2. `MACD` 副图：读取 `snapshot.indicators.macd` 的 `dif / dea / hist`。
3. 与主图共享 `windowSize / viewEndIndex / crosshairIndex`。
4. crosshair 命中时显示当前 `VOL / DIF / DEA / HIST`。
5. 不在图面常驻堆叠指标数值。

## 页面接入补丁脚本

由于 `lib/ui/pages/origin_replay_page_v2.dart` 体量较大，页面接入通过确定性锚点补丁脚本完成：

```bash
python tools/patch_origin_replay_indicator_panes.py --check-anchors
python tools/patch_origin_replay_indicator_panes.py
dart format lib/ui/pages/origin_replay_page_v2.dart lib/ui/widgets/origin_indicator_pane.dart
flutter analyze
python tools/patch_origin_replay_indicator_panes.py --check
```

补丁会做以下改动：

1. 在 `OriginReplayPageV2` 引入 `OriginIndicatorPane`。
2. 增加 `_showVolPane / _showMacdPane` 状态。
3. 左侧工具栏增加 `VOL副图 / MACD副图` 开关。
4. 图层状态面板增加 `VOL / MACD` 数据量与显示状态。
5. `_buildChartPanel()` 改为主图 + 指标副图的 `Column` 布局。

## CI 护栏

当前 GitHub Actions 已加入：

```bash
python tools/patch_origin_replay_indicator_panes.py --check-anchors
```

该步骤只检查补丁锚点是否仍存在或已被接入，不强制页面已经接入；目的是防止后续大文件改动导致补丁脚本失效。

## 后续验收

页面接入并 format 后，需要验证：

```bash
flutter analyze
python tools/audit_dart_algorithm_usage.py
python tools/audit_global_lazy_loading.py --strict
python tools/validate_easy_tdx_indicator_contract.py build/real_analysis.json
```

UI 验收重点：

1. VOL 副图默认可见，MACD 可开关。
2. 缩放、拖动、逐K时副图窗口与主图一致。
3. crosshair 垂线在主图与副图同 rawIndex。
4. 指标数值只在 crosshair / 顶部提示显示，不常驻堆叠在主图。
5. Android MethodChannel 与 Windows HTTP 返回同一指标合同结构。
