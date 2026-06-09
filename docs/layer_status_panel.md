# 图层状态面板

## 目标

图层状态面板用于把“后端是否返回数据”和“前端是否开启显示”分开展示，避免把“没数据”和“被关闭”混淆。

## 覆盖图层

- FX：分型
- BI：笔
- SEG：线段
- ZS：中枢
- 笔BSP：`level=bi` 或普通 BSP
- 段BSP：`level=seg` / `segment`
- 合并K线：`merged_bars`

## 显示规则

每行展示三类信息：

```text
图层名    后端 N    显示 开/关    有效可见图标
```

- 后端 N：来自 Python chan.py 返回的结构数量，使用 `_fullSnapshot` 统计。
- 显示 开/关：来自 Flutter 用户开关状态。
- 有效可见：只有“后端有数据 + 前端开关开启”才是实际可见。

## 边界

Flutter 只展示状态，不计算 FX / BI / SEG / ZS / BSP / `merged_bars`。
这些结构仍必须来自 Python chan.py / Vespa 后端。
