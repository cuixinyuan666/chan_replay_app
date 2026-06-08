# chan_replay_app - origin_vespa_tdx

`origin_vespa_tdx` 基于 `vespa_tdx` 创建，目标是把 Vespa/chan.py 作为唯一缠论计算源。

## 核心架构

```text
Flutter UI
  ↓ JSON / localhost HTTP
Python chan.py 引擎
  ↓
返回 bars / FX / BI / SEG / ZS / BSP JSON
  ↓
Flutter 只负责 candlesticks 绘图、回放控制、缩放拖动、图层显示
```

## 平台方案

```text
Android：Chaquopy 类方案，把 CPython、easy-tdx、chan.py 打进 APK。
Windows：Flutter 启动本地 Python HTTP 服务，服务内调用 chan.py + easy-tdx。
```

Windows 打包方向：

```text
python/
  python.exe
  Lib/
  site-packages/
  chan.py/
  easy_tdx/
  app_engine.py
```

当前分支优先使用本地 HTTP 服务模式，而不是每次 stdin/stdout 启动一次 Python。这样更适合逐K回放、暂停、跳转、缓存和多次请求。

## Dart / Python 职责边界

```text
Dart 算法层：删除或弱化，不再复刻 chan.py 的 FX / BI / SEG / ZS 规则。
Dart 展示层：保留并强化。
Python 算法层：成为唯一真源。
```

Dart 仍保留这些展示模型和状态对象：

```text
KLineModel
FxDrawModel
BiDrawModel
SegDrawModel
ZsDrawModel
ReplayState
ChartViewport
```

它们只负责：

```text
解析 Python 返回 JSON
绘制到 candlesticks 图层上
支持缩放、拖动、逐K播放、显示开关
```

## Python 引擎接口

### 一次性模式

Flutter 请求：

```json
{
  "mode": "once",
  "symbol": "000001",
  "freq": "DAY",
  "start": "2020-01-01",
  "end": "2024-08-05",
  "adjust": "QFQ",
  "data_source": "easy_tdx"
}
```

Python 返回：

```json
{
  "bars": [],
  "fx": [],
  "bi": [],
  "seg": [],
  "zs": [],
  "bsp": [],
  "meta": {
    "engine": "chan.py",
    "version": "unknown",
    "symbol": "000001",
    "name": "平安银行",
    "freq": "DAY"
  }
}
```

### 严格逐K模式

逐K模式使用 chan.py 真 step 模式，不使用 Flutter 过滤未来结构。

依据 `quick_guide.md` 的策略实现 / 回测说明：

```text
打开 CChanConfig.trigger_step。
CChan 初始化时不做完整计算。
手动调用 CChan.step_load()。
每喂一根 K 线后返回当前 CChan，可获取当前位置静态元素。
每一帧不是完全重算，只重新计算不确定部分。
```

## 页面约束

本分支删除旧选项卡名称：

```text
本地复盘
Vespa对齐
```

App 入口应直接呈现复盘界面，不再显示“本地复盘 / Vespa对齐” Tab。Vespa 对齐工具可保留在 `tools/chanpy_compare` 作为开发工具，但不再作为 App 页面。

## 当前注意事项

此前长样本 diff 显示 Dart 复刻算法仍在 BI 初始化处与 chan.py 不一致：FX 已 0 mismatch，但 BI 少第一笔，导致 SEG / ZS 索引错位。因此本分支不再继续追 Dart 复刻，而改为 Python chan.py 单一计算源。
