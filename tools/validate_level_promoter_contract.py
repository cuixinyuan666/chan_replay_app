#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
paths = {
    'page': ROOT / 'lib/ui/pages/level_promoter_page.dart',
    'settings': ROOT / 'lib/core/settings/level_promoter_settings.dart',
    'chan_config': ROOT / 'lib/core/settings/chan_config_store.dart',
    'single_source': ROOT / 'lib/data/python_chan_analysis_source.dart',
    'scanner_client': ROOT / 'lib/data/scanner_backend_client.dart',
    'chart': ROOT / 'lib/ui/widgets/recursive_seg_origin_kline_chart.dart',
    'backend': ROOT / 'backend/app/a_recursive_seg_manager.py',
}
texts = {k: p.read_text(encoding='utf-8') if p.exists() else '' for k, p in paths.items()}
checks = {f'{k}_exists': p.exists() for k, p in paths.items()}
checks.update({
    'default_n_is_2': 'defaultMaxLayer = 2' in texts['settings'],
    'only_quantity_page': 'N段数量' in texts['page'] and '保存全局设置' in texts['page'] and 'PythonMultiLevelChanAnalysisSource' not in texts['page'],
    'multi_level_global_config': 'LevelPromoterSettings.configFields' in texts['chan_config'],
    'single_level_global_config': 'LevelPromoterSettings.applyToConfig(config)' in texts['single_source'],
    'scanner_global_config': 'LevelPromoterSettings.applyToConfig(config)' in texts['scanner_client'],
    'chart_global_layer_bound': 'LevelPromoterSettings.currentMaxLayer' in texts['chart'],
    'backend_exports_recursive_bsp': 'seg_bsp_layers' in texts['backend'] and "result[f'seg{layer}_bsp']" in texts['backend'],
})
failed = [k for k, v in checks.items() if v is not True]
print(json.dumps({'ok': not failed, 'failed': failed, 'checks': checks}, ensure_ascii=False, indent=2))
raise SystemExit(0 if not failed else 1)
