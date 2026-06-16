# hichanshezhi 设置页改动记录

## 目标

基于 `hichan` 创建 `hichanshezhi`，从 `origin_vespa_tdx`（后来改名为 `hichan`）这条历史演进线中重新定位 `zhibiao` 旧实现，提取其中 `复盘` 页的缠论 `CChanConfig` 设置，新增与 `复盘`、`单股多级别复盘` 同级的 `设置` 页面。

## 重新搜索结论

- 实际仓库：`cuixinyuan666/chan_replay_app`。
- 基线分支：`origin_vespa_tdx` 与 `hichan` 当前为同一提交 `8fcd455a456a8c196e77ce7694d6ab5c6ed609bb`。
- 历史参考：`zhibiao` 是 `origin_vespa_tdx / hichan` 演进线上的旧实现参考，不是 `chan_month5` 下的来源。
- 参考文件：`lib/ui/pages/origin_replay_page_v2.dart`。
- 来源内容：`_settingDefaults`、`_bspTypes`、`_macdAlgoValues`、BSP 高级覆盖后缀、设置分组与控件语义。

## 合并原则

- 不整页搬运 `origin_replay_page_v2.dart`，避免覆盖 `hichan` 当前复盘与 S13 多级别复盘实现。
- 新增独立页面 `lib/ui/pages/chan_settings_page.dart`，只在 `root_page.dart` 做最小路由接入。
- 当前阶段设置页负责集中展示、编辑、恢复默认、复制 JSON；不直接改动 `OriginReplayStrictPage` 或 `S13SingleStockReplayPage` 的计算配置链路，后续可在确认统一配置存储口径后再接入运行时。

## 已实现

- 新增 `设置` 同级页面。
- 新增根路由索引 `_settingsIndex = 5`。
- 根路由工具列新增 `设置` 按钮。
- 设置页收录以下配置组：
  - 回放 / 数据校验
  - 笔 BI
  - 线段 SEG
  - 中枢 ZS
  - 指标模型
  - 买卖点 BSP
- 设置页支持搜索、变更计数、恢复默认、复制当前 `CChanConfig` JSON。

## 验证说明

本次通过 GitHub Connector 直接创建远端分支并提交，未在本地执行 `flutter analyze`。最后由你在本地统一运行验证。
