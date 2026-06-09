# Vespa chan.py 对齐颗粒度

状态：已检查并固化为前后端边界。

## 目标

Flutter 前端只做显示、筛选、样式和交互，不复刻、不推导、不补算缠论结构。

缠论结构颗粒度以 Python chan.py / Vespa 口径后端输出为准。

## 后端输出颗粒度

`backend/app/chanpy_engine.py` 的 `_export_level` 当前导出以下结构：

- `merged_bars`：合并K线；
- `fx`：分型；
- `bi`：笔；
- `seg`：线段；
- `zs`：中枢；
- `bsp`：买卖点，含 `level=bi` / `level=seg` 区分。

逐K模式 `step_load` 每个 frame 也沿用同一套字段颗粒度：

- `bars`
- `merged_bars`
- `fx`
- `bi`
- `seg`
- `zs`
- `bsp`

## 前端解析颗粒度

`PythonChanAnalysisSource` 只把后端字段转换为 `ChanSnapshot`：

- `bars` -> `rawBars`
- `merged_bars` / `mergedBars` -> `mergedBars`
- `fx` -> `fxs`
- `bi` -> `bis`
- `seg` -> `segs`
- `zs` -> `zss`
- `bsp` / `bsps` -> `bsps`

其中合并K线 fallback 已拆分：

- `backendMergedBars` 进入 `ChanSnapshot.mergedBars`；
- `structuralMergedBars` 只用于内部解析 `fx` / `bi` 锚点；
- fallback 不进入 UI 显示字段。

## 前端显示颗粒度

`OriginReplayPageV2` 左侧工具栏只根据 `ChanSnapshot` 字段存在性控制灰度：

- 分型：`fxs`
- 分型连线：`fxs.length >= 2`
- 笔：`bis`
- 线段：`segs`
- 中枢：`zss`
- 笔买卖点：`bsps` 中非 seg level
- 线段买卖点：`bsps` 中 seg level
- 合并K线：`mergedBars`

`OriginKlineChart` 只消费这些字段绘图，不产生新的缠论结构。

## 禁止项

- 禁止 Flutter 根据 K线自行识别分型；
- 禁止 Flutter 根据分型自行连笔；
- 禁止 Flutter 根据笔自行生成线段；
- 禁止 Flutter 根据笔/线段自行生成中枢；
- 禁止 Flutter 根据走势自行判断 BSP；
- 禁止 Flutter 用普通K线伪造合并K线显示。

## 允许项

- 前端允许控制是否显示某类后端字段；
- 前端允许调整颜色、文字、大小、透明度、命中测试；
- 前端允许手动画线，但手动画线必须作为 `DrawingObject` 独立存在，不与缠论字段混淆；
- 不可用显示入口保持灰度不可点击，不隐藏。
