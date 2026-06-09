# 合并K线显示契约

状态：已整理。

## 原则

`snapshot.mergedBars` 只代表 Python chan.py / Vespa 后端实际返回的 `merged_bars` / `mergedBars`。

Flutter 前端不在显示层自造合并K线，也不把普通 K 线伪装成合并K线。

## 内部兼容 fallback

`PythonChanAnalysisSource` 解析 `fx` / `bi` 时需要通过 rawIndex 找到一个 `MergedBar` 锚点。

当后端没有返回合并K线字段时，解析器内部会临时用“一根原始K线对应一个临时 MergedBar”的结构锚点，避免分型和笔解析失败。

这个 fallback 只用于内部解析，最终不会写入 `ChanSnapshot.mergedBars`。

## UI 行为

- 后端返回 `merged_bars` / `mergedBars`：左侧“显示合并K线”按钮可用，图表绘制外框；
- 后端未返回该字段或返回空：按钮灰度不可用，图表不显示合并K线外框。

这保证了合并K线显示始终是后端字段展示，而不是 Flutter 前端重算。
