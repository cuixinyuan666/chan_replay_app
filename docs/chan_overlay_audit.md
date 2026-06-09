# 缠论元素显示入口审计

状态：已整理。

## 原则

前端只显示 `ChanSnapshot` 中已有字段，不在 Flutter 侧计算或推导分型、笔、线段、中枢、BSP、合并 K 线。

## 字段来源

`PythonChanAnalysisSource` 从 Python chan.py / Vespa 口径后端解析：

- K线：`bars`
- 合并K线：`merged_bars` / `mergedBars`
- 分型：`fx`
- 笔：`bi`
- 线段：`seg`
- 中枢：`zs`
- 买卖点：`bsp` / `bsps`

这些字段进入 `ChanSnapshot` 后，由 Flutter 图表消费显示。

## 显示入口

`OriginReplayPageV2` 左侧工具栏已按后端字段存在性灰度：

- 分型：`_fullSnapshot.fxs.isNotEmpty`
- 分型连线：`_fullSnapshot.fxs.length >= 2`
- 笔：`_fullSnapshot.bis.isNotEmpty`
- 线段：`_fullSnapshot.segs.isNotEmpty`
- 中枢：`_fullSnapshot.zss.isNotEmpty`
- 笔 BSP：`_fullSnapshot.bsps.any(_isBiBsp)`
- 线段 BSP：`_fullSnapshot.bsps.any(_isSegBsp)`
- 合并K线：`_fullSnapshot.mergedBars.isNotEmpty`

不可用入口保持灰度不可点击，不隐藏。

## BSP level 规则

当前前端只做 level 分类显示，不计算买卖点：

- `level=seg` / `level=segment` / 包含 `seg`：线段买卖点；
- 空 level、`level=bi`、非 seg level：笔买卖点。

## 图表绘制

`OriginKlineChart` 只根据传入的 `ChanSnapshot` 绘制：

- `snapshot.mergedBars` 画合并K线外框；
- `snapshot.fxs` 画分型和分型连线；
- `snapshot.bis` 画笔；
- `snapshot.segs` 画线段；
- `snapshot.zss` 画中枢；
- `snapshot.bsps` 画笔/线段 BSP。

手动画线 `DrawingObject` 是独立前端对象，不参与缠论计算。

## 后续建议

后端如果新增 `seg_zs`、特征序列框等字段，前端也应只以 `ChanSnapshot` 字段接入显示，不在 Flutter 侧重算。
