# S13 单股多级别复盘时间窗口、区间套链接与 step 当下性规则

## 数据范围规则

单股多级别复盘不再使用 `count` 控制取数数量。数据加载范围只由 `start` 和 `end` 决定。

- `start` 为空时，默认使用 `1990-01-01`。
- `end` 为空时，默认使用系统当前时间。
- 同时提供 `start` 与 `end` 时，严格使用该时间窗口。
- `start` 不得晚于 `end`。
- `count` 不得作为计算输入数据的裁剪条件。

## UI 结构规则

单股多级别复盘沿用历史版本“复盘”页面最左侧工具栏结构。

- 最左侧为垂直工具栏。
- 股票代码、市场、开始时间、结束时间、后端路径等股票基础设置，应放入工具栏对应的“股票基础设置”设置区。
- K 线图区域只负责显示、缩放、平移、十字光标和图层/指标交互，不再承载股票基础设置表单。

## 高速路与 chan.py 权限边界

- `python/chan.py` 仍然是唯一缠论结构计算源。
- Flutter/Dart 只负责时间窗口规范化、请求发起、显示、交互和证据复制。
- Flutter/Dart 不计算 FX / BI / SEG / ZS / BSP。
- `RuntimePathController.current` 默认使用 `high_speed`，S13 请求 `analyze_multi` 时透传 `runtime_path`。
- `slow_path` 只用于原始校验和调试，不作为默认生产路径。

## 区间套图上链接实现过程

### 第一步：从手动级别切换到图上链接

早期 S13 只有“加载级别”和“当前图表级别”切换。后续改为读取后端返回的 `LevelRelation`：

```text
parentLevel
parentRawIndex
childLevel
childStartRawIndex
childEndRawIndex
```

K 线图右上角显示“区间套链接”，每条关系显示为向下箭头：

```text
父级别@父rawIndex ↓ 子级别 childStart-childEnd
```

点击箭头后只切换图表显示级别和定位窗口，不重新计算缠论结构。

### 第二步：修复 step 下的当下性

step 模式下，S13 不读取最终 `analysis.snapshot`，而是读取当前帧：

```text
analysis.frames[_safeFrameIndex]
```

区间套链接只读取当前 frame 的 `relations`，并校验：

- `parentRawIndex` 不得超过当前父级别 K 线范围。
- `childStartRawIndex >= 0`。
- `childEndRawIndex >= childStartRawIndex`。
- `childEndRawIndex` 不得超过当前子级别 K 线范围。

点击区间套箭头不会修改 `_frameIndex`，因此不会跳到最终快照。

### 第三步：修复空值编译错误

`current.of(child)` 返回 `ChanSnapshot?`。之前直接访问 `childSnapshot.rawBars` 会导致 Flutter 编译错误。现规则是：

```text
childSnapshot == null 或 childSnapshot.rawBars.isEmpty 时禁止跳转，并提示当前帧无子级别 K 线。
```

## 未确认 BSP 的 step 行为

### 现象

在 step 模式下，`is_sure == false` 的 BSP 会随着 K 线推进消失。

### 原因

这不是前端主动过滤，而是当前 step frame 的 `snapshot.bsps` 已经不再包含该临时点。严格当下模式下，K 线图只显示当前 frame 中由后端返回的 BSP。

### 当前修正方向

- Dart parser 需要同时兼容后端字段 `confirmed` 和 `is_sure`。
- `confirmed == false` 的 BSP 标签继续以 `?` 标记。
- 若需要观察历史临时点，应使用 UI-only 的候选轨迹层；该轨迹层只能从历史 step frame 读取已出现过的未确认 BSP，不得反向写入 chan.py 结构。

## 实现约束

- 区间套链接、step 控制条、未确认 BSP 轨迹都属于 Flutter 显示层。
- 不得因为显示轨迹而修改 `analysis.snapshot` 或后端返回的原始 frame 数据。
- 任何 BSP 是否存在、是否确认，仍以当前 frame 的 chan.py 返回结果为准。
- 轨迹层只能作为观察工具，不得作为实盘信号源。
