# chan_replay_app - vespa_tdx

`vespa_tdx` 分支基于 `czsc_easy_tdx` 创建，但已移除 CZSC 缠论计算链路。

当前目标：

```text
内置/本地 easy-tdx 获取 K线 -> Flutter RawBar -> Vespa/chan.py 风格 Dart 引擎 -> FX / BI / SEG / ZS -> candlesticks + 缠论叠加层显示
```

## 当前功能

- K线图底层使用 Flutter `candlesticks` 包渲染，缠论分型、笔、线段、中枢作为前端叠加层绘制。
- 默认空图，只有显式加载数据源成功后才显示K线。
- Android App 内置 Python 解释器，直接安装并调用 `easy-tdx` 获取 K 线。
- Windows Flutter 使用 `easy-tdx 后端备用` 时，如果 `127.0.0.1:8000` 未启动，会自动后台启动本项目 `backend/app/main.py`，不显示 cmd 窗口，使用随机本机端口，请求结束后释放端口。
- 本地复盘页默认“一次性显示”；只有切换到“逐K回放”时才显示底部播放栏。
- 本地复盘页数据源支持：
  - Android：内置 Python easy-tdx，Android 默认；Windows 不显示该选项
  - Windows：easy-tdx 后端备用，Windows 默认；可自动后台启动本机子进程
  - 本地 CSV
- 新增“Vespa对齐”选项卡，用于展示 `tools/chanpy_compare` 基准测试入口。
- easy-tdx 后端只返回 K 线 `bars`，不再调用 CZSC。
- Flutter 端继续使用项目内 Vespa/Dart 缠论引擎计算：包含关系、分型、笔、线段、中枢。
- 标的市场由代码自动推断，例如 `600000` 走 SH，`000001` 走 SZ；也支持 `SH600000`、`600000.SH`、`SZ000001`、`000001.SZ`。
- 远程取数使用开始日期和结束日期；结束日期默认 `2026-06-06`。
- 支持显示 / 隐藏分型、分型连线、笔、线段、中枢，以及分型/笔/线段端点文字。

## 前端交互约束

```text
1. 每个设置项在整个前端只能有一个入口：
   - 数据源 / 标的 / 周期 / 复权 / 起止时间：只在“数据源”面板设置。
   - Vespa/chan.py 引擎参数：只在“设置”面板设置。
   - 一次性 / 逐K / 图层显隐 / 图表缩放：只在左侧工具栏操作。
2. 当前状态下不可用的操作必须灰度不可点击，禁止“点了才报错”。
3. Android 和 Windows 数据源必须用不同文案明确区分，避免误选。
4. 缠论计算逻辑只能复刻 Vespa/chan.py；除前端显示、数据源适配、UI交互外，禁止自造缠论规则。
```

更完整的任务注意事项见：

```text
docs/task_execution_notes.md
```

## Vespa/chan.py 对齐基准

新增工具目录：

```text
tools/chanpy_compare
```

用途：同一份 CSV K线数据分别输入 `Vespa314/chan.py` 和当前 Dart `ChanReplayEngine`，导出并比较：

```text
FX 列表
BI 起止点
SEG 起止点、方向、is_sure
ZS 起止笔、ZG/ZD/GG/DD
```

运行：

```bash
git clone https://github.com/Vespa314/chan.py.git ../chan.py
python tools/chanpy_compare/run_compare.py \
  --csv assets/sample_data/000001_daily.csv \
  --chanpy-path ../chan.py \
  --out build/chanpy_compare
```

输出：

```text
build/chanpy_compare/chanpy.json
build/chanpy_compare/chanpy_raw.json
build/chanpy_compare/dart.json
build/chanpy_compare/diff_report.json
build/chanpy_compare/diff_report.md
```

后续算法修复顺序固定为：

```text
BI -> SEG -> ZS
```

## candlesticks 图表说明

本分支使用：

```yaml
candlesticks: ^3.0.1
```

官方文档：

```text
https://pub.dev/packages/candlesticks
```

`candlesticks` 要求 `Candle` 列表按“最新在前、最旧在后”排序；当前项目内部 `RawBar` 仍保持按时间升序，进入图表时再反转为 `Candle`。

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
本地复盘 -> 数据源 -> Windows本机TDX
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
GET /api/tdx/kline?symbol=000001&market=SZ&freq=DAILY&adjust=QFQ&start=2020-01-01&end=2026-06-06
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
symbol  股票代码，例如 000001、600000、SZ000001、600000.SH
freq    MIN1 / MIN5 / MIN15 / MIN30 / MIN60 / DAILY / WEEKLY / MONTHLY
adjust  QFQ / HFQ / NONE
start   yyyy-MM-dd
end     yyyy-MM-dd，默认 2026-06-06
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
lib/ui/pages/chanpy_compare_page.dart                 Vespa 对齐基准说明页
lib/ui/widgets/kline_chart.dart                       candlesticks + 缠论叠加层
lib/core/engine/*                                     Vespa/chan.py 风格 Dart 引擎
lib/core/models/*                                     RawBar / FX / BI / SEG / ZS 模型
tools/chanpy_compare/*                                chan.py 与 Dart 输出对齐基准工具
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
