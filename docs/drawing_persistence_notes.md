# 手动画线持久化实现说明

状态：已完成代码接入。

## 范围

本实现只保存前端用户手动画线对象 `DrawingObject`，不保存、不计算、不推导任何缠论结构。

缠论元素仍然来自 Python chan.py / Vespa 口径后端输出，包括分型、笔、线段、中枢、BSP、合并 K 线。

## 存储 key

`OriginReplayPageV2` 显式向 `OriginKlineChart` 传入 `drawingStorageKey`。

当前 key 组成：

- 数据源：`easy_tdx` 或 `csv`；
- 标的：市场 + 代码，或 CSV 文件名；
- 周期：例如 `DAILY`；
- 复权：例如 `QFQ`。

## 功能

- 图表加载时自动读取本地 JSON；
- 新建、删除、锁定、隐藏、导入、拖拽结束后自动保存；
- 图表左下角提供导入 / 导出 JSON 浮条；
- 无画线时导出按钮灰度不可用。

## 文件

- `lib/ui/drawing/drawing_object_persistence.dart`
- `lib/ui/widgets/origin_kline_chart.dart`
- `lib/ui/pages/origin_replay_page_v2.dart`
- `pubspec.yaml`
