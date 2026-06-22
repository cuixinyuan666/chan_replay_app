# hichan 文本框任务续做状态

更新时间：2026-06-22
分支：`hichan`

## 本批已提交

### 1. 侧边栏滚轮循环滚动

文件：`lib/ui/widgets/auto_collapsible_side_toolbar.dart`

变更：

- 保留原有 `>` / `<` 展开收起逻辑。
- 鼠标滚轮滚到边栏底部后继续向下滚，会回到顶部。
- 鼠标滚轮滚到边栏顶部后继续向上滚，会跳到底部。
- 解决设置项大量迁入边栏后，滚动卡在端点的问题。

对应任务：

- “尽量将设置移动到边栏中，充满整个边栏，并增加鼠标滚轮可以循环滚动的功能”。

### 2. 筹码分布 target 选择防未来硬化

文件：`lib/core/analysis/chip_online_replay_adapter.dart`

变更：

- once 模式目标 K：`crosshairIndex > viewEndIndex > lastBarIndex`。
- step 模式目标 K：优先十字线，但不允许超过当前 `stepIndex`。
- 若 step 模式十字线指向未来 K，目标会 clamp 到当前 step。

对应任务：

- “once 模式按 crosshairIndex > viewEndIndex > lastBarIndex 选择筹码状态”。
- “step 模式只能使用当前 frame 及以前的数据”。
- “step 模式下如果 crosshairIndex > currentStepIndex，应当 clamp 到 currentStepIndex”。

### 3. S13 验证性 UI 清理脚本

文件：`tools/apply_s13_validation_ui_cleanup.py`

作用：

受保护地清理 `lib/ui/pages/s13_single_stock_replay_page.dart` 中的验证性、提示性、重复性 UI。

脚本会删除：

- `backend app-managed bundled Python` 禁用输入框。
- `窗口` 信息按钮。
- `复制 marker 证据` 按钮。
- `step` 信息按钮。
- `marker` 信息按钮。
- `1.382` 信息按钮。
- `segN 真实买卖点` 诊断区域。
- `回到最新` 诊断按钮。
- `校验` / `当前` 信息按钮。

脚本采用 exact-match protected patch：每个替换点必须只有一个匹配，否则直接退出，避免误删核心逻辑。

本地应用方式：

```bash
python tools/apply_s13_validation_ui_cleanup.py
flutter analyze
```

对应任务：

- “删除设置中的 backend app-managed bundled Python、窗口、复制marker证据、1.382、step、marker、segN真实买卖点、回到最新 等验证性提示性按钮”。
- “删除边栏中功能重复的按钮”。

## 本批未声称完成

以下内容仍是下一批硬任务，不能验收为完成：

1. 筹码分布后端 / checkpoint / cacheKey / settingsVersion 全闭环。
2. DAILY / MIN1 / MIN5 / TICK 同颗粒度上市以来历史基线。
3. tick 逐价成交桶聚合。
4. `chip_distribution_meta` 全字段输出。
5. 设置页筹码参数完全复用。
6. easy-tdx 全指标在 K线图主图 / 副图动态显示。
7. BSP step history、底部文字、手动/自动错对验证。
8. 区间套显示开关完整迁入边栏。
9. 画线工具点击无反应的根因修复。
10. 十字线移动卡顿的深度性能优化。
11. Android 全项目适配。
12. 段中枢、2段中枢、N段中枢显示及开关完整验收。
13. 研究/选股/回测专业 UI 和完整跑通闭环。

## 建议下一批顺序

1. 先运行并提交 `tools/apply_s13_validation_ui_cleanup.py` 生成的 S13 diff。
2. 实现 `BspStepReviewItem / BspBottomLabel / BspReviewStats`，先做手动“检查当前买卖点”。
3. 为 easy-tdx 指标建立动态指标注册表，前端不再只写死 `MA/BOLL/VOL/MACD`。
4. 新增后端筹码分布查询接口，返回 `chip_distribution_state` 和 `chip_distribution_meta`。
5. 再处理 Android 和性能深水区。
