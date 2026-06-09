# 绘图层调用审计

状态：已对照 Vespa `Plot/PlotDriver.py` 与 `Plot/PlotMeta.py` 完成一次检查。

## Vespa 绘图层边界

Vespa `CPlotDriver.DrawElement()` 根据 `plot_config` 调用绘图函数，例如：

- `plot_kline` -> `draw_klu`
- `plot_kline_combine` -> `draw_klc`
- `plot_bi` -> `draw_bi`
- `plot_seg` -> `draw_seg`
- `plot_zs` -> `draw_zs`
- `plot_bsp` -> `draw_bs_point`
- `plot_segbsp` -> `draw_seg_bs_point`

这些函数只消费 `CChanPlotMeta` 中已经生成的结构，不在绘图层重新识别分型、笔、线段、中枢或买卖点。

## 当前项目应保持的调用链

当前项目前端不直接调用 Vespa 绘图类，而是使用等价的数据流：

```text
chan.py / CChan
  -> backend/app/chanpy_engine.py 导出结构字段
  -> PythonChanAnalysisSource 解析为 ChanSnapshot
  -> OriginReplayPageV2 控制显示开关和灰度
  -> OriginKlineChart 只消费 ChanSnapshot 绘图
```

## 本次发现并修复的问题

### 1. BSP 绘图价格锚点偏离 Vespa PlotMeta

Vespa `CBS_Point_meta` 使用：

- 买点：`bsp.klu.low`
- 卖点：`bsp.klu.high`

当前后端之前会优先尝试 `bi.get_end_val()`，这可能让 BSP 显示位置偏离 Vespa 绘图层。

已修复为：优先使用 `klu.low/high`，只有缺少 `klu` 价格时才兼容 fallback 到直接字段或 line end value。

### 2. seg BSP 关联索引命名不规范

Vespa `seg_bsp_lst` 中的 `CBS_Point` 对应的 line 是 `CSeg`，不是普通 `CBi`。

当前后端之前对 seg BSP 也写入 `bi_index`，容易误导前端或调试输出。

已修复为：

- `level=bi`：写入 `bi_index`；
- `level=seg`：写入 `seg_index`；
- 两者不混用。

## 本次确认没有越界的点

- `OriginKlineChart` 只使用 `snapshot.rawBars / mergedBars / fxs / bis / segs / zss / bsps` 绘图；
- `OriginReplayPageV2` 只做开关与灰度，不推导结构；
- 手动画线 `DrawingObject` 独立于缠论结构；
- 合并K线显示只来自后端 `merged_bars`，不会用 fallback 伪造。

## 后续仍建议检查

- 本地运行 `flutter analyze` 捕捉 Flutter API 层错误；
- 对 `OriginKlineChart` 做纯格式化，减少单行 UI / Painter 代码；
- 后端如新增 `segzs`、`eigen`、`segseg` 等 Vespa 绘图元素，应继续按后端字段扩展 `ChanSnapshot`，不要在 Flutter 中计算。
