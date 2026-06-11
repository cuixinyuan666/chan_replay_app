# 多级别与区间套实施计划

> 分支：`origin_vespa_tdx`
>
> 目标：在保持 `python/chan.py` 为唯一缠论结构计算源的前提下，把当前单级别复盘 App 升级为多级别联动、严格逐K、区间套识别、训练、统计、选股与报告一体化工具。

## 0. 当前边界

当前分支的核心边界不变：

```text
Python chan.py：唯一缠论结构计算源。
Flutter：只解析 JSON、绘图、交互、发起请求，不在生产链路复刻 FX / BI / SEG / ZS / BSP 算法。
backend/app/a_*：App 自主扩展层，只消费 analysis JSON，不污染 chan.py。
```

当前前端请求仍以单级别为主：

```text
/api/chan/analyze?mode=once&symbol=000001&market=SZ&freq=DAILY&adjust=QFQ
/api/chan/analyze?mode=step&symbol=000001&market=SZ&freq=DAILY&adjust=QFQ
```

多级别任务的第一步不是直接堆 UI，而是先建立稳定的数据契约。

## 1. 总体目标

最终形态：

```text
多级别缠论复盘 App
├── 多级别结果结构 MultiLevelChanSnapshot
├── 多级别切换显示
├── 高级别结构定位低级别区间
├── 严格逐K多级别回放
├── 多级别图层状态面板
├── 区间套买卖点识别
├── 当前级别是否服从大级别判断
├── 多级别背驰检测
├── 买卖点质量评分
├── 止损位和目标位自动生成
├── 大级别方向 + 小级别触发交易计划
├── 区间套训练模式
├── 当时性与未来函数风险标注
├── 信号回放时间轴
├── 区间套历史统计
├── 多级别选股器
├── 区间套复盘报告
└── TV 工具栏 / 指标按级别联动
```

核心升级方向：

```text
当前：一个 freq -> 一个 ChanSnapshot -> 一张图
目标：lv_list -> MultiLevelChanSnapshot -> 多级别联动 / 区间套分析
```

## 2. 后端接口契约

### 2.1 新增接口

新增多级别一次性分析接口：

```http
POST /api/chan/analyze_multi
```

请求体：

```json
{
  "mode": "once",
  "symbol": "600340",
  "market": "SH",
  "lv_list": ["DAILY", "MIN30", "MIN5"],
  "adjust": "QFQ",
  "config": {
    "bi_algo": "normal",
    "seg_algo": "chan",
    "zs_algo": "normal"
  }
}
```

后续扩展严格逐K：

```json
{
  "mode": "step",
  "clock_level": "DAILY",
  "lv_list": ["DAILY", "MIN30", "MIN5"]
}
```

### 2.2 响应结构

```json
{
  "ok": true,
  "main_level": "DAILY",
  "levels": {
    "DAILY": {
      "bars": [],
      "merged_bars": [],
      "fx": [],
      "bi": [],
      "seg": [],
      "zs": [],
      "bsp": [],
      "indicators": {}
    },
    "MIN30": {
      "bars": [],
      "merged_bars": [],
      "fx": [],
      "bi": [],
      "seg": [],
      "zs": [],
      "bsp": [],
      "indicators": {}
    },
    "MIN5": {
      "bars": [],
      "merged_bars": [],
      "fx": [],
      "bi": [],
      "seg": [],
      "zs": [],
      "bsp": [],
      "indicators": {}
    }
  },
  "relations": [
    {
      "parent_level": "DAILY",
      "parent_raw_index": 120,
      "child_level": "MIN30",
      "child_start_raw_index": 340,
      "child_end_raw_index": 347
    }
  ],
  "frames": [],
  "meta": {
    "engine": "chan.py",
    "mode": "once",
    "levels": ["DAILY", "MIN30", "MIN5"]
  }
}
```

### 2.3 兼容原则

原有接口继续保留：

```text
GET  /api/chan/analyze
POST /api/chan/analyze_bars
```

Flutter 端优先支持：

```text
单级别：继续走 PythonChanAnalysis.snapshot / frames
多级别：新增 PythonChanAnalysis.multiSnapshot / multiFrames
```

## 3. Flutter 数据模型

### 3.1 新增文件

```text
lib/core/models/level_relation.dart
lib/core/models/multi_level_chan_snapshot.dart
lib/core/models/replay_clock_mode.dart
lib/core/models/interval_nest_signal.dart
lib/core/models/signal_visibility_state.dart
```

### 3.2 MultiLevelChanSnapshot

```dart
class MultiLevelChanSnapshot {
  final String mainLevel;
  final List<String> levels;
  final Map<String, ChanSnapshot> snapshots;
  final List<LevelRelation> relations;
  final Map<String, dynamic> meta;

  const MultiLevelChanSnapshot({
    required this.mainLevel,
    required this.levels,
    required this.snapshots,
    required this.relations,
    this.meta = const {},
  });

  ChanSnapshot? of(String level) => snapshots[level];
}
```

### 3.3 LevelRelation

```dart
class LevelRelation {
  final String parentLevel;
  final int parentRawIndex;
  final String childLevel;
  final int childStartRawIndex;
  final int childEndRawIndex;

  const LevelRelation({
    required this.parentLevel,
    required this.parentRawIndex,
    required this.childLevel,
    required this.childStartRawIndex,
    required this.childEndRawIndex,
  });
}
```

### 3.4 PythonChanAnalysis 扩展

```dart
class PythonChanAnalysis {
  final ChanSnapshot snapshot;
  final List<ChanSnapshot> frames;
  final MultiLevelChanSnapshot? multiSnapshot;
  final List<MultiLevelChanSnapshot> multiFrames;
  final Map<String, dynamic> meta;
}
```

## 4. 回放模式

```dart
enum ReplayClockMode {
  once,
  strictMainLevel,
  strictLowestLevel,
}
```

### 4.1 一次性显示

一次性计算所有级别，UI 只负责切换显示与联动定位。

### 4.2 主级别严格逐K

例如 `clock_level=DAILY`：

```text
每前进一次 = 增加一根日K
MIN30 / MIN5 只显示该日K之前已经可见的结构
```

适合大级别复盘。

### 4.3 最小级别严格逐K

例如 `clock_level=MIN5`：

```text
每前进一次 = 增加一根5分钟K
MIN30 / DAILY 动态合成当前未完成K
```

适合实盘模拟，优先级低于主级别严格逐K。

## 5. 区间套信号模型

```dart
class IntervalNestSignal {
  final String direction; // buy / sell
  final String highLevel;
  final String? midLevel;
  final String lowLevel;
  final String highPattern;
  final String? midPattern;
  final String lowTrigger;
  final int highRawIndex;
  final int? midRawIndex;
  final int? lowRawIndex;
  final double score;
  final String state; // forming / candidate / confirmed / invalid / futureOnly
  final List<String> reasons;
  final List<String> warnings;
}
```

第一批规则：

```text
1. 大级别二买 + 小级别一买
2. 大级别二买 + 小级别二买
3. 大级别三买 + 小级别一买
4. 大级别三买 + 小级别二买
5. 大级别一卖 + 小级别一卖
6. 大级别三卖 + 小级别二卖
```

后续扩展：

```text
大级别中枢上沿回踩 + 小级别下跌背驰
大级别中枢下沿反抽 + 小级别上涨背驰
周线中枢边界 + 日线买卖点 + 30分钟触发
```

## 6. 当时性与未来函数约束

所有信号必须区分：

```text
forming      形成中
candidate    候选
confirmed    已确认
invalid      失效
futureOnly   事后才知道
```

每个信号应包含：

```text
observedAt
confirmedAt
invalidatedAt
visibleAtCursor
```

严格规则：

```text
1. 当前 cursor 之后的数据不能参与判断。
2. 未确认笔不能当作确认笔。
3. 未确认线段不能当作确认线段。
4. 买卖点必须区分候选和确认。
5. 历史统计只能使用当时可见信号。
```

## 7. 16 个目标功能与阶段

| 编号 | 功能 | 阶段 |
|---:|---|---|
| 1 | 多级别联动复盘 | 阶段 3、4 |
| 2 | 区间套买卖点识别 | 阶段 6 |
| 3 | 大级别方向 + 小级别触发交易计划 | 阶段 7 |
| 4 | 多级别图层状态面板 | 阶段 3、5 |
| 5 | 严格逐K多级别回放 | 阶段 5 |
| 6 | 区间套训练模式 | 阶段 8 |
| 7 | 区间套历史统计 | 阶段 9 |
| 8 | 多级别选股器 | 阶段 9 |
| 9 | 买卖点质量评分 | 阶段 6、7 |
| 10 | 止损位和目标位自动生成 | 阶段 7 |
| 11 | 当前级别是否服从大级别 | 阶段 6 |
| 12 | 多级别背驰检测 | 阶段 6、10 |
| 13 | 区间套复盘报告 | 阶段 10 |
| 14 | 当时性与未来函数风险标注 | 阶段 5、8、9 |
| 15 | 信号回放时间轴 | 阶段 10 |
| 16 | TV 工具栏 / 指标联动 | 阶段 10 |

## 8. 推荐提交顺序

```text
01 docs: add multilevel architecture spec
02 backend: add analyze_multi api contract
03 backend: serialize chan.py multi-level snapshots
04 backend: add parent-child level relations
05 flutter: add MultiLevelChanSnapshot models
06 flutter: parse analyze_multi response
07 ui: add level switcher to replay page
08 ui: add multi-level layer status panel
09 ui: support selecting chart objects
10 ui: map high-level objects to lower-level ranges
11 replay: add multi-level main clock step mode
12 replay: add lowest-level step mode
13 domain: add interval nest signal engine
14 domain: add signal scoring and explanations
15 ui: add interval nest signal panel
16 domain: add trade plan generator
17 replay: add no-future visibility states
18 training: add interval nest training mode
19 stats: add interval nest backtest engine
20 scanner: add multi-level stock scanner
21 report: add event timeline
22 report: add replay report export
23 indicators: bind indicators by level
24 indicators: include indicator confirmations in score
```

## 9. MVP 验收路线

### MVP-1：多级别一次性显示

```text
后端 analyze_multi
Flutter 解析 MultiLevelChanSnapshot
DAILY / MIN30 / MIN5 切换显示
```

验收：

```text
1. 单级别 analyze 不受影响。
2. analyze_multi 能返回多个 levels。
3. Flutter 能切换显示不同级别。
4. 各级别图层数量正确。
```

### MVP-2：高级别定位低级别

```text
点击日线 K / BI / ZS / BSP
自动定位 30分钟 / 5分钟区间
```

验收：

```text
1. 点击日线 K 可定位 30分钟区间。
2. 点击日线 BI 可定位 30分钟区间。
3. 点击日线 ZS 可定位 30分钟区间。
4. 点击日线 BSP 可定位 5分钟附近区间。
```

### MVP-3：多级别严格逐K

```text
主级别逐K
多级别图层数量动态变化
信号不提前出现
```

验收：

```text
1. cursor 推进时各级别 rawBars 数量变化正确。
2. FX / BI / SEG / ZS / BSP 不提前显示。
3. 图层状态面板显示 当前/全量。
```

### MVP-4：区间套信号与交易计划

```text
区间套候选
评分
解释
入场 / 防守 / 目标 / 盈亏比
```

验收：

```text
1. 能输出区间套候选列表。
2. 每个信号有 reasons / warnings。
3. 每个信号可以定位到图表。
4. 每个信号能生成交易计划。
```

### MVP-5：训练、统计、选股、报告

```text
训练模式
历史统计
股票池扫描
时间轴
复盘报告导出
```

验收：

```text
1. 训练模式能隐藏未来。
2. 统计只使用当时可见信号。
3. 扫描器能按区间套条件过滤股票。
4. 报告能导出 Markdown / JSON / CSV。
```

## 10. 当前下一步

下一步进入代码阶段：

```text
1. 新增 Dart 模型：LevelRelation / MultiLevelChanSnapshot / ReplayClockMode。
2. 扩展 PythonChanAnalysis：保留 snapshot / frames，新增 multiSnapshot / multiFrames。
3. 在 PythonChanAnalysisSource 中增加 analyzeMulti 方法，但暂不替换现有 analyze。
4. 后端补 analyze_multi 的最小 mock/真实解析接口。
```

先完成模型和解析层，再做 UI 切换；否则 UI 功能会反复返工。
