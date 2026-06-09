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

## 前后端同步

- Flutter `_chanConfig` 已输出上述配置；
- `PythonChanAnalysisSource.analyze()` 会把这些配置作为 query 传给 `/api/chan/analyze`；
- `PythonChanAnalysisSource.analyzeBars()` 会把这些配置放入 POST body；
- FastAPI `/api/chan/analyze` 已补齐对应 query 参数；
- `backend/app/chanpy_engine.py` 的 `_config_dict()` 已把这些参数转换成 Vespa `CChanConfig` 接受的结构。

## 仍未展开的高级项

Vespa `CChanConfig.set_bsp_config()` 还支持带后缀的高级覆盖项：

- `*-buy`
- `*-sell`
- `*-segbuy`
- `*-segsell`
- `*-seg`

这类覆盖项属于 per-side / per-level 的专家级差异化配置，本次没有在 UI 中展开，避免把设置面板变成不可维护的重复矩阵。后续如需要，可单独增加“BSP 高级覆盖”折叠区，但仍必须直接透传到后端，不在 Flutter 侧解释逻辑。
