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

完成：

```text
- LevelRelation：父级别 rawIndex -> 子级别 rawIndex 区间。
- MultiLevelChanSnapshot：按级别承载多个 ChanSnapshot。
- ReplayClockMode：once / strictMainLevel / strictLowestLevel。
- SignalVisibilityState：forming / candidate / confirmed / invalid / futureOnly。
- IntervalNestSignal：区间套信号载体。
- 修正 MultiLevelChanSnapshot，移除 firstOrNull 依赖。
```

### 3. Flutter 多级别解析与客户端

```text
commit: 59c9abb363e4e196c8fecf0656bb79a616892dfa
file: lib/data/multi_level_chan_analysis_parser.dart

commit: 2a87332b69e2eee1d08b86f0bcf204290222e416
file: lib/data/chan_snapshot_json_parser.dart

commit: b44442e2897b639879942f49673e3d31bd82dfdd
file: lib/data/python_multi_level_chan_analysis_source.dart
```

完成：

```text
- MultiLevelChanAnalysisParser：解析 levels / relations / frames / meta。
- ChanSnapshotJsonParser：把后端 JSON 解析为现有 ChanSnapshot，不计算缠论结构。
- PythonMultiLevelChanAnalysisSource：独立客户端，支持 POST /api/chan/analyze_multi。
- 解析可选 interval_nest_signals。
```

限制：

```text
- 尚未接入 UI。
- 尚未接入 Windows 自动后台启动本地 Python 服务。
- 尚未接入 Android MethodChannel。
- 没有替换现有 PythonChanAnalysisSource。
```

### 4. 后端 analyze_multi 安全桥接版

```text
commit: ee2d039f3fa28e46226a5f0e26d74cfc84ffb1ea
file: backend/app/a_multilevel_engine.py
```

完成：

```text
- 新增 backend/app/a_multilevel_engine.py。
- 新增 analyze_multi 后端引擎函数。
- 返回 contract-compatible 多级别结构：levels / relations / frames / meta。
- 每个级别复用现有单级别 chanpy_engine.analyze_once。
- chan.py 仍是 FX / BI / SEG / ZS / BSP 唯一计算源。
- 新增时间/日期桥接 relations，用于高级别 K 到低级别 K 区间映射。
- 支持 mode=step 时按 clock_level 构造多级别 frame。
```

重要限制：

```text
- 当前是安全桥接版，不是原生 CChan(lv_list=[...])。
- meta.native_cchan_lv_list=false。
- parent-child relations 当前为 time_date_bridge，不是 chan.py parent_klu/sub_kl_list 原生关系。
- 后续需要升级为原生多级别对象关系。
```

### 5. FastAPI 路由接入

```text
commit: 1ded7ed6edd47267c7fd5856f504de4cfe341433
file: backend/app/main.py
```

完成：

```text
- 在 FastAPI 中引入 a_multilevel_engine.analyze_multi。
- 新增 POST /api/chan/analyze_multi。
- 根接口 endpoint 列表加入 /api/chan/analyze_multi。
- 接收 lv_list / levels / level_order。
- 接收 main_level / clock_level。
- 接收 mode / symbol / market / adjust / start / end / count / config。
- 保持 /api/chan/analyze 和 /api/chan/analyze_bars 不变。
```

### 6. analyze_multi 冒烟测试文档

```text
commit: 8ef4a6a26c9ee7865fed86ff98893e908e9f6230
file: docs/analyze_multi_smoke_test.md
```

完成：

```text
- 记录 once 模式请求体。
- 记录 step 模式请求体。
- 记录响应字段检查点。
- 记录当前安全桥接版边界。
- 记录 Flutter 侧已具备和未接入内容。
```

## 当前完成度

```text
阶段 0：架构文档与接口契约                    已完成
阶段 1A：Flutter 多级别基础模型                已完成
阶段 1B：多级别 JSON 解析器                    已完成
阶段 1C：独立 analyze_multi 客户端              已完成（未接 UI / 未接自动本地服务）
阶段 2：后端 analyze_multi 安全桥接版           已完成（非原生 CChan lv_list）
阶段 2B：原生 CChan(lv_list) 多级别关系          未完成
阶段 3：UI 级别切换与图层面板                  未完成
阶段 4：高级别定位低级别区间                  未完成
阶段 5：多级别严格逐K                         部分完成（后端安全桥接 frames；UI 未接）
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
lib/core/models/replay_clock_mode.dart
lib/core/models/signal_visibility_state.dart
lib/core/models/interval_nest_signal.dart
lib/data/multi_level_chan_analysis_parser.dart
lib/data/chan_snapshot_json_parser.dart
lib/data/python_multi_level_chan_analysis_source.dart
backend/app/a_multilevel_engine.py
```

修改：

```text
backend/app/main.py
```

尚未修改：

```text
lib/data/python_chan_analysis_source.dart
lib/ui/pages/origin_replay_page_v2.dart
lib/ui/widgets/origin_kline_chart.dart
python/app_engine.py
python/chan.py
```

## 当前可测试内容

后端新增接口：

```text
POST /api/chan/analyze_multi
```

参考：

```text
docs/analyze_multi_smoke_test.md
```

预期返回：

```text
levels: DAILY / MIN30 / MIN5 等多级别结构
relations: 父级别 K 到子级别 K 区间映射
frames: step 模式下的多级别逐K帧
meta.native_cchan_lv_list: false
meta.chan_py_polluted: false
```

## 下一步任务

### 下一步 1：本地验证 analyze_multi

目标：

```text
启动 python/app_engine.py。
调用 /api/chan/analyze_multi once。
调用 /api/chan/analyze_multi step。
检查 levels / relations / frames 是否符合契约。
```

### 下一步 2：Flutter UI 多级别切换

目标：

```text
先加受控入口，不替换原单级别入口。
支持 DAILY / MIN30 / MIN5 切换显示。
使用 PythonMultiLevelChanAnalysisSource。
```

### 下一步 3：多级别图层状态

目标：

```text
once：显示各级别全量数量。
step：显示各级别 当前/全量 数量。
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
3. 后续改 UI 前需要先本地验证 analyze_multi 响应。
4. Windows 自动启动本地 Python 和 Android MethodChannel 多级别调用仍未接入。
5. step frames 当前按 clock_level 截取各级别可见数据，仍需通过本地样本验证边界情况。
```
