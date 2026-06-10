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

## 监督任务文档索引

本轮任务按“先稳定主流程和绘图可用性，再推进 easy-tdx 与 Vespa 全量对齐”的顺序执行。

```text
docs/batch_1_2_execution_checklist.md       第一批 / 第二批执行与验收清单
docs/vespa_quick_guide_alignment_matrix.md  Vespa quick_guide 对齐矩阵
docs/easy_tdx_indicator_contract.md         easy-tdx 与指标输出合同
docs/label_overlap_policy.md                K线图文字与标签避让策略
```

可执行护栏：

```bash
python tools/audit_dart_algorithm_usage.py
python tools/check_chanpy_guardrails.py
python tools/audit_bsp_label_layout_usage.py --strict
python tools/audit_origin_kline_global_label_layout_usage.py --strict
python tools/validate_chanpy_output_contract.py path/to/analysis.json
python tools/validate_easy_tdx_indicator_contract.py path/to/analysis.json
```

GitHub Actions 已加入：

```text
.github/workflows/flutter_analyze.yml
```

它会执行：

```bash
flutter pub get
flutter analyze
flutter test test/chart_label_layout_test.dart
flutter test test/bsp_chart_label_adapter_test.dart
python tools/audit_dart_algorithm_usage.py
python tools/check_chanpy_guardrails.py
python tools/patch_origin_kline_bsp_label_layout.py --check
python tools/patch_origin_kline_global_label_layout.py --check
python tools/audit_bsp_label_layout_usage.py --strict
python tools/audit_origin_kline_global_label_layout_usage.py --strict
python tools/validate_easy_tdx_indicator_contract.py test/fixtures/easy_tdx_indicator_contract_valid.json
```

## 当前监督状态

最后更新：2026-06-09。

### 已完成

#### 1. 主架构与单一计算源

1. `origin_vespa_tdx` 分支建立。
2. App 根页面切到 `OriginReplayPageV2`。
3. 删除 App 内 Vespa 对齐页面；App 入口直接进入复盘界面。
4. Windows Python `app_engine.py` 入口已建立。
5. Windows Flutter 会优先使用 `python/python.exe`，并自动后台启动 Python chan.py 本地服务。
6. Android Chaquopy 已新增 `python_chan` MethodChannel。
7. Android 侧 `chanpy_runtime.py` 已接入 `CChan`，导出 FX / BI / SEG / ZS / BSP / merged_bars / frames。
8. 已确认 Android 真机可以把 `python/chan.py` 打入 APK，且 fx / bi / seg / zs 返回非空。
9. 后端 once 模式调用 Python chan.py 导出 FX / BI / SEG / ZS / BSP / merged_bars。
10. 后端 step 模式调用 `CChan.step_load()` 并返回 frames。
11. Flutter V2 页面直接消费 Python step frames，不再用前端切片模拟逐K。
12. Flutter V2 页面支持本地 CSV 上传到 Python chan.py。
13. Flutter V2 页面支持加载前 / 加载后修改 CChanConfig，并重新请求 Python chan.py 刷新结构。

#### 2. API 与输出合同

1. 已提供 `/api/chan/analyze` 后端接口。
2. 已提供 `/api/chan/analyze_bars` 本地 bars 分析接口。
3. 已新增 `tools/validate_chanpy_output_contract.py`，用于校验 Python 输出结构。
4. 已新增 `tools/validate_easy_tdx_indicator_contract.py`，用于校验 easy-tdx / indicators 输出合同。
5. 已新增 easy-tdx 与指标输出合同文档：`docs/easy_tdx_indicator_contract.md`。
6. 已新增 Vespa quick_guide 对齐矩阵：`docs/vespa_quick_guide_alignment_matrix.md`。

#### 3. BSP 与结构显示

1. Flutter V2 页面支持 BSP 显示开关与图上绘制。
2. Flutter V2 页面支持 BSP 相关 CChanConfig 配置项。
3. 已新增 BSP 到 ChartLabel 的 UI 适配层：`lib/ui/widgets/bsp_chart_label_adapter.dart`。
4. 已将 `bsp_chart_label_adapter.dart` 和 `chart_label_layout.dart` 接入 `OriginKlineChart` 的 BSP 文本绘制。
5. 已将 `OriginKlineChart` 内 FX / BI / SEG / BSP 结构文字统一接入 `ChartLabelLayout`，全局结构文字进入同一避让队列。
6. 已新增 BSP label layout 迁移审计脚本：`tools/audit_bsp_label_layout_usage.py`。
7. 已新增全局结构文字布局审计脚本：`tools/audit_origin_kline_global_label_layout_usage.py`。

#### 4. K线图文字避让与 UI 护栏

1. 已新增 Flutter 通用标签避让布局器：`lib/ui/widgets/chart_label_layout.dart`。
2. 已新增 K线图文字与标签避让策略文档：`docs/label_overlap_policy.md`。
3. 已新增 chart label 与 BSP label adapter 单元测试。
4. 已将 label 相关测试和审计脚本纳入 GitHub Actions。
5. 已将 BSP label layout 审计切换为 strict 护栏。
6. 已将全局结构文字布局审计纳入 GitHub Actions strict 护栏。

#### 5. 本地验证与 CI 护栏

1. 用户本地执行 `flutter analyze`，结果为 `No issues found`。
2. 用户本地验证 `audit_bsp_label_layout_usage.py --strict` 通过。
3. 用户本地验证两个 label 相关 Flutter test 全部通过。
4. GitHub Actions 已加入 `flutter analyze`、label tests、Dart 算法边界审计、chan.py a_ 护栏、输出合同校验。

### 已完成但仍需复验

这些项目已有实现或护栏，但不能直接视为最终完成，需要真实样本和真机复验：

1. BSP 绘制链路已接入，但仍需用真实样本确认 `1 / 1p / 2 / 2s / 3a / 3b`、`level=bi / level=seg`、`is_sure` 等字段全部覆盖。
2. `merged_bars` 已返回，但仍需用长样本确认 `raw_index / start_raw_index / end_raw_index / open / high / low / close` 与 chan.py 内部结果一致。
3. 标签避让已接入统一布局器，但仍需在 300 / 1000 / 3000 根 K 线窗口下做截图验收。
4. CI 护栏已加入，但仍需观察远端 Actions 实际运行结果。
5. Android 曾验证 Python 入包和结构返回，但本轮 label / contract / indicator 文档变更后仍需重新 `flutter run` 实机验收。

### 未完成

#### P0：生产链路收口

1. Windows `flutter run` 实机验收。
2. Android `flutter run` 实机验收。
3. 确认 App 生产链路完全不再 import / 调用旧 Dart FX / BI / SEG / ZS 算法。
4. 旧 Dart 算法层如需保留，只能作为 `legacy`、`tools`、`compare` 或测试用途。
5. 对 GitHub Actions 的真实运行结果做一次完整复核。

#### P1：chan.py 输出真实性校验

1. BSP 导出字段真实样本覆盖测试。
2. `merged_bars` 长样本一致性核对。
3. once 模式与 step 模式最终帧一致性核对。
4. `is_sure=false` 的 FX / BI / SEG / ZS / BSP 虚线或弱化显示统一检查。
5. 随机 5 只股票、3 个周期执行字段合同校验。

#### P2：easy-tdx 与指标显示

1. easy-tdx 后端 bars 增加 `volume / amount / turnover` 透传。
2. 后端增加 `indicators.vol` 输出。
3. Flutter 增加 VOL 副图。
4. 后端增加 MACD / MA / BOLL 展示指标输出。
5. Flutter 增加指标开关、crosshair 联动和 tooltip。
6. Android MethodChannel 输出合同与 Windows HTTP 输出合同保持一致。
7. easy-tdx 缺失字段必须写入 `meta.warning`，不得伪造 turnover、amount 等字段。

#### P3：K线图最终显示验收

1. 300 根、1000 根、3000 根 K线窗口截图验收。
2. FX / BI / SEG / ZS / BSP 文本开启时不允许明显重叠。
3. 缩放、拖动、逐K回放时 label lane 不应跳乱或遮挡主结构。
4. 密集区域应自动隐藏低优先级文字，保留结构点位。
5. OHLC、VOL、指标数值应优先放到 crosshair / tooltip / 侧栏，不应在图面常驻堆叠。

#### P4：README 与 Vespa 文档索引继续补强

1. 将 README 中 CChan / CChanConfig 说明继续链接到 Vespa quick_guide 对应章节。
2. 在 README 或 docs 中补充 `trigger_step / step_load / trigger_load` 的区别和当前分支支持范围。
3. 明确 segseg / segzs / segbsp 暂作为增强项，不进入当前主流程强制显示。
4. 明确策略、机器学习、AutoML、交易引擎不属于本轮任务范围。

### 下一批建议任务

1. 先跑 Windows / Android `flutter run`，确认当前 README 所列完成项不是只停留在代码层。
2. 用真实 easy-tdx 或本地长样本导出一次完整 analysis JSON，执行：

```bash
python tools/validate_chanpy_output_contract.py path/to/analysis.json
python tools/validate_easy_tdx_indicator_contract.py path/to/analysis.json
```

3. 对 `OriginKlineChart` 做 300 / 1000 / 3000 根窗口截图验收，确认 label lane 实际解决重叠问题。
4. 开始实现 easy-tdx 的 VOL / amount / turnover / indicators 输出与 Flutter 副图显示。

## 当前注意事项

此前长样本 diff 显示 Dart 复刻算法仍在 BI 初始化处与 chan.py 不一致：FX 已 0 mismatch，但 BI 少第一笔，导致 SEG / ZS 索引错位。因此本分支不再继续追 Dart 复刻，而改为 Python chan.py 单一计算源。

Android 运行期经验见：

```text
docs/chanpy_runtime_lessons.md
```
