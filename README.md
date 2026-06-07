# 缠论 K 线复盘 App MVP

这是第一版 Flutter 安卓 MVP：

- App 内直连腾讯行情历史 K 线数据源
- 本地 CSV 导入
- 示例 K 线数据
- 逐 K 前进 / 后退 / 播放
- 自绘 K 线图
- 自动识别包含关系、分型、笔、线段、中枢
- 显示 / 隐藏分型、分型连线、笔、线段、中枢
- 配置层按 `Vespa314/chan.py` 的 `CChanConfig / CBiConfig / CSegConfig / CZSConfig` 结构对齐

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
- K线数量：100 到 2000 根

加载成功后，标题栏会显示当前数据源，并用同一套缠论引擎重新计算分型、笔、线段、中枢。

如果接口返回空数据，优先检查市场选择是否正确，例如 `000001` 应选择 `SZ`，`600000` 应选择 `SH`。

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

中枢模块当前实现状态：

```text
ZS model 线段字段         已加入
ZsEngine 线段感知计算      已加入
zs_algo = normal          只按确认线段 seg.isSure 内部 biList 计算，不退回全局笔列表
zs_algo = overSeg         按全局笔列表计算，允许跨段
zs_algo = auto            优先确认线段内中枢，无结果时退回全局笔列表
zs_combine_mode = zs/peak 已接入
不同线段中枢不会被合并  已加入
中枢边界二次校验        已加入
```

暂未完整实现但已保留配置位：

```text
bi.gapAsKl
bi.allowSubPeak
线段中枢的完整生命周期回滚
MACD / BOLL / Demark / RSI / KDJ 指标配置
多级别联立
买卖点 BSP
```

## 当前版本边界

这是 v0.1 原型，重点验证“逐 K 复盘 + 缠论结构引擎”。暂未接实时行情、选股、自动交易、复杂背驰、多级别联动。

分钟线一般不使用前复权/后复权参数；当前腾讯适配器会自动对分钟周期使用分钟线请求格式，只对日线、周线、月线发送 `qfq/hfq`。

## 核心引擎位置

```text
lib/core/engine/chan_replay_engine.dart
lib/core/engine/include_processor.dart
lib/core/engine/fx_engine.dart
lib/core/engine/bi_engine.dart
lib/core/engine/seg_engine.dart
lib/core/engine/zs_engine.dart
```

计算链路：

```text
RawBar -> 包含关系处理 -> MergedBar -> FX -> BI -> SEG -> ZS -> ChanSnapshot -> KlinePainter绘图
```

## 数据源适配位置

```text
lib/data/csv_loader.dart
lib/data/tencent_kline_source.dart
lib/data/eastmoney_kline_source.dart
```

`eastmoney_kline_source.dart` 暂时保留为备用源，当前页面默认调用 `tencent_kline_source.dart`。
