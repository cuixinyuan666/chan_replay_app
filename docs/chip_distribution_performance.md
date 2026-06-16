# 筹码分布计算量与性能预算

## 当前在线阶段输入

当前分支只使用在线 `analyze_multi` 已返回到 Flutter 的 `ChanSnapshot.rawBars`：

```text
online analyze_multi -> ChanSnapshot.rawBars -> ChipOnlineReplayAdapter -> ChipDistributionEngine
```

不读取离线分笔文件，不扫描本地 tick 文件。

## 计算复杂度

令：

- `N` = 目标 K 线以前参与筹码累计的 K 线根数；
- `B` = 价格桶数量，当前默认 80；
- `T` = 如果后端返回 `chip_tick_bins`，逐价桶总数。

当前 OHLCV 三角分摊兜底的保守复杂度约为：

```text
O(N * B)
```

如果未来后端在线返回 `chip_tick_bins(p/s/b/w)`，逐价精确模式约为：

```text
O(T)
```

其中 `T` 通常远小于 “全部分笔逐笔数量”，因为后端已经按价格桶聚合过。

## 粗略量级

常见参数下：

- `N = 900`，`B = 80`：约 72,000 次价格桶加权；
- `N = 3,000`，`B = 80`：约 240,000 次；
- `N = 10,000`，`B = 80`：约 800,000 次；
- `N = 10,000`，`B = 160`：约 1,600,000 次。

这类计算在 Dart 中通常不是主要瓶颈。真正更容易变慢的是：

1. 后端 `analyze_multi` 本身的 chan.py 计算；
2. step frames 的 JSON 体积；
3. Flutter 对大数组反复 setState 重绘；
4. 每次鼠标移动或 crosshair 变动都全量重算筹码。

## 当前风险

如果把筹码面板直接绑定到 crosshair hover，每次 hover 都重新计算 `N * B`，在大 `N` 下会卡顿。

## 建议优化顺序

### 第一阶段：Flutter/Dart 内缓存

- 以 `(level, frameIndex, targetIndex, binCount, ageDecay, bars.length)` 做 cache key；
- crosshair 只在目标 K 变化时计算；
- 使用 debounce/throttle，避免鼠标每个像素移动都重算；
- 面板关闭时不计算。

### 第二阶段：前缀累计缓存

如果仍慢，可把每根 K 的价格桶贡献预先转换为固定 `B` 维数组，做 prefix sum：

```text
prefix[i][bucket] = prefix[i-1][bucket] + contribution(i,bucket)
```

查询任意目标 K 时接近：

```text
O(B)
```

代价是内存增加：`N * B * double`。

举例：`N=10,000, B=80`，double 8 字节，单侧约 6.4MB，买卖两侧约 12.8MB，仍可接受，但要注意多级别、多股票、多 frame 时的累计内存。

### 第三阶段：后端预聚合

如果后端在线能返回 `chip_tick_bins(p/s/b/w)`，前端不需要从 OHLCV 猜分布，可直接消费聚合桶，精度更高。

### 第四阶段：换语言或 isolate

只有在以下条件同时出现时，才值得考虑换语言或 isolate：

- 参与 K 线超过数万；
- 桶数超过 200；
- crosshair 高频交互需要实时重算；
- 手机端或低性能设备出现明显卡顿。

可选方案：

1. Dart isolate：最小架构变动，适合把计算移出 UI 线程；
2. Rust/C++ FFI：性能最好，但跨平台打包复杂，Flutter Android/Windows 都要处理动态库；
3. Python 后端预聚合：与现有 app-managed Python 一致，但交互式 crosshair 会有通信延迟，不适合每次鼠标移动请求。

## 当前结论

当前在线阶段优先保持 Dart 实现更合适：

- 数据已在 Flutter 内存；
- 算法量级可控；
- 避免额外 IPC/FFI；
- 更容易和 S13 页面状态联动。

真正需要优化时，优先做 cache 和 prefix-sum，而不是立刻换语言。
