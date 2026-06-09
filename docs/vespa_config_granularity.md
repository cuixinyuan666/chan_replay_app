# Vespa CChanConfig 配置颗粒度

状态：已对照 Vespa `Common/CEnum.py`、`ChanConfig.py`、`Bi/BiConfig.py`、`Seg/SegConfig.py`、`ZS/ZSConfig.py`、`BuySellPoint/BSPointConfig.py` 做一次配置颗粒度扩展。

## 枚举来源

### BSP_TYPE

来自 `Common/CEnum.py`：

- `1`
- `1p`
- `2`
- `2s`
- `3a`
- `3b`

Flutter 设置中 `bs_type` 已改为 `FilterChip` 枚举选择，不再要求手写逗号字符串。

### FX_CHECK_METHOD

来自 `Common/CEnum.py` / `Bi/BiConfig.py`：

- `strict`
- `loss`
- `half`
- `totally`

Flutter 设置中 `bi_fx_check` 使用下拉框。

### LEFT_SEG_METHOD

来自 `Common/CEnum.py` / `Seg/SegConfig.py`：

- `peak`
- `all`

Flutter 设置中 `left_seg_method` 使用下拉框。

### MACD_ALGO

来自 `Common/CEnum.py` / `BuySellPoint/BSPointConfig.py`：

- `area`
- `peak`
- `full_area`
- `diff`
- `slope`
- `amp`
- `volumn`
- `amount`
- `volumn_avg`
- `amount_avg`
- `turnrate_avg`
- `rsi`

Flutter 设置中 `macd_algo` 使用下拉框。

## 已覆盖到设置面板的配置项

### 回放 / 数据校验

- `skip_step`
- `kl_data_check`
- `max_kl_misalgin_cnt`
- `max_kl_inconsistent_cnt`
- `auto_skip_illegal_sub_lv`
- `print_warning`
- `print_err_time`

### BI

- `bi_algo`
- `bi_strict`
- `bi_fx_check`
- `gap_as_kl`
- `bi_end_is_peak`
- `bi_allow_sub_peak`

### SEG

- `seg_algo`
- `left_seg_method`

### ZS

- `zs_algo`
- `zs_combine`
- `zs_combine_mode`
- `one_bi_zs`

### 指标模型

- `mean_metrics`
- `trend_metrics`
- `macd.fast`
- `macd.slow`
- `macd.signal`
- `cal_demark`
- `cal_rsi`
- `cal_kdj`
- `rsi_cycle`
- `kdj_cycle`
- `boll_n`

### Demark

- `demark_len`
- `setup_bias`
- `countdown_bias`
- `max_countdown`
- `tiaokong_st`
- `setup_cmp2close`
- `countdown_cmp2close`

### BSP

- `bs_type`
- `divergence_rate`
- `min_zs_cnt`
- `bsp1_only_multibi_zs`
- `max_bs2_rate`
- `bs1_peak`
- `bsp2_follow_1`
- `bsp3_follow_1`
- `bsp3_peak`
- `bsp2s_follow_2`
- `max_bsp2s_lv`
- `strict_bsp3`
- `bsp3a_max_zs_cnt`
- `macd_algo`

## BSP 高级覆盖项

Vespa `CChanConfig.set_bsp_config()` 支持带后缀的 per-side / per-level 高级覆盖项。当前已支持以下后缀透传：

- `-buy`
- `-sell`
- `-segbuy`
- `-segsell`
- `-seg`

Flutter 设置页已新增“BSP 高级覆盖”折叠区。输入格式为每行一个 `key-suffix=value`：

设置页会同步显示“当前最终高级覆盖项”，用于确认“表单选择 → 自动生成专家文本 → `_chanConfig` → 后端”的链路没有断。

```text
# 买点 1.2 背驰比例覆盖
divergence_rate-buy=1.2

# 线段级别保持 Vespa 默认 slope
macd_algo-seg=slope

# 段买点启用严格三买
strict_bsp3-segbuy=true

# 卖点二买卖最大比例覆盖
max_bs2_rate-sell=0.8

# 线段级别 BSP 类型覆盖
bs_type-seg=1,2,3a
```

当前允许覆盖的 key：

- `divergence_rate`
- `min_zs_cnt`
- `bsp1_only_multibi_zs`
- `max_bs2_rate`
- `macd_algo`
- `bs1_peak`
- `bs_type`
- `bsp2_follow_1`
- `bsp3_follow_1`
- `bsp3_peak`
- `bsp2s_follow_2`
- `max_bsp2s_lv`
- `strict_bsp3`
- `bsp3a_max_zs_cnt`

实现边界：

- Flutter 只校验 `key-suffix=value` 语法和白名单，不解释缠论含义；
- `backend/app/main.py` 会从 `/api/chan/analyze` 的 query 参数中收集合法高级覆盖项；
- `/api/chan/analyze_bars` 通过 POST body 的 `config` 天然接收这些高级覆盖项；
- `backend/app/chanpy_engine.py` 会把高级覆盖项转成 `CChanConfig` 可接受的类型后透传；
- 前端不基于这些配置重算 BSP，BSP 仍只能来自 Python chan.py / Vespa 计算结果。

### 线段级 macd_algo 风险说明

`seg` / `segbuy` / `segsell` 属于线段级 BSP。Vespa 初始化线段 BSP 时会把买点和卖点的 `macd_algo` 默认设为 `slope`，因此前端表单只允许：

```text
macd_algo-seg=slope
macd_algo-segbuy=slope
macd_algo-segsell=slope
```

不建议在线段级 BSP 上使用 `area`。实测 `macd_algo-seg=area` 可能触发后端 fallback，表现为 K 线仍显示，但分型、笔、线段、中枢、BSP 全部为空。普通 `buy` / `sell` 暂不限制完整 MACD_ALGO 枚举；若未来发现具体组合触发 fallback，再按 suffix 做白名单收窄。

## 前后端同步

- Flutter `_chanConfig` 已输出上述基础配置和 BSP 高级覆盖配置；
- `PythonChanAnalysisSource.analyze()` 会把这些配置作为 query 传给 `/api/chan/analyze`；
- `PythonChanAnalysisSource.analyzeBars()` 会把这些配置放入 POST body；
- FastAPI `/api/chan/analyze` 已补齐基础 query 参数，并通过 `Request.query_params` 收集 BSP 高级覆盖项；
- `backend/app/chanpy_engine.py` 的 `_config_dict()` 已把基础参数和合法 BSP 高级覆盖项转换成 Vespa `CChanConfig` 接受的结构。

## 后续可优化项

当前 BSP 高级覆盖区采用专家文本格式，优点是改动小、覆盖完整、不会把设置页膨胀成重复矩阵。后续如需更强可用性，可以把常用组合拆成更友好的折叠表单：

- 买点覆盖 `buy`
- 卖点覆盖 `sell`
- 段买点覆盖 `segbuy`
- 段卖点覆盖 `segsell`
- 段默认覆盖 `seg`

即便后续做表单化，也仍应保持原则：Flutter 只负责配置录入、合法性提示和透传，不做 BSP 计算。
