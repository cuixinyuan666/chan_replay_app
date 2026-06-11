# analyze_multi 冒烟测试

分支：`origin_vespa_tdx`

## 1. 目标

验证后端新增接口：

```text
POST /api/chan/analyze_multi
```

该接口用于返回多级别结构：

```text
levels
relations
frames
meta
```

## 2. 一次性模式请求体

```json
{
  "mode": "once",
  "symbol": "000001",
  "market": "SZ",
  "lv_list": ["DAILY", "MIN30", "MIN5"],
  "adjust": "QFQ",
  "count": 800,
  "config": {
    "bi_algo": "normal",
    "seg_algo": "chan",
    "zs_algo": "normal"
  }
}
```

预期响应检查点：

```text
1. ok 字段存在。
2. main_level 默认为 DAILY。
3. levels 中包含 DAILY / MIN30 / MIN5。
4. 每个 level 下至少包含 bars / merged_bars / fx / bi / seg / zs / bsp / indicators。
5. relations 字段存在，可以为空数组。
6. frames 在 once 模式下为空数组。
7. meta.native_cchan_lv_list 当前应为 false。
8. meta.chan_py_polluted 应为 false。
```

## 3. 主级别严格逐K请求体

```json
{
  "mode": "step",
  "symbol": "000001",
  "market": "SZ",
  "lv_list": ["DAILY", "MIN30", "MIN5"],
  "main_level": "DAILY",
  "clock_level": "DAILY",
  "adjust": "QFQ",
  "count": 300,
  "config": {
    "bi_algo": "normal",
    "seg_algo": "chan"
  }
}
```

预期响应检查点：

```text
1. frames 是数组。
2. 每个 frame 都有 levels。
3. 每个 frame 都有 cursor / current_time / clock_level。
4. 每个 frame 中各级别 bars 数量应随 cursor 推进而变化。
5. frame 内 relations 应基于当前 frame 的可见数据重新生成。
```

## 4. 当前实现边界

当前 analyze_multi 是安全桥接版：

```text
1. 不修改 python/chan.py 内部逻辑。
2. 每个级别复用现有单级别 chanpy_engine.analyze_once。
3. chan.py 仍是 FX / BI / SEG / ZS / BSP 的唯一计算源。
4. parent-child relations 当前采用时间/日期桥接。
5. meta.native_cchan_lv_list=false 表示尚未接入原生 CChan(lv_list=[...])。
```

后续升级方向：

```text
1. 用 CChan(lv_list=[...]) 原生多级别对象替换当前安全桥接版。
2. 使用 chan.py 的 parent_klu / sub_kl_list 构造更精确的 relations。
3. 支持最小级别严格逐K。
4. 接入 Flutter 多级别切换 UI。
```

## 5. Flutter 侧当前状态

已具备：

```text
- MultiLevelChanSnapshot
- LevelRelation
- MultiLevelChanAnalysisParser
- ChanSnapshotJsonParser
- PythonMultiLevelChanAnalysisSource
```

尚未接入：

```text
- origin_replay_page_v2.dart 多级别 UI
- 图层状态面板多级别显示
- 高级别结构点击定位低级别区间
```
