# 缠论 K 线复盘 App MVP

这是第一版 Flutter 安卓 MVP：

- App 内直连腾讯行情历史 K 线数据源
- 支持按开始日期 / 结束日期获取并过滤 K 线
- 本地 CSV 导入
- 示例 K 线数据
- 一次性显示模式与逐 K 线回放模式
- 自绘 K 线图
- 自动识别包含关系、分型、笔、线段、中枢
- 显示 / 隐藏分型、分型连线、笔、线段、中枢
- 独立控制分型、笔、线段端点文字显示
- 配置层按 `Vespa314/chan.py` 的 `CChanConfig / CBiConfig / CSegConfig / CZSConfig` 结构对齐
- `czsc_easy_tdx` 分支新增 CZSC + easy-tdx 后端模式，用于直接显示 Python/CZSC 输出的分型、笔、线段、中枢

## 运行方式

```bash
flutter pub get
flutter run
```

如果解压后没有 `android/` 目录，先在项目根目录生成平台工程：

```bash
flutter create . --platforms=android
flutter pub get
flutter run
```

## CSV 格式

第一行可以是表头，字段顺序：

```csv
time,open,high,low,close,volume
2024-01-02,10.00,10.35,9.92,10.22,123456
```

支持日期 `yyyy-MM-dd` 或标准 ISO 时间字符串。

## 显示模式

顶部工具栏提供两种模式：

```text
一次性  -> 加载后一次性显示全部已获取 K 线，并禁用底部 Bar Replay 控制
逐K     -> 按 cursor 逐 K 线推进，可前进、后退、播放和拖动进度
```

这对应 chan.py 中常见的“一次性计算”和 `trigger_step` 分步回放思路。

## App 内直连行情数据源

当前默认使用腾讯行情历史 K 线接口。App 直接通过 HTTPS 请求历史 K 线数据，并转换为统一的 `RawBar`：

```text
腾讯行情 HTTPS K线接口 -> Flutter -> RawBar -> 缠论引擎
```

点击顶部云同步图标，填写：

- 市场：`SZ` 或 `SH`
- 代码：例如 `000001`
- 周期：`MIN1/MIN5/MIN15/MIN30/MIN60/DAILY/WEEKLY/MONTHLY`
- 复权：`QFQ/HFQ/NONE`
- 开始日期：`yyyy-MM-dd`
- 结束日期：`yyyy-MM-dd`，可留空表示最新
- K线数量：100 到 2000 根

加载成功后，标题栏会显示当前数据源，并用同一套缠论引擎重新计算分型、笔、线段、中枢。

如果接口返回空数据，优先检查市场选择是否正确，例如 `000001` 应选择 `SZ`，`600000` 应选择 `SH`。如果指定了很早的开始日期但只读取 500 根，可能需要把 K 线数量拉高到 2000。

## CZSC + easy-tdx 后端模式

`czsc_easy_tdx` 分支新增第二个底部标签页：

```text
本地复盘     -> 原有 Flutter/Dart 本地引擎
CZSC后端     -> Python FastAPI + easy-tdx + CZSC
```

第一阶段链路：

```text
easy-tdx -> FastAPI -> CZSC -> bars/fx/bi/seg/zs JSON -> Flutter KlineChart
```

后端启动：

```bash
cd backend
python -m venv .venv
. .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Flutter 端默认后端地址：

```text
http://10.0.2.2:8000
```

这个地址适合 Android 模拟器访问电脑本机。如果是真机，把页面里的“后端地址”改成电脑局域网 IP，例如：

```text
http://192.168.1.8:8000
```

后端接口：

```text
GET /health
GET /api/czsc/analyze?symbol=000001&market=SZ&freq=DAILY&adjust=QFQ&count=800
```

Flutter 第一阶段已经接入并显示：

```text
K线 bars
分型 fx
笔 bi
线段 seg
中枢 zs
信号数量 signals
```

## 腾讯行情周期映射

```text
MIN1    -> m1
MIN5    -> m5
MIN15   -> m15
MIN30   -> m30
MIN60   -> m60
DAILY   -> day
WEEKLY  -> week
MONTHLY -> month
```

## chan.py 兼容配置

配置入口：

```text
lib/core/engine/chan_config.dart
```

当前配置结构：

```text
ChanConfig
├── ChanBiConfig   -> 对齐 CBiConfig
├── ChanSegConfig  -> 对齐 CSegConfig
└── ChanZsConfig   -> 对齐 CZSConfig
```

默认值按 chan.py 的 `CChanConfig` 对齐：

```text
bi_algo           = normal
bi_strict         = true
bi_fx_check       = strict
gap_as_kl         = false
bi_end_is_peak    = true
bi_allow_sub_peak = true
seg_algo          = chan
left_seg_method   = peak
zs_combine        = true
zs_combine_mode   = zs
one_bi_zs         = false
zs_algo           = normal
```

已接入当前 Flutter 引擎的配置：

```text
enableInclude
bi.biAlgo
bi.isStrict
bi.fxCheck
bi.endIsPeak
seg.segAlgo
seg.leftMethod
zs.needCombine
zs.combineMode
zs.oneBiZs
zs.zsAlgo
zs.onlyConfirmed
```

线段模块当前实现状态：

```text
SEG model          已加入
SegEngine          已加入
EigenFX 特征序列    已加入
特征元素包含合并    已加入
特征序列分型确认    已加入
实际突破检查        已加入
尾部未确认线段收集  已加入
ChanSnapshot.segs  已加入
图表线段显示        已加入
左工具栏线段开关    已加入
```

底层引用关系当前实现状态：

```text
BI.prevIndex / nextIndex               已加入
BI.parentSegIndex                      已加入
BI.parentSegDirection                  已加入
BI.parentSegIsSure                     已加入
BI.parentSegStartBiIndex/EndBiIndex    已加入
SEG.prevIndex / nextIndex              已加入
ChanRelationLinker                     已加入
ChanReplayEngine 生成 ZS 前统一建链    已加入
```

中枢模块当前实现状态：

```text
ZS model 对齐 CZS.high/low/peak_high/peak_low 已加入
ZsEngine 已按 CZSList 状态机重写
normal 模式：按 SEG 内部、只处理与线段方向相反的 BI
normal 非单笔中枢：按 Vespa 的最近两笔重叠构造
one_bi_zs：按一笔构造，后续 try_add_to_end 扩展
try_add_to_end：已加入
try_construct_zs：已加入
try_combine：已加入
combine_mode = zs/peak：已加入
CZS.do_combine 范围扩展方向：已修正
over_seg 的 parent_seg.dir 过滤：已接入 BI.parentSegDirection
尾部未确认部分处理：已加入
```

仍受当前 Flutter 模型影响的差异：

```text
pre/next/parent_seg 当前使用索引式引用，不是 Python 对象引用
bi_in / bi_out 字段已保留，但买卖点模块尚未接入，所以当前暂不驱动背驰判断
线段中枢的完整增量回滚机制仍是“每次 snapshot 全量重算”实现
```

暂未完整实现但已保留配置位：

```text
bi.gapAsKl
bi.allowSubPeak
MACD / BOLL / Demark / RSI / KDJ 指标配置
多级别联立
买卖点 BSP
```

## 当前版本边界

这是 v0.1 原型，重点验证“逐 K 复盘 + 缠论结构引擎”。暂未接实时行情、选股、自动交易、复杂背驰、多级别联动。

分钟线一般不使用前复权/后复权参数；当前腾讯适配器会自动对分钟周期使用分钟线请求格式，并在 App 端根据输入的开始 / 结束日期做二次过滤。日线、周线、月线会在请求参数中携带起止日期，并同样做 App 端二次过滤。

CZSC/easy-tdx 后端模式当前属于第一阶段联调入口：优先验证数据链路、CZSC 元素 JSON、Flutter 图层显示；实时推送、逐 K 后端增量回放、多级别 CZSC 联立和买卖点 BSP 放到后续阶段。

## 核心引擎位置

```text
lib/core/engine/chan_replay_engine.dart
lib/core/engine/include_processor.dart
lib/core/engine/fx_engine.dart
lib/core/engine/bi_engine.dart
lib/core/engine/seg_engine.dart
lib/core/engine/relation_linker.dart
lib/core/engine/zs_engine.dart
```

计算链路：

```text
RawBar -> 包含关系处理 -> MergedBar -> FX -> BI -> SEG -> 关系建链 -> ZS -> ChanSnapshot -> KlinePainter绘图
```

## 数据源适配位置

```text
lib/data/csv_loader.dart
lib/data/tencent_kline_source.dart
lib/data/eastmoney_kline_source.dart
lib/data/czsc_easy_tdx_source.dart
backend/app/easy_tdx_provider.py
backend/app/czsc_adapter.py
backend/app/main.py
```

`eastmoney_kline_source.dart` 暂时保留为备用源，当前页面默认调用 `tencent_kline_source.dart`。`czsc_easy_tdx_source.dart` 只在 `CZSC后端` 标签页使用，用于连接 Python 后端。