# Vespa research extension plan

本文件记录 `origin_vespa_tdx` 在不污染 `python/chan.py` 的前提下，参考 Vespa/chan.py README 与 quick_guide 开始接入买卖点特征、机器学习和回测的边界。

## 1. 基本原则

1. `chan.py` 仍是 FX / BI / SEG / ZS / BSP / merged_bars / frames 的唯一计算源。
2. 本 App 自主开发的特征、机器学习、回测只能消费 `analysis JSON`，不得改写或 monkey patch `chan.py`。
3. 任何使用未来收益的字段必须命名为 `label_*`，只允许用于离线训练或评估。
4. 实盘/逐K策略判断必须使用当前帧或上一帧可见信息，不得读取未来 K 线。
5. 新增研究模块统一放在 `backend/app/a_*` 或 `tools/`，通过 `tools/check_chanpy_guardrails.py` 继续约束。

## 2. Vespa 参考点

Vespa/chan.py README 描述框架能力包括：基础缠论元素、策略买卖点开发、机器学习对买卖点打分、回测评估框架、交易系统对接。开源 quick_guide 明确开源版包含缠论元素计算，但策略、交易引擎、机器学习相关特征/模型不在公开版中，因此本分支采用自主扩展、JSON 消费的方式接入。

关键映射：

| Vespa 方向 | 本分支接入方式 |
| --- | --- |
| 形态学 BSP | 继续由 Python `chan.py` 导出 `bsp` |
| BSP 特征 | `backend/app/a_bsp_feature_engine.py` 从 analysis JSON 派生 |
| ML 打分 | `backend/app/a_ml_bridge.py` 提供 heuristic / linear model 合同 |
| 策略回测 | `backend/app/a_backtest_engine.py` 使用下一根 K 线入场，避免同 K 线偷看 |
| 实时/逐K | 继续依赖 `CChan.step_load()` / frames，未来再加 trigger_load 真增量接口 |

## 3. 当前 API

### 3.1 BSP 特征

```text
POST /api/research/bsp/features
```

输入可以是完整 analysis JSON，也可以是：

```json
{
  "analysis": {},
  "label_horizon": 5,
  "include_labels": true
}
```

输出：

```text
features[]
meta.labels_use_future_data
meta.chan_py_polluted=false
```

### 3.2 ML 打分

```text
POST /api/research/ml/score
```

支持两类输入：

1. 直接传 `features`。
2. 传 analysis JSON，由后端先提特征。

默认模型是透明 heuristic baseline。也可以传线性模型：

```json
{
  "model": {
    "type": "linear",
    "intercept": 0,
    "weights": {
      "ret_5": -1.0,
      "macd_hist": 0.5
    },
    "threshold": 0.55
  }
}
```

### 3.3 BSP 回测

```text
POST /api/research/backtest
```

回测约束：

1. 买点信号后下一根 K 线开盘价入场，开盘缺失时用收盘价兜底。
2. 卖点、止损、止盈、最大持仓根数触发离场。
3. 计算手续费和滑点。
4. 不使用同一根 K 线的未来信息入场。

### 3.4 一键 pipeline

```text
POST /api/research/pipeline
```

执行：

```text
analysis JSON -> BSP 特征 -> ML 打分 -> BSP 回测
```

## 4. 后续任务

1. 用真实 easy-tdx analysis JSON 跑 `features / ml / backtest / pipeline`。
2. 将 research API 输出保存为 fixture，加入合同校验。
3. Flutter 增加“研究 / 回测”入口，但必须懒加载或放在独立页面边界。
4. 支持外部模型文件加载，但默认不引入 xgboost / lightgbm / sklearn 重依赖。
5. Android MethodChannel 合同后续补齐 research API 或走本地 HTTP 服务。

## 5. 验收命令

```bash
flutter analyze
python tools/audit_dart_algorithm_usage.py
python tools/audit_global_lazy_loading.py --strict
python tools/check_chanpy_guardrails.py
python tools/validate_chanpy_output_contract.py path/to/analysis.json
```
