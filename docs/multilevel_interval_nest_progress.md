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

### 4. 后端 analyze_multi 桥接原型

```text
commit: ee2d039f3fa28e46226a5f0e26d74cfc84ffb1ea
file: backend/app/a_multilevel_engine.py
```

完成：新增桥接原型，返回 `levels / relations / frames / meta`，每个级别复用现有单级别 `chanpy_engine.analyze_once`。

现状态：

```text
该版本已降级为 fallback/prototype。
不能作为最终区间套关系来源。
若响应 meta.fallback_to_bridge=true，说明原生 CChan(lv_list) 失败并回退到了该桥接原型。
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

完成：多级别 source 对齐复盘页自动后端启动逻辑。localhost 不可用、旧服务不兼容、缺少 `/api/chan/analyze_multi` 或 Windows 连接拒绝时，会自动启动内置 `python/app_engine.py`。

### 11. 原生 CChan(lv_list) 后端模块

```text
commit: 71831aeb34fec52d1f7bd9a9ec354a277de94ffd
file: backend/app/a_multilevel_native_engine.py
```

完成：

```text
- 新增 backend/app/a_multilevel_native_engine.py。
- 准备所有 lv_list 级别的 CSV 数据。
- 在同一个 chan.py CSV code 下准备多级别数据。
- 构造一个 CChan(lv_list=[...])。
- 从同一个 CChan 对象导出各级别结构。
- 从 chan.py 的 sub_kl_list / sup_kl 关系导出 parent-child relations。
- meta.native_cchan_lv_list=true。
- meta.level_relation_mode=chan_parent_child。
```

### 12. analyze_multi 默认优先原生 lv_list

```text
commit: c5ee0fc0b5d12aba5b68a6311924046d47649a28
file: backend/app/a_multilevel_engine.py
```

完成：

```text
- /api/chan/analyze_multi 默认先尝试 analyze_multi_native。
- 原桥接实现改为 _analyze_multi_bridge。
- 原生成功时返回 native_cchan_lv_list=true。
- 原生失败时 fallback 到桥接版，并写入：
  - meta.fallback_to_bridge=true
  - meta.native_failure=<错误原因>
  - meta.native_cchan_lv_list=false
```

### 13. 原生 lv_list step 安全修正

```text
commit: e0a7ec8e6898469a8bba40a354cdbe776b775299
file: backend/app/a_multilevel_native_engine.py
```

完成：

```text
- 原生 CChan(lv_list) 当前固定使用 trigger_step=false 完整加载。
- 避免 mode=step 但 native frames 未实现时导出空结构。
- mode=step 当前返回最终多级别结构，并在 warnings 中说明 native step frames 尚未实现。
```

## 当前完成度

```text
阶段 0：架构文档与接口契约                    已完成
阶段 1A：Flutter 多级别基础模型                已完成
阶段 1B：多级别 JSON 解析器                    已完成
阶段 1C：独立 analyze_multi 客户端              已完成
阶段 1D：多级别 source 启动逻辑对齐复盘页        已完成（Windows）
阶段 2：后端 analyze_multi 桥接原型             已完成，但仅作 fallback/prototype
阶段 2B：原生 CChan(lv_list) 多级别关系          已实现，待本地验证
阶段 3A：Flutter 多级别 UI 基础组件             已完成
阶段 3B：受控多级别页面入口                    已完成（独立页面，不替换原复盘页）
阶段 3C：原复盘页内联多级别模式                未完成
阶段 4：高级别定位低级别区间                  未完成
阶段 5：多级别严格逐K                         部分完成（原生 final levels；native step frames 未实现）
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
backend/app/a_multilevel_native_engine.py
```

修改：

```text
backend/app/main.py
lib/ui/pages/root_page.dart
lib/data/python_multi_level_chan_analysis_source.dart
backend/app/a_multilevel_engine.py
backend/app/a_multilevel_native_engine.py
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
4. 响应 meta.native_cchan_lv_list 是否为 true。
5. 响应 meta.level_relation_mode 是否为 chan_parent_child。
6. 如果 meta.fallback_to_bridge=true，请记录 meta.native_failure。
7. DAILY / MIN30 / MIN5 切换是否正常。
8. 原“复盘”页面是否仍保持原行为。
```

## 老板 review 修正状态

老板指出的两个问题成立：

```text
1. 当前后端不是 chan.py 原生多级别 lv_list 实现。
2. 当前是多个单级别 analyze_once + 时间桥接 relations。
```

当前修正状态：

```text
1. 已新增 native CChan(lv_list) 路径。
2. /api/chan/analyze_multi 已默认优先 native 路径。
3. 桥接路径只作为 fallback/prototype。
4. native 是否可稳定运行需要本地样本验证。
```

## 下一步任务

### 下一步 1：根据 flutter run 和 analyze_multi meta 修正 native 路径

目标：

```text
先确认 meta.native_cchan_lv_list=true。
如果 fallback_to_bridge=true，优先修 native_failure。
```

### 下一步 2：实现 native step_load frames

目标：

```text
mode=step 时使用 CChan(lv_list) + step_load 生成多级别 frames。
右侧图层状态显示 当前/全量。
```

### 下一步 3：高级别定位低级别区间

目标：

```text
使用 chan_parent_child relations 实现高级别 K/BI/ZS/BSP 到低级别区间定位。
```

## 风险记录

```text
1. GitHub contents API 每次 create_file/update_file 会直接在远端分支产生提交，不是本地暂存后统一 push。
2. native CChan(lv_list) 依赖 exporter.prepare_chanpy_csv 能为同一个 code 准备多级别 CSV 文件。
3. 如 native CSV 准备或级别顺序失败，接口会 fallback 到 bridge，并在 meta.native_failure 中给出原因。
4. Android MethodChannel 多级别调用仍未接入。
5. 原生 step_load frames 尚未实现。
```
