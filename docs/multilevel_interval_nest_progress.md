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

完成内容：

```text
- 定义多级别与区间套总目标。
- 定义 POST /api/chan/analyze_multi 接口契约。
- 定义 levels / relations / frames / meta 返回结构。
- 定义 16 个目标功能与开发阶段。
- 定义 MVP-1 到 MVP-5 验收路线。
```

### 2. 父子级别关系模型

```text
commit: 294292aa4e057af1f40b858792dc97f8c28756af
file: lib/core/models/level_relation.dart
```

完成内容：

```text
- 新增 LevelRelation。
- 支持 parent_level + parent_raw_index 映射 child_level 的 rawIndex 区间。
- 为后续“点击高级别结构 -> 定位低级别区间”做基础。
```

### 3. 多级别快照模型

```text
commit: dcd3570c40d988e107e1f472910fd2edaf2621f0
file: lib/core/models/multi_level_chan_snapshot.dart
```

完成内容：

```text
- 新增 MultiLevelChanSnapshot。
- 用 Map<String, ChanSnapshot> 按级别承载 DAILY / MIN30 / MIN5 等快照。
- 支持 mainLevel、levels、relations、meta。
- 支持 relationsFromParent 和 relationsForParentRange 查询。
```

### 4. 回放时钟模式

```text
commit: 2bda4c3ef636e047c6c234ff2f208932003a1338
file: lib/core/models/replay_clock_mode.dart
```

完成内容：

```text
- 新增 ReplayClockMode。
- 支持 once、strictMainLevel、strictLowestLevel。
- 为一次性显示、主级别严格逐K、最小级别严格逐K预留统一枚举。
```

### 5. 信号可见性状态

```text
commit: 26a78c7968affb9459dce57f631f83e49e747add
file: lib/core/models/signal_visibility_state.dart
```

完成内容：

```text
- 新增 SignalVisibilityState。
- 支持 forming、candidate、confirmed、invalid、futureOnly。
- 为未来函数风险标注、训练模式、历史统计当时性校验做基础。
```

### 6. 区间套信号模型

```text
commit: 7fa905c032bdd96f82f9130172178958ac112004
file: lib/core/models/interval_nest_signal.dart
```

完成内容：

```text
- 新增 IntervalNestSignal。
- 承载 highLevel / midLevel / lowLevel。
- 承载 highPattern / midPattern / lowTrigger。
- 承载 score、state、reasons、warnings。
- 增加 observedAtCursor、confirmedAtCursor、invalidatedAtCursor。
- 支持 fromJson / toJson。
```

### 7. MultiLevelChanSnapshot 安全修正

```text
commit: e3ac134e4a08023f7ecec2557edf701695d75770
file: lib/core/models/multi_level_chan_snapshot.dart
```

完成内容：

```text
- 移除 firstOrNull 依赖。
- 改为显式 levels.isNotEmpty 判断。
- 降低 Dart analyzer 兼容风险。
```

### 8. 多级别分析解析器

```text
commit: 59c9abb363e4e196c8fecf0656bb79a616892dfa
file: lib/data/multi_level_chan_analysis_parser.dart
```

完成内容：

```text
- 新增 MultiLevelChanAnalysisParser。
- 解析 analyze_multi 返回的 levels。
- 解析 relations。
- 解析 main_level 和 meta.levels。
- 解析多级别 frames。
- 通过注入 ChanSnapshotParser 复用现有单级别 _parseSnapshot，避免重复实现 FX / BI / SEG / ZS / BSP 解析。
```

## 当前完成度

```text
阶段 0：架构文档与接口契约        已完成
阶段 1A：Flutter 多级别基础模型    已完成
阶段 1B：多级别 JSON 解析器        已完成
阶段 1C：PythonChanAnalysisSource 接入    未完成
阶段 2：后端 analyze_multi              未完成
阶段 3：UI 级别切换与图层面板          未完成
阶段 4：高级别定位低级别区间          未完成
阶段 5：多级别严格逐K                 未完成
阶段 6：区间套信号引擎                未完成
阶段 7：评分、交易计划、训练、统计、选股 未完成
```

## 当前代码影响范围

当前已提交内容只新增模型、解析器和文档：

```text
新增：docs/multilevel_interval_nest_plan.md
新增：docs/multilevel_interval_nest_progress.md
新增：lib/core/models/level_relation.dart
新增：lib/core/models/multi_level_chan_snapshot.dart
新增：lib/core/models/replay_clock_mode.dart
新增：lib/core/models/signal_visibility_state.dart
新增：lib/core/models/interval_nest_signal.dart
新增：lib/data/multi_level_chan_analysis_parser.dart
```

尚未修改：

```text
lib/data/python_chan_analysis_source.dart
lib/ui/pages/origin_replay_page_v2.dart
lib/ui/widgets/origin_kline_chart.dart
python/app_engine.py
python/chan.py
```

因此当前单级别复盘、一次性显示、严格逐K、图层开关理论上不应受影响。

## 下一步任务

### 下一步 1：扩展 PythonChanAnalysis

目标：

```text
保留 snapshot / frames
新增 multiSnapshot / multiFrames
```

计划：

```dart
class PythonChanAnalysis {
  final ChanSnapshot snapshot;
  final List<ChanSnapshot> frames;
  final MultiLevelChanSnapshot? multiSnapshot;
  final List<MultiLevelChanSnapshot> multiFrames;
  final Map<String, dynamic> meta;
}
```

### 下一步 2：新增 analyzeMulti()

目标：

```text
新增 POST /api/chan/analyze_multi 客户端请求方法。
不替换 analyze()。
不影响 analyzeBars()。
```

### 下一步 3：后端 analyze_multi

目标：

```text
后端接收 lv_list。
调用 chan.py 多级别能力。
返回 levels / relations / frames。
```

### 下一步 4：UI 多级别切换

目标：

```text
先实现 DAILY / MIN30 / MIN5 切换显示。
暂不做复杂区间套联动。
```

## 风险记录

```text
1. GitHub contents API 每次 create_file/update_file 会直接在远端分支产生提交，不是本地暂存后统一 push。
2. 后续修改 python_chan_analysis_source.dart 时文件较长，应避免整文件误覆盖。
3. 最好先用小提交扩展模型和解析器，再单独提交 source 接入。
4. 后端 analyze_multi 未完成前，前端 multiSnapshot 只能解析模拟或未来接口返回。
```
