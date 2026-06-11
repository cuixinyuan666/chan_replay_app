# 多级别与区间套任务进度

分支：`origin_vespa_tdx`

## 当前目标

把当前单级别复盘 App 逐步升级为：

```text
多级别联动复盘 + 严格逐K + 区间套识别 + 训练 + 统计 + 选股 + 报告
```

本阶段遵守当前分支边界：

```text
Python chan.py 是唯一缠论结构计算源。
Flutter 只做 JSON 解析、模型承载、绘图、交互和研究入口。
不在 Flutter 生产链路复刻 FX / BI / SEG / ZS / BSP 结构算法。
```

## 已完成提交

### 1. 架构与接口契约

```text
commit: b14310c18e53bc647e2e21c1c9c15d43190ef7cb
file: docs/multilevel_interval_nest_plan.md
```

完成：定义多级别总目标、`POST /api/chan/analyze_multi` 契约、`levels / relations / frames / meta` 返回结构、16 个目标功能与 MVP 验收路线。

### 2. Flutter 多级别基础模型

```text
commit: 294292aa4e057af1f40b858792dc97f8c28756af
file: lib/core/models/level_relation.dart

commit: dcd3570c40d988e107e1f472910fd2edaf2621f0
file: lib/core/models/multi_level_chan_snapshot.dart

commit: 2bda4c3ef636e047c6c234ff2f208932003a1338
file: lib/core/models/replay_clock_mode.dart

commit: 26a78c7968affb9459dce57f631f83e49e747add
file: lib/core/models/signal_visibility_state.dart

commit: 7fa905c032bdd96f82f9130172178958ac112004
file: lib/core/models/interval_nest_signal.dart

commit: e3ac134e4a08023f7ecec2557edf701695d75770
file: lib/core/models/multi_level_chan_snapshot.dart
```

完成：LevelRelation、MultiLevelChanSnapshot、ReplayClockMode、SignalVisibilityState、IntervalNestSignal 以及 MultiLevelChanSnapshot 安全修正。

### 3. Flutter 多级别解析与客户端

```text
commit: 59c9abb363e4e196c8fecf0656bb79a616892dfa
file: lib/data/multi_level_chan_analysis_parser.dart

commit: 2a87332b69e2eee1d08b86f0bcf204290222e416
file: lib/data/chan_snapshot_json_parser.dart

commit: b44442e2897b639879942f49673e3d31bd82dfdd
file: lib/data/python_multi_level_chan_analysis_source.dart
```

完成：多级别 JSON 解析、公共 ChanSnapshot JSON 解析、独立 analyze_multi 客户端。

限制：尚未接入 Windows 自动后台启动本地 Python 服务，尚未接入 Android MethodChannel，尚未替换现有 PythonChanAnalysisSource。

### 4. 后端 analyze_multi 安全桥接版

```text
commit: ee2d039f3fa28e46226a5f0e26d74cfc84ffb1ea
file: backend/app/a_multilevel_engine.py
```

完成：新增 analyze_multi 后端引擎函数，返回 `levels / relations / frames / meta`，每个级别复用现有单级别 `chanpy_engine.analyze_once`。

重要限制：当前是安全桥接版，不是原生 `CChan(lv_list=[...])`；`meta.native_cchan_lv_list=false`；relations 当前为 `time_date_bridge`。

### 5. FastAPI 路由接入

```text
commit: 1ded7ed6edd47267c7fd5856f504de4cfe341433
file: backend/app/main.py
```

完成：新增 `POST /api/chan/analyze_multi`，根接口列表加入 `/api/chan/analyze_multi`，并保持 `/api/chan/analyze` 与 `/api/chan/analyze_bars` 不变。

### 6. analyze_multi 冒烟测试文档

```text
commit: 8ef4a6a26c9ee7865fed86ff98893e908e9f6230
file: docs/analyze_multi_smoke_test.md
```

完成：记录 once/step 请求体、响应字段检查点、当前安全桥接版边界、Flutter 侧已具备与未接入内容。

### 7. Flutter 多级别 UI 基础组件

```text
commit: 8b15d903489e2d4debab66ef408ce185addfd8ab
file: lib/ui/widgets/multi_level_switcher.dart

commit: ba614e065ff1fbed7ed9c939a64db45bce7caddc
file: lib/ui/widgets/multi_level_layer_status_panel.dart

commit: 6def2a24a42a607b630780f102285c347a1e3041
file: lib/core/models/multi_level_view_state.dart
```

完成：新增 MultiLevelSwitcher、MultiLevelLayerStatusPanel、MultiLevelViewState。

限制：基础组件本身不改变现有复盘页面行为。

### 8. 受控多级别复盘入口页

```text
commit: adc92953f876bc33301fdfbe52b1f6534c627979
file: lib/ui/pages/multi_level_replay_page.dart
```

完成：

```text
- 新增 MultiLevelReplayPage。
- 使用 PythonMultiLevelChanAnalysisSource 请求 /api/chan/analyze_multi。
- 支持后端 URL、symbol、market、lv_list、mode、count 输入。
- 接入 MultiLevelSwitcher。
- 接入 MultiLevelLayerStatusPanel。
- 接入 OriginKlineChart 显示当前 activeLevel 的 ChanSnapshot。
```

限制：

```text
- 当前是精简验证页。
- step 模式暂时只加载结果，尚未添加 frame 播放控制。
- CSV 模式、Android MethodChannel、Windows 自动本地服务暂未接入。
```

### 9. RootPage 增加多级别入口

```text
commit: 63ee497411132f59c03a659a549b1e4c82683ba4
file: lib/ui/pages/root_page.dart
```

完成：

```text
- RootPage 增加 MultiLevelReplayPage lazy route。
- 左下工具栏新增“多级别”按钮。
- 原复盘页仍为默认 index 0。
- 原扫描器、研究/回测入口仍保留。
- OriginReplayPageV2 未修改。
```

## 当前完成度

```text
阶段 0：架构文档与接口契约                    已完成
阶段 1A：Flutter 多级别基础模型                已完成
阶段 1B：多级别 JSON 解析器                    已完成
阶段 1C：独立 analyze_multi 客户端              已完成（未接自动本地服务）
阶段 2：后端 analyze_multi 安全桥接版           已完成（非原生 CChan lv_list）
阶段 2B：原生 CChan(lv_list) 多级别关系          未完成
阶段 3A：Flutter 多级别 UI 基础组件             已完成
阶段 3B：受控多级别页面入口                    已完成（独立页面，不替换原复盘页）
阶段 3C：原复盘页内联多级别模式                未完成
阶段 4：高级别定位低级别区间                  未完成
阶段 5：多级别严格逐K                         部分完成（后端 frames；UI 播放控件未接）
阶段 6：区间套信号引擎                        未完成
阶段 7：评分、交易计划、训练、统计、选股       未完成
```

## 当前代码影响范围

新增：

```text
docs/multilevel_interval_nest_plan.md
docs/multilevel_interval_nest_progress.md
docs/analyze_multi_smoke_test.md
lib/core/models/level_relation.dart
lib/core/models/multi_level_chan_snapshot.dart
lib/core/models/multi_level_view_state.dart
lib/core/models/replay_clock_mode.dart
lib/core/models/signal_visibility_state.dart
lib/core/models/interval_nest_signal.dart
lib/data/multi_level_chan_analysis_parser.dart
lib/data/chan_snapshot_json_parser.dart
lib/data/python_multi_level_chan_analysis_source.dart
lib/ui/pages/multi_level_replay_page.dart
lib/ui/widgets/multi_level_switcher.dart
lib/ui/widgets/multi_level_layer_status_panel.dart
backend/app/a_multilevel_engine.py
```

修改：

```text
backend/app/main.py
lib/ui/pages/root_page.dart
```

尚未修改：

```text
lib/data/python_chan_analysis_source.dart
lib/ui/pages/origin_replay_page_v2.dart
lib/ui/widgets/origin_kline_chart.dart
python/app_engine.py
python/chan.py
```

## 当前必须验证

现在已经新增了可见 UI 入口，因此需要本地验证：

```text
flutter analyze
flutter run
```

验证重点：

```text
1. App 是否能正常启动。
2. 左下工具栏是否出现“多级别”按钮。
3. 点击“多级别”是否进入 MultiLevelReplayPage。
4. 后端启动后点击 Load 是否能请求 /api/chan/analyze_multi。
5. DAILY / MIN30 / MIN5 切换是否能显示不同级别 K 线。
6. 右侧多级别图层状态是否显示各级别数量。
7. 原“复盘”页面是否仍保持原行为。
```

## 下一步任务

### 下一步 1：根据 flutter run 结果修正编译或布局问题

目标：

```text
先保证新增页面可运行，再继续加功能。
```

### 下一步 2：MultiLevelReplayPage 增加 step frame 控制

目标：

```text
mode=step 时显示 cursor slider。
支持上一帧 / 下一帧。
右侧图层状态显示 当前/全量。
```

### 下一步 3：高级别定位低级别区间

目标：

```text
利用 LevelRelation 实现点击高级别 K/BI/ZS/BSP 后定位低级别范围。
```

### 下一步 4：原生 CChan(lv_list) 升级

目标：

```text
使用 chan.py 原生多级别对象关系。
从 parent_klu / sub_kl_list 生成精确 relations。
替换当前 time_date_bridge。
```

## 风险记录

```text
1. GitHub contents API 每次 create_file/update_file 会直接在远端分支产生提交，不是本地暂存后统一 push。
2. 当前 analyze_multi 是安全桥接版，结构计算仍来自 chan.py，但多级别关系不是原生 CChan lv_list。
3. Windows 自动启动本地 Python 和 Android MethodChannel 多级别调用仍未接入新页面。
4. MultiLevelReplayPage 是新入口页，但尚未经过 flutter analyze / flutter run。
5. 原复盘页未修改；若新页面有问题，应优先修新页面，不影响原复盘流程。
```
