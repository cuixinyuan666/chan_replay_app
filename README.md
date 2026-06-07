# chan_replay_app - vespa_tdx

`vespa_tdx` 分支基于 `czsc_easy_tdx` 创建，但已移除 CZSC 缠论计算链路。

当前目标：

```text
内置/本地 easy-tdx 获取 K线 -> Flutter RawBar -> Vespa/chan.py 风格 Dart 引擎 -> FX / BI / SEG / ZS -> KlineChart 显示
```

## 当前功能

- Android App 内置 Python 解释器，直接安装并调用 `easy-tdx` 获取 K 线。
- Windows Flutter 使用 `easy-tdx 后端备用` 时，如果 `127.0.0.1:8000` 未启动，会自动后台启动本项目 `backend/app/main.py`，不显示 cmd 窗口，使用随机本机端口，请求结束后释放端口。
- 本地复盘页支持一次性显示与逐 K 线回放。
- 本地复盘页数据源支持：
  - 内置 Python easy-tdx，Android 默认
  - easy-tdx 后端备用，Windows 默认；可自动后台启动本机子进程
  - 腾讯行情直连备用
  - 示例 CSV / 本地 CSV
- easy-tdx 后端只返回 K 线 `bars`，不再调用 CZSC。
- Flutter 端继续使用项目内 Vespa/Dart 缠论引擎计算：包含关系、分型、笔、线段、中枢。
- 支持设置标的、市场、周期、复权、K线数量、开始日期、结束日期。
- 支持显示 / 隐藏分型、分型连线、笔、线段、中枢，以及分型/笔/线段端点文字。

## Android 内置 Python 说明

本分支使用 Chaquopy 把 CPython 和 `easy-tdx` 打进 APK：

```text
android/settings.gradle.kts             Chaquopy Gradle 插件
android/app/build.gradle.kts            Python 3.11 + easy-tdx pip 依赖
android/app/src/main/python/easy_tdx_runtime.py
android/app/src/main/kotlin/.../MainActivity.kt
lib/data/embedded_easy_tdx_source.dart
```

注意：

```text
1. Android minSdk 已提高到 24。
2. 当前只打包 arm64-v8a 和 x86_64 两个 ABI。
3. APK 体积会明显增加。
4. 内置 Python easy-tdx 目前只支持 Android；Windows 请用 easy-tdx 后端备用模式。
5. 如果 easy-tdx 或其依赖在 Chaquopy 环境中安装失败，需要改为纯 Python 依赖或继续使用后端备用模式。
```

## Windows 自动后台 easy-tdx 模式

Windows 下选择：

```text
本地复盘 -> 数据源 -> easy-tdx 后端备用
```

如果 `http://127.0.0.1:8000` 没有服务，Flutter 会自动：

```text
1. 查找项目 backend/app/main.py；
2. 优先使用 backend/.venv/Scripts/python.exe；
3. 否则尝试 python 或 py -3；
4. 后台执行 python -m uvicorn app.main:app --host 127.0.0.1 --port <随机端口>；
5. 使用随机端口获取 K线；
6. 请求结束后 kill 子进程并释放端口。
```

首次使用前仍建议安装依赖：

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
```

## Flutter 运行

```bash
flutter pub get
flutter run
```

如果解压后没有平台工程：

```bash
flutter create . --platforms=android,windows
flutter pub get
flutter run
```

## easy-tdx 后端备用手动运行

```bash
cd backend
python -m venv .venv
. .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Android 模拟器默认后端地址：

```text
http://10.0.2.2:8000
```

Windows / 本机调试默认后端地址：

```text
http://127.0.0.1:8000
```

真机请使用电脑局域网 IP，例如：

```text
http://192.168.1.8:8000
```

## 后端备用接口

```text
GET /health
GET /api/tdx/kline?symbol=000001&market=SZ&freq=DAILY&adjust=QFQ&count=800&start=2020-01-01&end=2024-12-31
```

返回示例：

```json
{
  "ok": true,
  "engine": "flutter-vespa-dart",
  "source": {"name": "easy-tdx", "symbol": "000001.SZ", "freq": "DAILY"},
  "bars": [
    {"id": 0, "dt": "2024-01-02 00:00:00", "open": 1.0, "high": 1.1, "low": 0.9, "close": 1.0, "vol": 1000}
  ]
}
```

## 数据源参数

```text
symbol  股票代码，例如 000001 或 600000
market  SZ / SH，可留空自动推断
freq    MIN1 / MIN5 / MIN15 / MIN30 / MIN60 / DAILY / WEEKLY / MONTHLY
adjust  QFQ / HFQ / NONE
count   10~5000
start   yyyy-MM-dd，可选
end     yyyy-MM-dd，可选
```

## 核心代码位置

```text
android/app/src/main/python/easy_tdx_runtime.py       Android 内置 easy-tdx Python 调用
android/app/src/main/kotlin/.../MainActivity.kt       Flutter MethodChannel -> Python
lib/data/embedded_easy_tdx_source.dart                Flutter 内置 easy-tdx 数据适配
lib/data/easy_tdx_kline_source.dart                   Flutter 后端备用 + Windows 自动子进程数据适配
backend/app/easy_tdx_provider.py                      后端备用 easy-tdx 获取与标准化 K线
backend/app/main.py                                   FastAPI 原始 K线接口
lib/ui/pages/replay_page.dart                         本地复盘页与数据源选择
lib/core/engine/*                                     Vespa/chan.py 风格 Dart 引擎
lib/core/models/*                                     RawBar / FX / BI / SEG / ZS 模型
```

## CZSC 移除说明

本分支不再使用：

```text
czsc_adapter.py
CzscEasyTdxSource
CzscEasyTdxPage
/api/czsc/analyze
/api/czsc/multi
```

后续缠论结构对齐任务应继续在 Flutter/Dart 的 Vespa 引擎内完成。
