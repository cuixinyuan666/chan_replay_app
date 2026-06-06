# 缠论 K 线复盘 App MVP

这是第一版 Flutter 安卓 MVP：

- 本地 CSV 导入
- 示例 K 线数据
- EasyTDX HTTP 代理数据源
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

## EasyTDX 数据源

Flutter 安卓端不能直接导入 Python 包，所以当前实现采用：

```text
easy-tdx / Python -> HTTP JSON 代理 -> Flutter -> RawBar -> 缠论引擎
```

### 1. 启动 EasyTDX 代理

在电脑或 VPS 上执行：

```bash
pip install fastapi uvicorn easy-tdx
python tools/easy_tdx_proxy.py --host 0.0.0.0 --port 8765
```

健康检查：

```bash
curl http://127.0.0.1:8765/health
```

K线接口示例：

```bash
curl "http://127.0.0.1:8765/kline?market=SZ&code=000001&period=DAILY&adjust=QFQ&count=500"
```

返回格式：

```json
{
  "provider": "easy-tdx",
  "market": "SZ",
  "code": "000001",
  "period": "DAILY",
  "adjust": "QFQ",
  "count": 500,
  "data": [
    {"time":"2024-01-02","open":10.0,"high":10.3,"low":9.9,"close":10.2,"volume":123456.0}
  ]
}
```

### 2. App 内加载

点击顶部云同步图标，填写：

- EasyTDX HTTP 服务地址：真机不能用 `127.0.0.1` 访问电脑服务，应填写电脑局域网 IP，例如 `http://192.168.1.8:8765`
- 模拟器访问宿主机可尝试：`http://10.0.2.2:8765`
- 市场：`SZ` 或 `SH`
- 代码：例如 `000001`
- 周期：`MIN1/MIN5/MIN15/MIN30/MIN60/DAILY/WEEKLY/MONTHLY`
- 复权：`QFQ/HFQ/NONE`

加载成功后，标题栏会显示当前数据源，并用同一套缠论引擎重新计算分型、笔、中枢。

## 当前版本边界

这是 v0.1 原型，重点验证“逐 K 复盘 + 缠论结构引擎”。暂未接实时行情、选股、自动交易、复杂背驰、多级别联动。

EasyTDX 代理里的 `Tdx.kline(...)` 调用已经做了一层兼容 fallback，但不同 easy-tdx 版本的参数名可能不同。如果你的 easy-tdx 版本报参数错误，优先只改 `tools/easy_tdx_proxy.py` 中 `_market_value`、`_period_value`、`_adjust_value` 和 `kline()` 的调用，不需要改 Flutter 端。

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

## 数据源适配位置

```text
lib/data/csv_loader.dart
lib/data/easy_tdx_proxy_source.dart
tools/easy_tdx_proxy.py
```
