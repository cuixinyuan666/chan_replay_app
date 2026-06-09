# 第一批 / 第二批执行与验收清单

本文件用于 `origin_vespa_tdx` 分支的本轮监督验收。执行边界：Flutter 只做展示与交互，Python `chan.py` 是唯一缠论计算源。

## 0. 硬约束

- 不修改 Vespa `python/chan.py` 原有笔、线段、中枢、买卖点计算逻辑。
- 不在 Dart / Flutter 侧重新计算 FX / BI / SEG / ZS / BSP。
- Flutter 只消费 Python 返回的结构化 JSON。
- 新增 `python/chan.py` 内文件时，只能放入 `a_*` 文件夹或命名为 `a_*.py`。

可执行检查：

```bash
python tools/audit_dart_algorithm_usage.py
python tools/check_chanpy_guardrails.py
```

## 1. 第一批：稳定主流程

### 1.1 编译与静态检查

```bash
flutter pub get
flutter analyze
```

GitHub Actions 已新增 `.github/workflows/flutter_analyze.yml`，会在 `origin_vespa_tdx` push / PR 时执行：

1. `flutter pub get`
2. `flutter analyze`
3. `python tools/audit_dart_algorithm_usage.py`
4. `python tools/check_chanpy_guardrails.py`

### 1.2 once / step / local CSV 主链路

验收项：

- once 模式调用 Python `/api/chan/analyze` 或 Android `python_chan` MethodChannel。
- step 模式消费 Python `frames`，不使用前端未来切片模拟。
- local CSV 走 `/api/chan/analyze_bars` 或 Android 同一 MethodChannel 分析入口。
- 后端失败时 UI 显示 warning / error，不闪退。

### 1.3 旧 Dart 算法层隔离

目标：旧 Dart `FxEngine / BiEngine / SegEngine / ZsEngine / IncludeProcessor / ChanReplayEngine` 不进入生产 UI 链路。

执行：

```bash
python tools/audit_dart_algorithm_usage.py
```

处理标准：

- 若报告 `blocking_count > 0`，对应文件必须改为 Python JSON 消费，或迁移到 `legacy` / `tools` / `compare` / `test`。
- 仅作为显示 DTO 的 `FxDrawModel / BiDrawModel / SegDrawModel / ZsDrawModel / BspPoint` 可以保留。

## 2. 第二批：绘图可用性优化

### 2.1 图层顺序

当前 V2 绘图组件应保持如下顺序：

1. 网格、坐标轴、K线蜡烛图。
2. 合并K线外框。
3. 中枢 ZS 区域。
4. FX 连线。
5. BI / SEG 结构线。
6. BSP 图形点位。
7. FX 点位。
8. 手动画线。
9. crosshair / 顶层信息。

不得把文本标签放到结构线之前，避免线条覆盖文字。

### 2.2 标签避让策略

必须实现或保持以下策略：

- 默认关闭高密度编号：BI 文本默认关闭，SEG 文本可开关。
- BSP 标签区分笔/段，段级别用更大符号或不同文字。
- 同一 X 区域内多个标签按上下错层排列。
- 买点标签优先放在低点下方，卖点标签优先放在高点上方。
- 缩放窗口大于阈值时减少文字显示，只保留点位与结构线。
- crosshair / 点击查看时再显示完整 OHLCV 与 BSP 详情。

### 2.3 验收样本

最小验收：

- `assets/sample_data/000001_daily_long.csv`
- 300 根可读。
- 1000 根缩放后结构线可读。
- 3000 根长样本不出现大面积文字糊图；若样本不足，需补充长 CSV 或 easy-tdx 拉取。

## 3. Python 输出合同验收

保存后端响应为 JSON 后执行：

```bash
python tools/validate_chanpy_output_contract.py path/to/analysis.json
```

检查重点：

- BSP 字段：`index / raw_index / time / price / is_buy / types / bi_idx / klu_idx / is_sure`。
- `types` 支持 `1 / 1p / 2 / 2s / 3a / 3b`，同一位置可多类型合并。
- `is_sure=false` 必须保留，不允许前端伪装为确定信号。
- `merged_bars` 必须包含 begin/end/raw index 与 OHLC。
- `frames` 中的 BSP / merged_bars 也要满足同一合同。

## 4. 本轮不做范围

- 不开发策略买卖点。
- 不接入机器学习、AutoML、交易引擎。
- 不新增线上交易、Futu、数据库系统。
- 不重写 Vespa `chan.py` 核心计算。

## 5. 当前下一步

1. 修复 `flutter analyze` 报错。
2. 将旧 Dart 算法入口移出生产链路或标记为 legacy。
3. 在 `OriginKlineChart` 落实统一 label layout / label lane 避让。
4. 将 VOL 副图和 easy-tdx 扩展字段并入后端输出合同。
