# Vespa quick_guide 对齐矩阵

本文件用于监督 `origin_vespa_tdx` 分支与 `Vespa314/chan.py` 的 `quick_guide.md` 对齐范围。原则：**只对齐开源版缠论计算与数据接入能力，不把策略、机器学习、交易引擎纳入本轮任务**。

## 1. 对齐边界

### 必须对齐

| quick_guide 主题 | 本分支要求 | 当前状态 | 下一步 |
| --- | --- | --- | --- |
| 框架核心能力 | 给定 K 线范围后，Python `chan.py` 输出缠论元素 | 已接入 once 模式 | 保持 Flutter 只消费 JSON |
| 当前帧 / step | 逐根 K 线投喂后返回当前帧元素 | 已接入 `CChan.step_load()` 并返回 `frames` | 验证每帧 FX/BI/SEG/ZS/BSP 变化 |
| `is_sure` | 不确定元素保留 `is_sure=false`，前端弱化或虚线显示 | SEG 已有 `is_sure` 样式，BSP/ZS 仍需统一检查 | 增加虚线/弱化规范和样本验收 |
| 取出缠论元素 | 导出 CKLine/FX/BI/SEG/ZS/BSP | 已导出主元素 | 用合同脚本校验字段完整性 |
| CKLine / CKLine_Unit | `merged_bars` 必须来自 Python，不允许前端重算 | 已返回 `merged_bars` | 长样本核对 raw index/OHLC |
| CChanConfig | Flutter 设置面板传入 Python 配置 | 已接入结构、中枢、BSP 配置 | 增加 README 文档索引 |
| 数据接入 | 遵循 `CCommonStockApi` / 自定义数据源思想 | 已有 easy-tdx provider 雏形 | 固化 easy-tdx 字段合同 |
| 指标添加 | 指标仅展示，不影响缠论逻辑 | 配置位存在，展示合同待补 | 先做 VOL，再做 MACD/MA/BOLL |

### 可做增强

| quick_guide 主题 | 处理方式 |
| --- | --- |
| `trigger_load` | 作为未来实时行情增强项，不阻塞 once / step / CSV / easy-tdx 静态链路 |
| `segseg_list / segzs_list / seg_bs_point_lst` | 作为父级别结构增强项，先不进入第一阶段强制显示 |
| 自定义指标 | 可按 `a_` 适配层和后端 indicators 输出合同接入 |
| PlotMeta / 绘图元信息 | Flutter 可参考，但不得把 Python 绘图逻辑搬到前端计算缠论 |

### 暂不纳入本轮

| README / quick_guide 提到的内容 | 原因 |
| --- | --- |
| 策略买卖点开发 | 开源版说明中策略不属于通用开源范围 |
| 机器学习特征 / 模型 | 不属于 App MVP，也不属于本轮复盘展示目标 |
| AutoML | 不属于本轮范围 |
| 线上交易 / Futu / 交易引擎 | 与复盘展示目标无关，风险和范围过大 |
| MySQL / SQLite 缠论数据库 | 本轮重点是 UI、数据接入、输出合同和回放 |

## 2. 字段合同

### BSP 最小字段

后端导出 BSP 时，Flutter 需要至少消费：

```text
index
raw_index
time
price
is_buy
types
bi_idx
klu_idx
is_sure
level
```

要求：

- `types` 必须支持 `1 / 1p / 2 / 2s / 3a / 3b`。
- 同一位置多个 BSP 类型必须合并显示，不允许后发覆盖先发。
- `is_sure=false` 不得被前端伪装成确定信号。
- `level=bi` 与 `level=seg` 必须能区分显示。

### merged_bars 最小字段

```text
index
raw_index
start_raw_index
end_raw_index
time
open
high
low
close
```

要求：

- `high >= low`。
- `start_raw_index <= end_raw_index`。
- 顺序以 `end_raw_index` 或 `index` 单调递增为准。
- Flutter 不得对包含关系二次计算或二次修正。

可执行校验：

```bash
python tools/validate_chanpy_output_contract.py path/to/analysis.json
```

## 3. step / 当前帧验收

验收样本：

1. 本地 CSV：`assets/sample_data/000001_daily_long.csv`。
2. easy-tdx：至少随机 5 只股票、3 个周期。
3. 每个样本分别跑 once 与 step。

验收点：

- step 帧内 `rawBars.length` 随 cursor 增加。
- 每帧的 FX/BI/SEG/ZS/BSP 只展示当前帧可见元素。
- 不确定元素保持 `is_sure=false`。
- BSP 消失、移动、变化时，Flutter 跟随 Python 当前帧，不用前端自行过滤未来结构。

## 4. 旧 Dart 算法隔离验收

执行：

```bash
python tools/audit_dart_algorithm_usage.py
```

目标：

- 生产 UI 页面不 import `lib/core/engine/*` 旧算法。
- 旧 Dart 算法如需保留，只能作为 `legacy`、`tools`、`compare` 或测试用途。
- `FxDrawModel / BiDrawModel / SegDrawModel / ZsDrawModel / BspPoint` 仅作为显示模型保留。

## 5. README 收口要求

README 应至少链接以下文件：

```text
docs/batch_1_2_execution_checklist.md
docs/vespa_quick_guide_alignment_matrix.md
docs/easy_tdx_indicator_contract.md
docs/label_overlap_policy.md
tools/validate_chanpy_output_contract.py
tools/audit_dart_algorithm_usage.py
```

完成第一批和第二批后，README 的待完成项应更新为：

1. Windows / Android `flutter run` 实机验收。
2. BSP 字段真实样本覆盖测试。
3. `merged_bars` 长样本一致性核对。
4. label lane 避让实装与截图验收。
5. easy-tdx VOL / amount / indicators 展示链路。
