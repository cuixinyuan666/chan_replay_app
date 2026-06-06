# 缠论 K 线复盘 App MVP

这是第一版 Flutter 安卓 MVP：

- 本地 CSV 导入
- 示例 K 线数据
- 逐 K 前进 / 后退 / 播放
- 自绘 K 线图
- 自动识别包含关系、分型、笔、中枢
- 显示 / 隐藏分型、笔、中枢
- 可调整引擎参数：包含关系、严格分型、成笔最小K线间隔、单笔中枢开关

## 运行方式

本压缩包包含 Flutter 业务代码。如果解压后没有 `android/` 目录，先在项目根目录生成平台工程：

```bash
flutter create . --platforms=android
flutter pub get
flutter run
```

已有 Android Studio 的情况下，也可以：

1. Android Studio 打开项目目录；
2. 执行 `flutter pub get`；
3. 选择安卓模拟器或真机；
4. 点击 Run。

## CSV 格式

第一行可以是表头，字段顺序：

```csv
time,open,high,low,close,volume
2024-01-02,10.00,10.35,9.92,10.22,123456
```

支持日期 `yyyy-MM-dd` 或标准 ISO 时间字符串。

## 当前版本边界

这是 v0.1 原型，重点验证“逐 K 复盘 + 缠论结构引擎”。暂未接实时行情、选股、自动交易、复杂背驰、多级别联动。

## 核心引擎位置

```text
lib/core/engine/chan_replay_engine.dart
lib/core/engine/include_processor.dart
lib/core/engine/fx_engine.dart
lib/core/engine/bi_engine.dart
lib/core/engine/zs_engine.dart
```

计算链路：

```text
RawBar -> 包含关系处理 -> MergedBar -> FX -> BI -> ZS -> ChanSnapshot -> KlinePainter绘图
```
