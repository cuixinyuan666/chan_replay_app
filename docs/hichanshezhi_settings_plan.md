# hichanshezhi 设置页改动记录

## 目标

基于 `hichan` 创建 `hichanshezhi`，从 `origin_vespa_tdx`（后来改名为 `hichan`）这条历史演进线中重新定位 `zhibiao` 旧实现，提取其中 `复盘` 页的缠论 `CChanConfig` 设置，新增与 `复盘`、`单股多级别复盘` 同级的 `设置` 页面，并为 `单股多级别复盘` 的 `analyze_multi` 提供可复用的缠论配置基础。

## 重新搜索结论

- 实际仓库：`cuixinyuan666/chan_replay_app`。
- 基线分支：`origin_vespa_tdx` 与 `hichan` 当前为同一提交 `8fcd455a456a8c196e77ce7694d6ab5c6ed609bb`。
- 历史参考：`zhibiao` 是 `origin_vespa_tdx / hichan` 演进线上的旧实现参考，不是 `chan_month5` 下的来源。
- 参考文件：`lib/ui/pages/origin_replay_page_v2.dart`。
- 来源内容：`_settingDefaults`、`_bspTypes`、`_macdAlgoValues`、BSP 高级覆盖后缀、设置分组与控件语义。

## 已发现并修复的适配隐患

- 隐患：初版设置页只负责展示、编辑、恢复默认和复制 JSON，`S13SingleStockReplayPage` 的 `_loadReplay()` 仍然只向 `analyze_multi` 传入 `bi_algo / seg_algo / zs_algo` 三项硬编码基础配置。
- 修复：新增 `lib/core/settings/chan_config_store.dart`，把历史 `CChanConfig` 默认值、枚举、分组、校验、BSP 高级覆盖解析集中到共享配置仓库。
- 修复：`lib/ui/pages/chan_settings_page.dart` 改为写入 `ChanConfigStore`，设置页不再只是孤立展示。
- 修复：`lib/data/python_multi_level_chan_analysis_source.dart` 在所有 `analyze_multi` 请求构建时调用 `ChanConfigStore.backendConfig(base: config)`，将调用方基础配置与共享设置页配置合成为最终后端 `config`。
- 效果：`单股多级别复盘` 当前仍可保留原有 `_loadReplay()` 低冲突实现，但其请求进入后端前会被统一补齐为完整 `CChanConfig`，设置页的改动会影响多级别缠论计算。

## 合并原则

- 不整页搬运 `origin_replay_page_v2.dart`，避免覆盖 `hichan` 当前复盘与 S13 多级别复盘实现。
- 新增独立页面 `lib/ui/pages/chan_settings_page.dart`，只在 `root_page.dart` 做最小路由接入。
- 不直接大改 `S13SingleStockReplayPage` 的 复盘 UI / marker / 区间套逻辑，避免和同级功能分支产生大面积冲突。
- 通过 `PythonMultiLevelChanAnalysisSource.analyzeMulti()` 统一接入共享配置，优先保证所有 `analyze_multi` 调用都使用同一份可审计的 `CChanConfig`。

## 已实现

- 新增 `设置` 同级页面。
- 新增根路由索引 `_settingsIndex = 5`。
- 根路由工具列新增 `设置` 按钮。
- 新增共享配置仓库 `lib/core/settings/chan_config_store.dart`。
- `analyze_multi` 请求统一合成并发送共享 `CChanConfig`。
- 设置页收录以下配置组：
  - 回放 / 数据校验
  - 笔 BI
  - 线段 SEG
  - 中枢 ZS
  - 指标模型
  - 买卖点 BSP
- 设置页支持搜索、变更计数、非法值提示、恢复默认、复制后端 `CChanConfig` JSON。

## 验证说明

本次通过 GitHub Connector 直接创建远端分支并提交，未在本地执行 `flutter analyze` 或启动 App。最后由你在本地统一运行验证。
