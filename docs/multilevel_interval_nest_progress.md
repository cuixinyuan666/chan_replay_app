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

完成：LevelRelation、MultiLevelChanSnapshot、ReplayClockMode、SignalVisibilityState、IntervalNestSignal 以及 MultiLevelChanSnapshot 安全修正。

### 3. Flutter 多级别解析与客户端

完成：多级别 JSON 解析、公共 ChanSnapshot JSON 解析、独立 analyze_multi 客户端。

### 4. 后端 analyze_multi 安全桥接版

```text
commit: ee2d039f3fa28e46226a5f0e26d74cfc84ffb1ea
file: backend/app/a_multilevel_engine.py
```

完成：新增 analyze_multi 后端引擎函数，返回 `levels / relations / frames / meta`，每个级别复用现有单级别 `chanpy_engine.analyze_once`。

重要限制：

```text
当前是安全桥接版，不是原生 CChan(lv_list=[...])。
这是 review 中指出的核心问题，需要作为 Phase 2B 阻塞项修正。
当前 meta.native_cchan_lv_list=false。
当前 relations 为 time_date_bridge。
不能把该版本视为最终区间套关系来源。
```

### 5. FastAPI 路由接入

完成：新增 `POST /api/chan/analyze_multi`，根接口列表加入 `/api/chan/analyze_multi`，并保持 `/api/chan/analyze` 与 `/api/chan/analyze_bars` 不变。

### 6. analyze_multi 冒烟测试文档

完成：记录 once/step 请求体、响应字段检查点、当前安全桥接版边界、Flutter 侧已具备与未接入内容。

### 7. Flutter 多级别 UI 基础组件

完成：新增 MultiLevelSwitcher、MultiLevelLayerStatusPanel、MultiLevelViewState。

### 8. 受控多级别复盘入口页

完成：新增 MultiLevelReplayPage，接入独立多级别 source、级别切换、图层状态面板和 OriginKlineChart。

### 9. RootPage 增加多级别入口

完成：RootPage 增加 MultiLevelReplayPage lazy route，左下工具栏新增“多级别”按钮，原复盘页仍为默认 index 0。

### 10. 多级别 source 启动逻辑对齐复盘页

```text
commit: c3ec762bff85f65b44abb71cc01c7465664b2142
file: lib/data/python_multi_level_chan_analysis_source.dart
```

修复问题：

```text
点击“多级别 -> Load”时，如果 127.0.0.1:8000 没有后端服务，会出现：
ClientException with SocketException: 远程计算机拒绝网络连接。
```

完成：

```text
- 多级别 source 增加 localhost /health 兼容检查。
- localhost 服务不可用时，Windows 自动启动内置 python/app_engine.py。
- localhost 是旧服务或缺少 /api/chan/analyze_multi 时，自动 fallback 到内置服务。
- 增加 SocketException / errno=1225 / 中文“拒绝连接”匹配。
- close() 会关闭自动启动的本地 Python 进程。
```

限制：

```text
- Android MethodChannel 多级别调用仍未实现。
- Windows 自动启动依赖 python/python.exe 和 python/app_engine.py 存在。
```

## 当前完成度

```text
阶段 0：架构文档与接口契约                    已完成
阶段 1A：Flutter 多级别基础模型                已完成
阶段 1B：多级别 JSON 解析器                    已完成
阶段 1C：独立 analyze_multi 客户端              已完成
阶段 1D：多级别 source 启动逻辑对齐复盘页        已完成（Windows）
阶段 2：后端 analyze_multi 安全桥接版           已完成，但不是最终版
阶段 2B：原生 CChan(lv_list) 多级别关系          未完成，当前为阻塞项
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
lib/data/python_multi_level_chan_analysis_source.dart
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

现在需要重新本地验证：

```text
flutter analyze
flutter run
```

验证重点：

```text
1. 点击“多级别 -> Load”时，如果没有手动启动后端，是否会自动启动内置 Python 服务。
2. 是否不再出现 127.0.0.1:8000 connection refused。
3. 多级别页面是否能拿到 analyze_multi 响应。
4. DAILY / MIN30 / MIN5 切换是否正常。
5. 原“复盘”页面是否仍保持原行为。
```

## 老板 review 结论

老板指出的两个问题成立：

```text
1. 当前后端不是 chan.py 原生多级别 lv_list 实现。
2. 当前是多个单级别 analyze_once + 时间桥接 relations。
```

修正策略：

```text
短期：保留安全桥接版仅作为 UI/接口契约验证。
中期：Phase 2B 必须改为 CChan(lv_list=[...]) 原生多级别。
长期：区间套 relations 必须来自 chan.py parent/sub 关系，而不是时间桥接。
```

## 下一步任务

### 下一步 1：根据 flutter run 结果修正编译或启动问题

目标：

```text
先保证多级别入口可运行，不再 connection refused。
```

### 下一步 2：实现原生 CChan(lv_list) analyze_multi

目标：

```text
后端真正构造 CChan(lv_list=[DAILY, MIN30, MIN5])。
从同一个 CChan 多级别对象导出各级别结构。
从 parent/sub 关系导出 relations。
把 meta.native_cchan_lv_list 改为 true。
```

### 下一步 3：MultiLevelReplayPage 增加 step frame 控制

目标：

```text
mode=step 时显示 cursor slider。
支持上一帧 / 下一帧。
右侧图层状态显示 当前/全量。
```

## 风险记录

```text
1. GitHub contents API 每次 create_file/update_file 会直接在远端分支产生提交，不是本地暂存后统一 push。
2. 当前 analyze_multi 安全桥接版不能作为最终区间套关系来源。
3. Windows 自动启动本地 Python 已接入多级别 source，但需要 flutter run 验证。
4. Android MethodChannel 多级别调用仍未接入。
5. 原生 CChan(lv_list) 需要结合当前 tools.chanpy_compare / chan.py CSV 数据源行为验证。
```
