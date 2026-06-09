# K线图文字与标签避让策略

本文件定义 `OriginKlineChart` 后续实现文字、数字、BSP、BI、SEG、ZS 标签避让时必须遵守的规则。目标：**图上不再默认全量堆叠文字，密集区域优先显示结构，详情交给 crosshair / tooltip / 侧栏**。

## 1. 图层优先级

绘制顺序应保持：

```text
1. 背景 / 网格 / 坐标轴
2. K线蜡烛图
3. merged_bars 外框
4. ZS 中枢矩形
5. FX 连线
6. BI 线
7. SEG 线
8. BSP 图形点位
9. FX 点位
10. 手动画线
11. label lane 文本层
12. crosshair / hover 信息层
```

原则：

- 结构线优先于文本。
- 文本永远在最后集中布局。
- crosshair 信息优先级最高。

## 2. 默认显示策略

| 元素 | 默认 | 原因 |
| --- | --- | --- |
| K线 OHLC 数字 | 关闭，仅 crosshair 显示 | 避免价格轴和顶部状态重叠 |
| FX 顶/底文字 | 可开关，窗口过大时自动降密度 | 顶/底在密集区容易遮挡 K线 |
| BI 编号 | 默认关闭 | 笔数量多，极易糊图 |
| SEG 编号 | 可开关，窗口过大时自动降密度 | 线段数量较少，可保留但必须避让 |
| ZS 标签 | 默认只显示 `ZS序号`，必要时缩略 | 中枢矩形内部文字容易覆盖 |
| BSP 标签 | 默认显示简写；密集时只显示点位 | BSP 是重点，但不能全量糊图 |
| VOL/指标数值 | crosshair 显示 | 副图避免文字堆叠 |

## 3. label lane 模型

### 3.1 标签对象

后续实现时建议将所有文字先转为统一对象：

```text
ChartLabel
- text
- anchorX
- anchorY
- preferredSide: top / bottom / right / inside
- priority: crosshair > bsp > seg > bi > zs > fx > grid
- rawIndex
- color
- fontSize
- visibleWhenWindowLE
```

所有 label 不直接 paint，而是进入统一布局器。

### 3.2 碰撞规则

布局器维护已占用矩形列表：

```text
occupiedRects: List<Rect>
```

每个 label 先按 preferredSide 生成候选位置：

```text
sell BSP: 上方 1 → 上方 2 → 右侧 → 隐藏文字，仅保留点位
buy BSP : 下方 1 → 下方 2 → 右侧 → 隐藏文字，仅保留点位
BI/SEG  : 端点旁 → 斜向错层 → 隐藏编号
ZS      : 矩形内左上 → 矩形外上方 → 隐藏文字
FX      : 顶上/底下 → 隐藏文字
```

若候选 `Rect` 与已占用区域相交，则尝试下一候选；全部失败时按优先级决定是否隐藏。

## 4. 密度控制

以 `windowSize` 或 `visible.length` 作为降密度依据：

| 可见 K线数量 | 策略 |
| --- | --- |
| `<= 120` | 可显示 BSP 文本、SEG 文本、少量 FX 文本 |
| `121 ~ 360` | BSP 仅显示高优先级文本，BI/SEG 编号降采样 |
| `> 360` | 默认只显示结构点位，不显示普通标签 |

降采样规则：

```text
label.rawIndex % densityStep == 0
```

但 BSP 优先级高于 BI/SEG/FX，BSP 可以先保留图形点位，文字再根据碰撞决定。

## 5. BSP 专用规则

### 5.1 笔买卖点 / 线段买卖点区分

| level | 图形 | 文本 |
| --- | --- | --- |
| `bi` 或空 | 小三角 | `笔1` / `笔2s` / `笔3a` |
| `seg` | 大三角或描边三角 | `段1` / `段2s` / `段3b` |

### 5.2 多类型合并

同一 raw_index / price 上多个类型：

```text
笔1,2s
段1p,3a
```

不允许生成多个完全重叠标签。

### 5.3 不确定 BSP

`is_sure=false`：

- 点位降低透明度。
- 文本追加 `?` 或使用虚线边框。
- tooltip 中明确显示“不确定”。

## 6. ZS 标签规则

- 中枢矩形内只显示 `ZS1` 这种短标签。
- 不在矩形内显示高低点、开始结束时间等长文本。
- 完整信息放到 tooltip / 侧栏。
- 多个中枢重叠时只显示最新或最高优先级标签。

## 7. crosshair 信息规则

crosshair 激活时，顶部信息条显示当前 raw_index 的：

```text
时间 / O / H / L / C / VOL / amount / turnover
FX / BI / SEG / ZS / BSP 命中信息
```

要求：

- crosshair 信息可以覆盖普通 label。
- 普通 label 不得覆盖 crosshair 信息条。
- crosshair 退出后恢复避让布局。

## 8. 验收标准

### 8.1 静态样本

- 300 根：BSP、SEG、ZS 开启后仍清晰。
- 1000 根：结构线清楚，普通标签自动减少。
- 3000 根：默认不出现大面积文字糊图。

### 8.2 交互样本

- 缩放时 label 不跳乱。
- 拖动时 label 与 K线 raw_index 对齐。
- 逐K回放时新增/消失的 BSP 文本不会残留。
- crosshair 显示详情时，不被状态栏或价格轴遮挡。

## 9. 实现建议

第一步：在 `OriginKlineChart` 内新增私有 label 布局器，不改变模型层。

建议文件内类：

```text
_ChartLabel
_LabelLayout
_LabelCandidate
```

第二步：把 `_drawFx / _drawBi / _drawSeg / _drawZs / _drawBsp` 中的 `_drawText` 改为收集 label。

第三步：在所有结构线和点位绘制完成后统一：

```text
_layoutLabels(...)
_drawLaidOutLabels(...)
```

第四步：将 `windowSize`、`showBiText`、`showSegText`、`showBiBsp`、`showSegBsp` 纳入 label 过滤。

该实现只改 Flutter 绘图层，不碰 `chan.py`。
