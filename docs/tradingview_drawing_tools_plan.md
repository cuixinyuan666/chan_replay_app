# TradingView 风格画线工具箱与 chan.py 缠论元素接入计划

> 分支：`origin_vespa_tdx`
>
> 目标：在 Flutter 原生 K 线图上实现 TradingView Charting Library 风格的完整画线/工具箱分类，同时继续坚持 `Vespa314/chan.py` 是唯一缠论计算源，Flutter 只做展示、交互、图层管理和用户手动画线。

## 0. 重要边界

1. 不在 Dart/Flutter 里复刻缠论算法。
2. 分型、笔、线段、中枢、买卖点、合并 K 线、逐 K 帧等全部来自 Python `chan.py` 后端返回值。
3. Flutter 新增的画线工具只处理用户交互形状，例如趋势线、水平线、矩形、文字、测量、斐波那契等。
4. 自动缠论图层与用户手动画线图层必须分离：
   - `chan.py layer`：FX / BI / SEG / ZS / BSP / merged_bars，只读展示。
   - `drawing layer`：用户新增、编辑、删除、隐藏、锁定、保存的画线对象。
5. TradingView Charting Library 本身是 JS/HTML/CSS 客户端库。当前项目主图是 Flutter `CustomPainter`，因此本计划实现“TradingView 风格工具箱”，不是直接打包 TradingView 私有库。

## 1. TradingView 官方画线工具分类清单

参考：

- https://www.tradingview.com/charting-library-docs/latest/ui_elements/drawings/Drawings-List/
- https://www.tradingview.com/charting-library-docs/latest/ui_elements/drawings/drawings-api/

### 1.1 Trend Line Tools

- Trend Line
- Arrow
- Ray
- Info Line
- Extended Line
- Trend Angle
- Horizontal Line
- Horizontal Ray
- Vertical Line
- Cross Line
- Parallel Channel
- Regression Trend
- Flat Top/Bottom
- Disjoint Channel
- Anchored VWAP

### 1.2 Gann and Fibonacci Tools

- Fib Retracement
- Trend-Based Fib Extension
- Pitchfork
- Schiff Pitchfork
- Modified Schiff Pitchfork
- Inside Pitchfork
- Fib Channel
- Fib Time Zone
- Gann Box
- Gann Square Fixed
- Gann Square
- Gann Fan
- Fib Speed Resistance Fan
- Trend-Based Fib Time
- Fib Circles
- Pitchfan
- Fib Spiral
- Fib Speed Resistance Arcs
- Fib Wedge

### 1.3 Geometric Shapes

- Brush
- Highlighter
- Rectangle
- Circle
- Ellipse
- Path
- Curve
- Polyline
- Triangle
- Rotated Rectangle
- Arc
- Double Curve

### 1.4 Annotation Tools

- Text
- Anchored Text
- Note
- Anchored Note
- Signpost
- Callout
- Comment
- Price Label
- Price Note
- Arrow Marker
- Arrow Mark Left
- Arrow Mark Right
- Arrow Mark Up
- Arrow Mark Down
- Flag Mark

### 1.5 Patterns

- XABCD Pattern
- Cypher Pattern
- ABCD Pattern
- Triangle Pattern
- Three Drives Pattern
- Head and Shoulders
- Elliot Impulse Wave (12345)
- Elliot Triangle Wave (ABCDE)
- Elliot Triple Combo Wave (WXYXZ)
- Elliot Correction Wave (ABC)
- Elliot Double Combo Wave (WXY)
- Cyclic Lines
- Time Cycles
- Sine Line

### 1.6 Predictions and Measurement Tools

- Long Position
- Short Position
- Forecast
- Date Range
- Price Range
- Date and Price Range
- Bars Pattern
- Ghost Feed
- Projection
- Fixed Range Volume Profile

### 1.7 Icons / Stickers / Emojis

- Icons
- Stickers
- Emojis

### 1.8 Actions

- Measure
- Zoom In
- Magnets
  - Weak Magnet
  - Strong Magnet
- Stay in Drawing Mode
- Lock All Drawing Tools
- Hide All Drawings
- Remove X Drawings

## 2. Flutter 侧目标架构

建议新增模块：

```text
lib/core/drawing/
  drawing_tool.dart              # 工具枚举、分类、元数据、点数要求
  drawing_object.dart            # 用户画线对象模型
  drawing_anchor.dart            # time/rawIndex/price/screen-percent 锚点
  drawing_style.dart             # 颜色、线宽、虚线、填充、文字样式
  drawing_store.dart             # 序列化、反序列化、按 symbol/freq 保存
  drawing_hit_test.dart          # 命中测试、选择、拖拽控制点

lib/ui/widgets/drawing/
  drawing_toolbar.dart           # 左侧工具箱分组 UI
  drawing_overlay_painter.dart   # 用户画线图层绘制
  drawing_interaction_layer.dart # 点击取点、拖拽、编辑、删除
```

现有 `OriginKlineChart` 保持负责：

```text
K线坐标系 + chan.py 图层 + crosshair + 缩放拖动
```

新增 drawing layer 通过同一套坐标转换函数绘制，避免坐标系重复。

## 3. 分步任务计划

### 小任务 1：计划与差距清单

状态：已完成本文档。

输出：

- 固化 TradingView 官方工具分类。
- 固化项目边界：Flutter 不创造缠论逻辑，chan.py 是唯一算法源。
- 明确后续实现模块路径。

### 小任务 2：新增画线工具元数据模型

目标：只新增 Dart 模型，不改 UI 行为。

内容：

1. `DrawingToolCategory` 枚举。
2. `DrawingToolType` 枚举，覆盖上面 7 类工具。
3. `DrawingToolSpec` 元数据：中文名、英文名、分类、所需点数、是否支持文本、是否支持填充、是否第一阶段可绘制。
4. 提供 `DrawingToolRegistry.all`。
5. 增加基础单元测试或至少保证 `flutter analyze` 不报错。

### 小任务 3：新增用户画线对象数据结构

目标：建立可保存、可恢复的画线对象模型。

内容：

1. `DrawingAnchor`：支持 `rawIndex + price`、`time + price`、`screenPercent` 三种锚点。
2. `DrawingObject`：id、toolType、anchors、style、text、locked、hidden、createdAt、updatedAt。
3. JSON 序列化/反序列化。
4. 不接入 painter，避免一次改太大。

### 小任务 4：接入最小工具箱 UI

目标：左侧工具栏加入“画线工具”入口。

内容：

1. 增加工具箱弹层/抽屉。
2. 按 TradingView 分类显示完整工具列表。
3. 第一阶段不可绘制的复杂工具灰度不可操作。
4. 可绘制工具先开放：Trend Line、Arrow、Ray、Horizontal Line、Vertical Line、Rectangle、Text、Price Range、Date Range、Date and Price Range。

### 小任务 5：实现基础画线图层

目标：用户可在 K 线上手动画线。

内容：

1. Trend Line / Arrow / Ray / Horizontal Line / Vertical Line。
2. Rectangle / Text。
3. 坐标锚点吸附 K 线 rawIndex。
4. 与 crosshair、缩放、拖动共存。
5. 只改展示和交互，不触碰 chan.py 逻辑。

### 小任务 6：实现选择、删除、锁定、隐藏、Stay in Drawing Mode

目标：补齐 TradingView 常用画线操作。

内容：

1. 单击选中。
2. 控制点拖拽。
3. Delete 删除。
4. 锁定单个对象。
5. 隐藏单个对象。
6. 全部隐藏 / 全部锁定 / 删除当前选中。

### 小任务 7：实现测量工具

目标：完成复盘高频功能。

内容：

1. Date Range。
2. Price Range。
3. Date and Price Range。
4. Measure 临时测量。
5. 显示 K 数、天数、涨跌幅、价格差。

### 小任务 8：实现 Fibonacci / Gann 第一批

目标：先做交易最常用的比例工具。

内容：

1. Fib Retracement。
2. Trend-Based Fib Extension。
3. Fib Channel。
4. Gann Fan。
5. Gann Box。

### 小任务 9：实现形态工具第一批

目标：支持手动画形态，不做自动识别。

内容：

1. ABCD Pattern。
2. Triangle Pattern。
3. Head and Shoulders。
4. Elliott Impulse Wave。
5. Elliott Correction Wave。

### 小任务 10：缠论元素完整接入校验

目标：对照 `Vespa314/chan.py`，保证前端只消费后端元素。

检查项：

1. `merged_bars`：合并 K 线外框字段、起止 raw index、高低点。
2. `fx`：顶/底、价格、raw index、is_sure。
3. `bi`：起止 raw index、起止价格、方向、is_sure。
4. `seg`：起止 raw index、起止价格、方向、is_sure。
5. `zs`：start/end、zg/zd/gg/dd、是否跨段、is_sure。
6. `bsp`：type、is_buy/is_sell、price、raw_index、level=bi/seg。
7. `frames`：严格逐 K 模式只消费 `CChan.step_load()` 的结果。

### 小任务 11：保存/恢复画线

目标：复盘时画线不丢。

内容：

1. 按 `symbol + period + adjust + dataSource` 保存。
2. Windows 本地文件保存。
3. Android SharedPreferences 或本地文件保存。
4. 预留导入/导出 JSON。

### 小任务 12：复杂工具补全与回归

目标：补足剩余 TradingView 风格工具。

内容：

1. Pitchfork 系列。
2. Gann Square / Gann Square Fixed。
3. Cycles / Sine Line。
4. Long Position / Short Position。
5. Icons / Emojis。
6. 固定范围成交量分布需先确认后端是否提供足够成交量分布数据，否则作为独立后续任务。

## 4. 小任务验收规则

每个小任务完成后默认执行：

```text
1. 代码提交到 origin_vespa_tdx。
2. 汇报本次改动文件。
3. 说明是否已运行 flutter analyze。
4. 提出下一次小任务。
5. 等待用户输入“继续”。
```

如果当前执行环境不能运行 Flutter，则必须明确说明，并尽量通过静态审查降低风险。

## 5. 当前仓库已观察到的现状

- `README.md` 已声明 `origin_vespa_tdx` 目标是把 Vespa/chan.py 作为唯一缠论计算源。
- `pubspec.yaml` 已包含 `candlesticks`、`http`、`file_picker`、`url_launcher`。
- `RootPage` 已直接进入 `OriginReplayPageV2`。
- `OriginReplayPageV2` 已有 FX / BI / SEG / ZS / 笔 BSP / 段 BSP / merged_bars 开关。
- `OriginKlineChart` 当前使用 `CustomPainter` 绘制 K 线、chan.py 图层、BSP、merged_bars、crosshair。

## 6. 下一步

等待输入“继续”后进入小任务 2：新增 `lib/core/drawing/` 下的画线工具元数据模型。