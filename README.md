# chan_replay_app - origin_vespa_tdx

`origin_vespa_tdx` 基于 `vespa_tdx` 创建，目标是把 Vespa/chan.py 作为唯一缠论计算源。Flutter 只负责展示、交互、复盘、回测结果呈现和研究入口，不在生产链路复刻 FX / BI / SEG / ZS / BSP 算法。

## 核心架构

```text
Flutter UI
  ↓ JSON / localhost HTTP / Android MethodChannel
Python chan.py 引擎
  ↓
返回 bars / merged_bars / FX / BI / SEG / ZS / BSP / indicators / frames JSON
  ↓
Flutter 绘图、回放控制、缩放拖动、图层显示、研究结果展示
```

## 严格边界

```text
Python chan.py：唯一缠论结构计算源。
backend/app/a_*：本 App 自主扩展层，只消费 analysis JSON，不污染 chan.py。
Flutter：只解析 JSON、绘图、交互、发起请求，不计算缠论结构。
```

禁止事项：

1. 不修改 `python/chan.py` 内部逻辑。
2. 不在 Flutter 生产链路 import / 调用旧 Dart FX / BI / SEG / ZS / BSP 引擎。
3. 不把展示指标、机器学习分数、回测结果反向写入 chan.py 结构结果。
4. 不用未来 K 线生成实盘特征；未来收益只能放在 `label_*` 字段，用于离线训练 / 评估。

## 平台方案

```text
Android：Chaquopy 类方案，把 CPython、easy-tdx、chan.py 打进 APK。
Windows：Flutter 自动后台启动本地 Python HTTP 服务，服务内调用 chan.py + easy-tdx。
```

Windows 打包方向见：

```text
docs/windows_embedded_python.md
```

Android 运行期经验见：

```text
docs/chanpy_runtime_lessons.md
```

## Python 引擎接口

### 一次性模式

```http
GET /api/chan/analyze?mode=once&symbol=000001&market=SZ&freq=DAILY&adjust=QFQ
```

返回：

```json
{
  "ok": true,
  "bars": [],
  "merged_bars": [],
  "fx": [],
  "bi": [],
  "seg": [],
  "zs": [],
  "bsp": [],
  "indicators": {},
  "frames": [],
  "meta": {
    "engine": "chan.py",
    "symbol": "000001.SZ"
  }
}
```

### 严格逐K模式

```http
GET /api/chan/analyze?mode=step&symbol=000001&market=SZ&freq=DAILY&adjust=QFQ
```

依据 Vespa quick_guide 的策略实现 / 回测说明：

```text
打开 CChanConfig.trigger_step。
CChan 初始化时不做完整计算。
手动调用 CChan.step_load()。
每喂一根 K 线后返回当前 CChan，可获取当前位置静态元素。
每一帧不是完全重算，只重新计算不确定部分。
```

当前后端 mode=step 走 `CChan.step_load()` 并返回 `frames`；Flutter V2 页面直接消费 `frames`，不再用前端切片模拟逐K。

### 本地 CSV 模式

```http
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

## easy-tdx 与展示指标

已接入后端展示指标输出：

```text
indicators.vol
indicators.amount
indicators.turnover
indicators.ma
indicators.boll
indicators.macd
```

说明：

1. `vol / amount / turnover` 来自 bars 透传字段。
2. `turnover` 缺失时保持 `null`，不得估算伪造。
3. `ma / boll / macd` 当前为 `backend_display_only_from_close`，只用于展示和研究特征，不改变 BSP 计算。
4. step frames 会按各自可见 bars 输出对应 indicators。

合同文档：

```text
docs/easy_tdx_indicator_contract.md
```

## 研究扩展：BSP 特征 / ML / 回测

参考 Vespa/chan.py README 和 quick_guide，本分支已经开始接入研究层，但采用非侵入式自主扩展方式。

### 当前后端模块

```text
backend/app/a_bsp_feature_engine.py   BSP 特征提取
backend/app/a_ml_bridge.py            轻量 ML 打分桥接
backend/app/a_backtest_engine.py      BSP 研究回测
```

### 当前 API

```http
POST /api/research/bsp/features
POST /api/research/ml/score
POST /api/research/backtest
POST /api/research/pipeline
```

### 当前 Flutter 入口

```text
lib/ui/pages/research_backtest_page.dart
```

该页面通过左下角同列路由按钮进入，首次点击后才构造；输入为 chan.py analysis JSON，输出为 features / scores / backtest / pipeline JSON。

约束：

1. 输入为 chan.py analysis JSON。
2. 特征只读取当前 / 过去可见字段。
3. `label_*` 字段可以用未来收益，但只允许离线训练 / 评估。
4. 回测默认下一根 K 线入场，避免同 K 线偷看。
5. 默认 ML 是透明 heuristic baseline；后续可接外部模型文件，但默认不引入 xgboost / lightgbm / sklearn 重依赖。

详细文档：

```text
docs/vespa_research_extension_plan.md
```

## 页面约束

App 入口应直接呈现复盘界面，不再显示“本地复盘 / Vespa对齐” Tab。Vespa 对齐工具可保留在 `tools/chanpy_compare` 作为开发工具，但不再作为 App 页面。

当前根页面：

```text
lib/ui/pages/root_page.dart
```

约束：

1. 默认只构造复盘页。
2. 扫描器、研究 / 回测页面必须首次访问后才构造并缓存。
3. `lib/ui/pages/replay_page.dart` 只是 `OriginReplayPageV2` 兼容 wrapper，不再 import 或实例化旧 Dart `ChanReplayEngine`。

## 护栏与验证命令

```bash
flutter analyze
python tools/audit_dart_algorithm_usage.py
python tools/audit_global_lazy_loading.py --strict
python tools/check_chanpy_guardrails.py
python tools/audit_bsp_label_layout_usage.py --strict
python tools/audit_origin_kline_global_label_layout_usage.py --strict
python tools/validate_chanpy_output_contract.py path/to/analysis.json
python tools/validate_easy_tdx_indicator_contract.py path/to/analysis.json
```

新增全局懒加载 / 生产耦合审计：

```text
tools/audit_global_lazy_loading.py
```

它检查：

1. `main.dart / app.dart / root_page.dart / replay_page.dart` 等全局入口不引用旧 Dart 缠论算法引擎。
2. 生产 Dart 文件不 import `core/engine/` 旧算法。
3. 重页面 import 必须位于明确边界或白名单内。
4. `root_page.dart` 必须保留 lazy route marker，防止回退到 eager `IndexedStack`。

## 当前监督状态

最后更新：2026-06-10。

### 已完成

#### 1. 主架构与单一计算源

1. `origin_vespa_tdx` 分支建立。
2. App 根页面切到 `OriginReplayPageV2`。
3. App 入口直接进入复盘界面。
4. Windows Python `app_engine.py` 入口已建立。
5. Windows Flutter 会优先使用 `python/python.exe`，并自动后台启动 Python chan.py 本地服务。
6. Android Chaquopy 已新增 `python_chan` MethodChannel。
7. 后端 once 模式调用 Python chan.py 导出 FX / BI / SEG / ZS / BSP / merged_bars。
8. 后端 step 模式调用 `CChan.step_load()` 并返回 frames。
9. Flutter V2 页面直接消费 Python step frames，不再用前端切片模拟逐K。
10. Flutter V2 页面支持本地 CSV 上传到 Python chan.py。
11. `lib/ui/pages/replay_page.dart` 已改为 V2 wrapper，不再 import / 实例化旧 Dart 算法引擎。
12. `RootPage` 已从 eager `IndexedStack` 改为 lazy route stack，扫描器和研究页首次访问后才构造。

#### 2. API 与输出合同

1. 已提供 `/api/chan/analyze`。
2. 已提供 `/api/chan/analyze_bars`。
3. 已提供 `/api/tdx/kline`。
4. 已新增 `tools/validate_chanpy_output_contract.py`。
5. 已新增 `tools/validate_easy_tdx_indicator_contract.py`。
6. 已新增 `docs/easy_tdx_indicator_contract.md`。
7. 已新增 `docs/vespa_quick_guide_alignment_matrix.md`。

#### 3. BSP 与结构显示

1. Flutter V2 页面支持 BSP 显示开关与图上绘制。
2. Flutter V2 页面支持 BSP 相关 CChanConfig 配置项。
3. BSP label 已接入 `ChartLabelLayout`。
4. FX / BI / SEG / BSP 结构文字已统一进入避让队列。
5. BSP 与全局结构文字布局审计脚本已加入。

#### 4. easy-tdx 与指标输出

1. easy-tdx bars 已保留 `volume / amount / turnover` 字段。
2. 后端已输出 `indicators.vol / amount / turnover / ma / boll / macd`。
3. `python/app_engine.py --json-request` 已补 indicators 输出。
4. step frames 已补 indicators 输出。
5. 指标来源写入 `meta.indicator_sources`。

#### 5. 研究层接入起步

1. 已新增 BSP 特征提取引擎：`backend/app/a_bsp_feature_engine.py`。
2. 已新增轻量 ML 打分桥：`backend/app/a_ml_bridge.py`。
3. 已新增 BSP 研究回测引擎：`backend/app/a_backtest_engine.py`。
4. 已新增 research API：`features / score / backtest / pipeline`。
5. 已新增研究扩展文档：`docs/vespa_research_extension_plan.md`。
6. 已新增 Flutter 研究 / 回测页面：`lib/ui/pages/research_backtest_page.dart`。

#### 6. 本地验证与 CI 护栏

1. 用户本地执行 `flutter analyze`，结果为 `No issues found`。
2. 用户本地执行 `python tools/audit_dart_algorithm_usage.py` 时发现 3 个 blocking，均来自旧 `replay_page.dart` 生产链路 import / 实例化旧 Dart 引擎。
3. 本轮已修复上述 blocking 源文件，但仍需用户重新执行审计确认。
4. 已新增 `tools/audit_global_lazy_loading.py --strict`。
5. 全局懒加载审计已加入 GitHub Actions。

### 已完成但仍需复验

1. `audit_dart_algorithm_usage.py` 需重新执行，确认 blocking_count 归零。
2. `audit_global_lazy_loading.py --strict` 需本地执行。
3. Windows `flutter run -d windows` 需确认启动后复盘页面、扫描器入口、研究 / 回测入口、Python 后端自动启动都可用。
4. Android `flutter run` 需重新验收。
5. Research API 和 Flutter 研究页需用真实 analysis JSON 复验。
6. 合同校验脚本需用真实导出的 analysis JSON，而不是占位路径 `path/to/analysis.json`。

### 未完成

#### P0：生产链路收口

1. 重新跑 `python tools/audit_dart_algorithm_usage.py`。
2. 重新跑 `python tools/audit_global_lazy_loading.py --strict`。
3. 对 GitHub Actions 的真实运行结果做一次完整复核。
4. 旧 Dart 算法层如需保留，只能作为 `legacy`、`tools`、`compare` 或测试用途。

#### P1：chan.py 输出真实性校验

1. BSP 导出字段真实样本覆盖测试。
2. `merged_bars` 长样本一致性核对。
3. once 模式与 step 模式最终帧一致性核对。
4. `is_sure=false` 的 FX / BI / SEG / ZS / BSP 虚线或弱化显示统一检查。
5. 随机 5 只股票、3 个周期执行字段合同校验。

#### P2：Flutter 指标副图

1. Flutter 增加 VOL 副图。
2. Flutter 增加 MACD / MA / BOLL 显示。
3. Flutter 增加指标开关、crosshair 联动和 tooltip。
4. Android MethodChannel 输出合同与 Windows HTTP 输出合同保持一致。

#### P3：研究 / 回测 UI

1. 将研究页与当前复盘页的最新 analysis JSON 自动打通，减少手动粘贴。
2. UI 展示 BSP 特征表、ML score、回测交易列表和 summary，而不是只显示原始 JSON。
3. 后续支持外部模型文件导入，但不得让重依赖污染默认启动链路。
4. 增加 research API fixture 和合同校验。

#### P4：K线图最终显示验收

1. 300 根、1000 根、3000 根 K线窗口截图验收。
2. FX / BI / SEG / ZS / BSP 文本开启时不允许明显重叠。
3. 缩放、拖动、逐K回放时 label lane 不应跳乱或遮挡主结构。
4. 密集区域应自动隐藏低优先级文字，保留结构点位。
5. OHLC、VOL、指标数值应优先放到 crosshair / tooltip / 侧栏，不应在图面常驻堆叠。

## 下一批建议任务

1. 先重新跑：

```bash
flutter analyze
python tools/audit_dart_algorithm_usage.py
python tools/audit_global_lazy_loading.py --strict
```

2. 导出一份真实 analysis JSON，执行：

```bash
python tools/validate_chanpy_output_contract.py path/to/real_analysis.json
python tools/validate_easy_tdx_indicator_contract.py path/to/real_analysis.json
```

3. 用同一份 JSON 调用：

```text
POST /api/research/bsp/features
POST /api/research/ml/score
POST /api/research/backtest
POST /api/research/pipeline
```

4. 开始 Flutter VOL 副图和 MACD / MA / BOLL 显示。
5. 补齐 Android MethodChannel indicators 输出合同。

## 当前注意事项

此前长样本 diff 显示 Dart 复刻算法仍在 BI 初始化处与 chan.py 不一致：FX 已 0 mismatch，但 BI 少第一笔，导致 SEG / ZS 索引错位。因此本分支不再继续追 Dart 复刻，而改为 Python chan.py 单一计算源。
