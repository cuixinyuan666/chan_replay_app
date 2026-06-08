# TradingView 画线工具箱迁移计划

本计划用于把 TradingView Charting Library 风格的画线/工具箱能力逐步加入当前 Flutter K 线复盘页面，同时保持缠论计算只调用/显示后端或 Vespa chan.py 口径结果，不在前端自造缠论逻辑。

## 总原则

1. 画线工具属于前端交互层，可自绘、可持久化。
2. 缠论元素属于引擎输出层，分型、笔、线段、中枢、买卖点、合并K线均从现有 `ChanSnapshot` 或后端扩展字段读取。
3. 前端只做显示、筛选、样式、命中测试、拖拽编辑，不重新推导缠论结构。
4. 某个设置下不可用的操作必须灰度不可点击，不隐藏真实状态。
5. 每次小任务完成后推送 `origin_vespa_tdx`，再等待输入“继续”。

## 小任务拆分

### 1. 工具箱注册表与分类基座

状态：已完成。

新增 `lib/ui/drawing/tradingview_drawing_tool.dart`，定义 TradingView 风格工具枚举、中文标签、分组、点位数量、是否可持久化、是否依赖缠论快照。

### 2. 工具栏 UI 接入

状态：已完成。

已新增 `lib/ui/drawing/tradingview_toolbox_host.dart`，并在 `RootPage` 外层接入覆盖式 TradingView 工具箱入口：

- 分组显示：光标测量、线类、音叉、斐波那契/江恩、几何、文字标注、形态、预测测量、图标、缠论叠加。
- 灰度规则已封装在 Host：无K线时禁用需要时间/价格锚点的工具；无 `ChanSnapshot` 时禁用缠论叠加工具。
- 当前选择工具统一由 Host 保存，避免散落状态。
- 后续已把 Host 移入 `OriginKlineChart` 状态层，由图表直接创建手动画线。

### 3. 手动画线数据模型

状态：已完成。

已新增 `lib/ui/drawing/drawing_object.dart`，包括：

- `DrawingAnchorType`：区分 K线价格域锚点与屏幕锚点；
- `DrawingAnchor`：保存 `rawIndex/price` 或 `dx/dy`；
- `DrawingStyle`：保存颜色、线宽、透明度、虚线、填充、字体大小；
- `DrawingObject`：保存工具类型、锚点、样式、文字、锁定、隐藏、选中、创建/更新时间；
- `DrawingObjectCollection`：提供 upsert、remove、select、clearSelection、JSON 序列化/反序列化。

### 4. 最小可用绘制器

状态：已完成。

已新增 `lib/ui/drawing/drawing_object_painter.dart`，并把 `OriginKlineChart` 接入 `drawingObjects` 参数。当前绘制器支持：

- 趋势线 / 信息线 / 箭头线；
- 水平线 / 水平射线；
- 垂直线；
- 矩形；
- 文本 / 备注 / 价格标签；
- 测量尺 / 日期范围 / 价格范围 / 日期价格范围；
- 选中对象端点 handle 显示；
- 虚线线段绘制；
- 绘制层插入在缠论元素之后、十字光标之前。

这些工具只消费 `DrawingObject` 数据，不参与任何缠论结构计算。

### 5. 基础画线交互

状态：已完成。

已把 `TradingViewToolboxHost` 迁入 `OriginKlineChart` 状态层，支持：

- 工具箱受控选中状态；
- 图表点击转换为 `DrawingAnchor.chart(rawIndex, price)`；
- 单点工具点击即创建：水平线、水平射线、垂直线、文本、备注、价格标签；
- 双点工具二次点击创建：趋势线、信息线、箭头线、矩形、测量尺、日期/价格范围；
- 新建对象自动选中并显示端点 handle；
- 清空手动画线；
- 光标/十字光标模式继续保留原十字光标读取逻辑。

### 6. 选择、命中测试、拖拽编辑

实现：

- 点击选中对象；
- 端点拖拽；
- 整体移动；
- 删除；
- 锁定；
- 隐藏；
- ESC/右键取消。

### 7. 画线持久化

以本地 JSON 为第一阶段：

- 按市场、代码、周期、复权、数据源区分；
- 支持导出/导入；
- 后续可扩展到后端同步。

### 8. 缠论元素补全

只接入 Vespa/后端字段：

- `mergedBars` 合并K线外框；
- `bsp level=bi` 笔买卖点；
- `bsp level=seg` 线段买卖点；
- 文字和大小区分；
- 分型、笔、线段、中枢继续使用引擎输出。

### 9. 测试与验证

每步至少检查：

- `flutter analyze`；
- Windows 图表交互；
- Android 不可用项灰度；
- 缠论字段来源不被前端重算。
