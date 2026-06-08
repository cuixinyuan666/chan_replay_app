# chan_replay_app - origin_vespa_tdx

`origin_vespa_tdx` 基于 `vespa_tdx` 创建，目标是把 Vespa/chan.py 作为唯一缠论计算源。

## 核心架构

```text
Flutter UI
  ↓ JSON / localhost HTTP / Android MethodChannel
Python chan.py 引擎
  ↓
返回 bars / merged_bars / FX / BI / SEG / ZS / BSP / frames JSON
  ↓
Flutter 只负责 candlesticks 绘图、回放控制、缩放拖动、图层显示
```

## 平台方案

```text
Android：Chaquopy 类方案，把 CPython、easy-tdx、chan.py 打进 APK。
Windows：Flutter 自动后台启动本地 Python HTTP 服务，服务内调用 chan.py + easy-tdx。
```

Android 打包要求：

```text
1. 将 Vespa/chan.py 仓库复制或克隆到项目根目录 python/chan.py。
2. Gradle 会通过 Chaquopy sourceSets 把 ../../python/chan.py 打入 APK。
3. Android 运行时通过 chan_replay_app/python_chan MethodChannel 调用 chanpy_runtime.py。
4. chanpy_runtime.py 会调用 CChan，导出 FX / BI / SEG / ZS / BSP / merged_bars / frames。
5. 如果 APK 内无法导入 chan.py，会降级只显示 K线，并在 meta.warning 中说明原因。
```

Windows 打包方向见：

```text
docs/windows_embedded_python.md
```

最终 Windows 目录：

```text
python/
  python.exe
  python311.dll
  python311.zip
  Lib/
  site-packages/
  app_engine.py
  requirements-windows.txt
  chan.py/
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
BspPoint
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
  "data_source": "easy_tdx",
  "config": {
    "bi_algo": "normal",
    "bi_strict": true,
    "seg_algo": "chan",
    "zs_algo": "normal",
    "zs_combine": true,
    "zs_combine_mode": "zs",
    "one_bi_zs": false,
    "bs_type": "1,1p,2,2s,3a,3b",
    "divergence_rate": "1e18",
    "min_zs_cnt": 1,
    "max_bs2_rate": "0.9999",
    "bs1_peak": true,
    "bsp2_follow_1": true,
    "bsp3_follow_1": true,
    "bsp3_peak": false,
    "bsp2s_follow_2": false,
    "strict_bsp3": false,
    "bsp3a_max_zs_cnt": 1,
    "macd_algo": "peak"
  }
}
```

Python 返回：

```json
{
  "bars": [],
  "merged_bars": [],
  "fx": [],
  "bi": [],
  "seg": [],
  "zs": [],
  "bsp": [],
  "frames": [],
  "meta": {
    "engine": "chan.py",
    "version": "external",
    "symbol": "000001.SZ",
    "name": "000001",
    "freq": "DAY"
  }
}
```

### CChanConfig 设置

Flutter V2 设置面板中的 `CChanConfig` 分为三组：

```text
结构识别：bi_algo / bi_strict / seg_algo
中枢 ZS：zs_algo / zs_combine / zs_combine_mode / one_bi_zs
买卖点 BSP：bs_type / divergence_rate / min_zs_cnt / max_bs2_rate / bs1_peak /
           bsp2_follow_1 / bsp3_follow_1 / bsp3_peak / bsp2s_follow_2 /
           strict_bsp3 / bsp3a_max_zs_cnt / macd_algo
```

加载前修改配置，点击“应用并重新计算”会直接按新配置请求 Python chan.py；加载后修改配置，也会重新请求 Python chan.py 并刷新 FX / BI / SEG / ZS / BSP。

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

当前后端和 Android `mode=step` 均走 `CChan.step_load()` 并返回 `frames`；Flutter V2 页面会直接消费 `frames`，不再用前端切片模拟逐K。

### 本地 CSV 模式

后端已提供：

```text
POST /api/chan/analyze_bars
```

请求体：

```json
{
  "mode": "once",
  "symbol": "local_csv",
  "freq": "DAILY",
  "adjust": "QFQ",
  "config": {},
  "bars": []
}
```

Flutter V2 页面已经支持本地 CSV 选择、解析成 bars，并提交给 `/api/chan/analyze_bars` 或 Android `python_chan` MethodChannel。

## 页面约束

本分支删除旧选项卡名称：

```text
本地复盘
Vespa对齐
```

App 入口应直接呈现复盘界面，不再显示“本地复盘 / Vespa对齐” Tab。Vespa 对齐工具可保留在 `tools/chanpy_compare` 作为开发工具，但不再作为 App 页面。

## 当前完成度

```text
已完成：
1. origin_vespa_tdx 分支建立。
2. App 根页面切到 OriginReplayPageV2。
3. 删除 App 内 Vespa 对齐页面。
4. Windows Python app_engine.py 入口。
5. /api/chan/analyze 后端接口。
6. /api/chan/analyze_bars 本地 bars 分析接口。
7. Windows Flutter 自动后台启动 Python chan.py 本地服务。
8. Android 真机已验证 python/chan.py 进入 APK，且 fx/bi/seg/zs 返回非空。
9. Windows 便携 Python 已完成本地实测，Flutter 会优先使用 python/python.exe。
10. 后端 once 模式调用 chan.py 导出 FX / BI / SEG / ZS / BSP / merged_bars。
11. 后端 step 模式调用 CChan.step_load() 并返回 frames。
12. Android Chaquopy 新增 python_chan MethodChannel。
13. Android chanpy_runtime.py 已接入 CChan，导出 FX / BI / SEG / ZS / BSP / merged_bars / frames。
14. Flutter V2 页面直接消费 step frames。
15. Flutter V2 页面支持 BSP 显示开关与图上绘制。
16. Flutter V2 页面支持 BSP 相关 CChanConfig 配置项。
17. Flutter V2 页面支持本地 CSV 上传到 Python chan.py。
18. Flutter V2 页面支持 CChanConfig 设置，加载前/加载后修改都会重新请求 Python chan.py。

待完成：
1. 跑 flutter analyze / flutter run，修复本轮新增 V2 文件的编译和运行期问题。
2. BSP 导出字段仍需用真实样本校验是否覆盖 chan.py 当前版本的所有买卖点对象形态。
3. merged_bars 字段已返回，但仍需用长样本核对 raw_index/high/low/open/close 与 chan.py 预期是否完全一致。
4. 删除或隔离旧 Dart 算法层。
5. 进一步把 README 中 CChan / CChanConfig 说明链接到 Vespa quick_guide 对应章节。
```

## 当前注意事项

此前长样本 diff 显示 Dart 复刻算法仍在 BI 初始化处与 chan.py 不一致：FX 已 0 mismatch，但 BI 少第一笔，导致 SEG / ZS 索引错位。因此本分支不再继续追 Dart 复刻，而改为 Python chan.py 单一计算源。

Android 运行期经验见：

```text
docs/chanpy_runtime_lessons.md
```
