# easy-tdx 与指标输出合同

本文件定义 `origin_vespa_tdx` 分支 easy-tdx 数据接入、指标展示、后端 JSON 输出与 Flutter 消费边界。原则：**数据适配可以扩展，缠论计算只交给 Python `chan.py`**。

## 1. 职责边界

```text
easy-tdx / CSV / 其他行情源
  ↓
Python 数据适配层
  ↓
CKLine_Unit / CChan 输入
  ↓
chan.py 计算 FX / BI / SEG / ZS / BSP / merged_bars
  ↓
后端 JSON 输出 bars / merged_bars / fx / bi / seg / zs / bsp / indicators / frames / meta
  ↓
Flutter 只绘图、交互、tooltip、开关、回放
```

禁止事项：

- Flutter 不重新计算包含关系。
- Flutter 不重新计算 FX / BI / SEG / ZS / BSP。
- easy-tdx 缺失字段不允许伪造。
- 指标展示不允许反向影响 `chan.py` 买卖点逻辑，除非后续按 Vespa 指标注册机制正式接入 Python 配置。

## 2. easy-tdx 字段映射

### 必填 K线字段

| 输出字段 | 说明 | 处理规则 |
| --- | --- | --- |
| `time` | K线时间 | 转为 ISO 字符串或后端统一时间格式 |
| `open` | 开盘价 | 数值型 |
| `high` | 最高价 | 数值型，必须满足 `high >= max(open, close, low)` |
| `low` | 最低价 | 数值型，必须满足 `low <= min(open, close, high)` |
| `close` | 收盘价 | 数值型 |

### 扩展行情字段

| 输出字段 | 说明 | easy-tdx 缺失时处理 |
| --- | --- | --- |
| `volume` / `vol` | 成交量 | 缺失时为 `0` 或 `null`，由 meta 标记来源 |
| `amount` | 成交额 | 缺失时为 `null` |
| `turnover` | 换手率 | easy-tdx 不能直接提供时为 `null`，不得估算伪造 |
| `market` | 市场 | `SH` / `SZ` |
| `code` | 代码 | 六位代码 |
| `period` | 周期 | Flutter 周期枚举映射到 easy-tdx 周期 |
| `adjust` | 复权 | `QFQ` / `HFQ` / `NONE`，无法支持时写入 `meta.warning` |

## 3. 周期映射建议

| Flutter 周期 | easy-tdx / 后端含义 | 备注 |
| --- | --- | --- |
| `MIN1` | 1 分钟 | 若数据源不支持，明确报错 |
| `MIN5` | 5 分钟 |  |
| `MIN15` | 15 分钟 |  |
| `MIN30` | 30 分钟 |  |
| `MIN60` | 60 分钟 |  |
| `DAILY` | 日线 | 默认优先支持 |
| `WEEKLY` | 周线 | 数据源不支持时由后端明确 warning |
| `MONTHLY` | 月线 | 数据源不支持时由后端明确 warning |

## 4. 后端 JSON 输出建议

```json
{
  "bars": [],
  "merged_bars": [],
  "fx": [],
  "bi": [],
  "seg": [],
  "zs": [],
  "bsp": [],
  "indicators": {
    "vol": [],
    "amount": [],
    "turnover": [],
    "ma": {},
    "boll": [],
    "macd": []
  },
  "frames": [],
  "meta": {
    "engine": "chan.py",
    "data_source": "easy_tdx",
    "symbol": "000001.SZ",
    "period": "DAILY",
    "adjust": "QFQ",
    "warnings": []
  }
}
```

## 5. indicators 子合同

### VOL

VOL 是第一优先级副图。

```json
{
  "time": "2024-01-02",
  "raw_index": 0,
  "value": 123456.0
}
```

要求：

- 与 `bars.raw_index` 对齐。
- 可从 `bars.volume` 直接派生展示。
- 不影响 `chan.py` 结构计算。

### amount

```json
{
  "time": "2024-01-02",
  "raw_index": 0,
  "value": 123456789.0
}
```

要求：

- 数据源缺失时 `value=null` 或不输出该点。
- Flutter tooltip 中显示 `--`，不得显示 `0` 冒充真实成交额。

### turnover

```json
{
  "time": "2024-01-02",
  "raw_index": 0,
  "value": null
}
```

要求：

- easy-tdx 不能直接提供时保持 `null`。
- 后续如从外部财务/流通股本数据源补齐，需要在 `meta.indicator_sources.turnover` 标明来源。

### MA / BOLL / MACD

本轮建议先按“展示指标”处理，不改变 BSP 计算。

可选来源：

1. Python `chan.py` 已有指标对象导出。
2. 后端在 `a_adapter` 或 `a_export` 层做展示计算。
3. Flutter 端只做纯展示指标计算，但必须标注 `source=flutter_display_only`，并且不得参与缠论算法。

优先级：

```text
VOL > amount > MACD > MA > BOLL > turnover
```

## 6. Flutter 显示要求

- 主图：K线、merged_bars、FX、BI、SEG、ZS、BSP。
- 副图 1：VOL。
- 副图 2：MACD 或其他指标。
- 指标开关独立于缠论结构开关。
- 指标显示不得影响主图缩放、拖动、逐K回放。
- crosshair 同步主图与副图的 raw_index。

## 7. 错误处理

后端失败时返回：

```json
{
  "bars": [],
  "merged_bars": [],
  "fx": [],
  "bi": [],
  "seg": [],
  "zs": [],
  "bsp": [],
  "indicators": {},
  "frames": [],
  "meta": {
    "warning": "easy-tdx request failed: ..."
  }
}
```

Flutter 要求：

- 显示 warning。
- 不闪退。
- 不用旧 Dart 算法兜底重新算缠论。
- 可以只显示已存在的 K线或空状态。

## 8. 验收命令

```bash
flutter analyze
python tools/audit_dart_algorithm_usage.py
python tools/validate_chanpy_output_contract.py path/to/analysis.json
```

## 9. 后续实现顺序

1. 后端 bars 增加 amount / turnover 透传。
2. 后端增加 `indicators.vol` 输出。
3. Flutter 增加 VOL 副图。
4. 后端增加 MACD / MA / BOLL 展示指标输出。
5. Flutter 增加指标开关与 tooltip。
6. Android MethodChannel 输出合同与 Windows HTTP 输出合同保持一致。
