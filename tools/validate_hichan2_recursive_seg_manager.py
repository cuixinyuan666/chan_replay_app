#!/usr/bin/env python3
from __future__ import annotations

import ast
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MANAGER = ROOT / 'backend' / 'app' / 'a_recursive_seg_manager.py'
WRAPPER = ROOT / 'backend' / 'app' / 'a_multilevel_native_timed_recursive_engine.py'
ENTRY = ROOT / 'backend' / 'app' / 'a_multilevel_engine_timed.py'
DART_SNAPSHOT = ROOT / 'lib' / 'core' / 'models' / 'chan_snapshot.dart'
DART_RECURSIVE_SEG = ROOT / 'lib' / 'core' / 'models' / 'recursive_seg.dart'
DART_PARSER = ROOT / 'lib' / 'data' / 'chan_snapshot_json_parser.dart'
DART_OVERLAY = ROOT / 'lib' / 'ui' / 'widgets' / 'recursive_seg_origin_kline_chart.dart'
S12_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 's12_single_stock_replay_page.dart'
LEVEL_PROMOTER_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'level_promoter_page.dart'
LEVEL_PROMOTER_SETTINGS = ROOT / 'lib' / 'core' / 'settings' / 'level_promoter_settings.dart'
CHAN_CONFIG = ROOT / 'lib' / 'core' / 'settings' / 'chan_config_store.dart'
SINGLE_SOURCE = ROOT / 'lib' / 'data' / 'python_chan_analysis_source.dart'
SCANNER_CLIENT = ROOT / 'lib' / 'data' / 'scanner_backend_client.dart'
ROOT_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'root_page.dart'


def _read(path: Path) -> str:
    return path.read_text(encoding='utf-8')


def _syntax_ok(path: Path) -> bool:
    ast.parse(_read(path), filename=str(path))
    return True


def main() -> None:
    checks: dict[str, Any] = {}
    missing: list[str] = []

    for label, path in {
        'manager_exists': MANAGER,
        'wrapper_exists': WRAPPER,
        'entry_exists': ENTRY,
        'dart_snapshot_exists': DART_SNAPSHOT,
        'dart_recursive_seg_exists': DART_RECURSIVE_SEG,
        'dart_parser_exists': DART_PARSER,
        'dart_overlay_exists': DART_OVERLAY,
        's12_page_exists': S12_PAGE,
        'level_promoter_page_exists': LEVEL_PROMOTER_PAGE,
        'level_promoter_settings_exists': LEVEL_PROMOTER_SETTINGS,
        'chan_config_exists': CHAN_CONFIG,
        'single_source_exists': SINGLE_SOURCE,
        'scanner_client_exists': SCANNER_CLIENT,
        'root_page_exists': ROOT_PAGE,
    }.items():
        checks[label] = path.exists()
        if not path.exists():
            missing.append(label)

    if missing:
        print(json.dumps({'ok': False, 'missing': missing, 'checks': checks}, ensure_ascii=False, indent=2))
        raise SystemExit(1)

    manager = _read(MANAGER)
    wrapper = _read(WRAPPER)
    entry = _read(ENTRY)
    dart_snapshot = _read(DART_SNAPSHOT)
    dart_recursive_seg = _read(DART_RECURSIVE_SEG)
    dart_parser = _read(DART_PARSER)
    dart_overlay = _read(DART_OVERLAY)
    s12_page = _read(S12_PAGE)
    level_promoter_page = _read(LEVEL_PROMOTER_PAGE)
    level_promoter_settings = _read(LEVEL_PROMOTER_SETTINGS)
    chan_config = _read(CHAN_CONFIG)
    single_source = _read(SINGLE_SOURCE)
    scanner_client = _read(SCANNER_CLIENT)
    root_page = _read(ROOT_PAGE)
    s12_lines = [line.strip() for line in s12_page.splitlines()]
    combined_backend = manager + wrapper + entry
    combined_dart = dart_snapshot + dart_recursive_seg + dart_parser + dart_overlay + s12_page + level_promoter_page + root_page

    checks.update({
        'manager_syntax_ok': _syntax_ok(MANAGER),
        'wrapper_syntax_ok': _syntax_ok(WRAPPER),
        'entry_syntax_ok': _syntax_ok(ENTRY),
        'entry_routes_to_recursive_wrapper': 'analyze_multi_native_timed_recursive' in entry,
        'exports_seg_layers': "'seg_layers'" in manager,
        'exports_recursive_seg_meta': "'recursive_seg_meta'" in manager,
        'layer1_native_seg_rows': 'native_seg_rows' in manager and "layers['1']" in manager,
        'layer2_native_or_generated': 'segseg_list' in manager and 'generated from native seg_list' in manager and "layers['2']" in manager,
        'layers_2_plus_use_chanpy_update': '_recursive_update_layer' in manager and '_update_seg_list(dst, src_copy)' in manager,
        'layers_2_plus_use_deepcopy_guard': 'copy.deepcopy' in manager and 'pollution_guard' in manager,
        'max_level_customizable_without_4_or_8_cap': 'level_promoter_max_level' in manager and 'return max(2, value)' in manager and '_MAX_RECURSIVE_SEG_LEVEL' not in manager,
        'segN_bsp_exported_as_independent_fields': 'seg_bsp_layers' in manager and "result[f'seg{layer}_bsp']" in manager and 'native bsp' in manager,
        'wrapper_attaches_to_once_result': '_native_once_response' in wrapper and '_attach_recursive_seg_layers(' in wrapper,
        'wrapper_attaches_to_step_final_result': '_recursive_timed_native_step_response' in wrapper and 'last_chan' in wrapper,
        'metadata_marks_export_policy': 'recursive_seg_layer_policy' in wrapper and 'recursive_seg_bsp_policy' in wrapper,
        'dart_recursive_seg_dto_exists': 'class RecursiveSEG' in dart_recursive_seg and 'RecursiveSegDirection' in dart_recursive_seg,
        'dart_snapshot_exposes_recursive_layers': 'recursiveSegLayers' in dart_snapshot and 'Map<int, List<RecursiveSEG>>' in dart_snapshot,
        'dart_snapshot_exposes_recursive_bsp_layers': 'recursiveSegBsps' in dart_snapshot,
        'dart_parser_reads_backend_seg_layers': "data['seg_layers']" in dart_parser and '_parseRecursiveSegLayers' in dart_parser,
        'dart_parser_reads_backend_recursive_bsp_layers': "data['seg_bsp_layers']" in dart_parser and "data['segBspLayers']" in dart_parser and '_parseRecursiveSegBspLayers(data)' in dart_parser,
        'dart_parser_passes_recursive_bsp_to_snapshot': 'recursiveSegBsps: recursiveSegBsps' in dart_parser,
        'dart_parser_keeps_endpoint_candidates_out_of_real_bsp': '_segBspLayerFromKey' in dart_parser and "r'^seg(\\d+)_bsp$'" in dart_parser and 'endpoint_bsp' not in dart_parser,
        'dart_frontend_parser_is_passive': 'must not synthesize or calculate Chan structures' in dart_parser,
        'dart_overlay_wraps_origin_chart': 'class RecursiveSegOriginKlineChart' in dart_overlay and 'base.OriginKlineChart' in dart_overlay,
        'dart_overlay_reads_recursive_layers': 'snapshot.recursiveSegLayers.entries' in dart_overlay,
        'dart_overlay_prefers_backend_recursive_bsp_types': 'if (snapshot.recursiveSegBsps.isNotEmpty)' in dart_overlay and 'text: bsp.type' in dart_overlay,
        'dart_overlay_keeps_endpoint_fallback_only': 'Backward compatible display fallback' in dart_overlay and 'SEG${layer}_B' in dart_overlay,
        'dart_overlay_displays_segN_bsp': 'showRecursiveSegBsp' in dart_overlay and 'SEG${layer}_B' in dart_overlay,
        'dart_overlay_skips_layer1_duplicate': 'if (layer == 1) continue' in dart_overlay,
        'dart_overlay_uses_safe_layer_bounds': 'minRecursiveSegLayer < 1 ? 1 : minRecursiveSegLayer' in dart_overlay and '_effectiveMaxRecursiveSegLayer' in dart_overlay,
        'dart_overlay_uses_global_level_promoter_default': 'LevelPromoterSettings.currentMaxLayer' in dart_overlay and 'int? maxRecursiveSegLayer' in dart_overlay,
        'dart_overlay_uses_locked_nonpersistent_drawing_objects': 'TradingViewDrawingTool.trendLine' in dart_overlay and 'locked: true' in dart_overlay,
        'dart_overlay_uses_raw_index_price_anchors': 'DrawingAnchor.chart(rawIndex: seg.startRawIndex, price: seg.startPrice)' in dart_overlay and 'DrawingAnchor.chart(rawIndex: seg.endRawIndex, price: seg.endPrice)' in dart_overlay,
        's12_imports_recursive_chart': "import '../widgets/recursive_seg_origin_kline_chart.dart';" in s12_lines,
        's12_uses_recursive_chart': 'return RecursiveSegOriginKlineChart(' in s12_page,
        's12_recursive_overlay_default_enabled': 'showRecursiveSegLayers: false' not in s12_page,
        's12_no_direct_origin_chart_import': "import '../widgets/origin_kline_chart.dart';" not in s12_lines,
        's12_retains_replay_entrypoints': 'class S12SingleStockReplayPage' in s12_page and 'Future<void> _loadReplay()' in s12_page and 'PythonMultiLevelChanAnalysisSource' in s12_page,
        's12_retains_step_frame_controls': 'Widget _frameControls()' in s12_page and 'Slider(' in s12_page and '_frameIndex' in s12_page,
        'level_promoter_route_entry': '级别推进器' in root_page and 'LevelPromoterPage' in root_page,
        'level_promoter_default_is_global_2': 'defaultMaxLayer = 2' in level_promoter_settings,
        'level_promoter_page_is_quantity_only': 'N段数量' in level_promoter_page and '保存全局设置' in level_promoter_page and 'PythonMultiLevelChanAnalysisSource' not in level_promoter_page,
        'level_promoter_global_config_injection': 'LevelPromoterSettings.configFields' in chan_config and 'LevelPromoterSettings.applyToConfig(config)' in single_source and 'LevelPromoterSettings.applyToConfig(config)' in scanner_client,
        'no_dart_chan_algorithm_added': 'check_fx' not in combined_dart and 'check_bi' not in combined_dart and 'cal_seg' not in combined_dart,
        'no_chanpy_source_write_path_added': 'python/chan.py' not in combined_backend and 'open(' not in manager,
    })

    failed = [name for name, value in checks.items() if value is not True]
    result = {
        'ok': not failed,
        'failed': failed,
        'checks': checks,
        'notes': [
            'hichan2 keeps recursive segment export under backend/app/a_* files.',
            'Layer 1 uses native seg; layer 2 prefers native segseg and can be generated from native seg_list when segseg is unavailable.',
            '级别推进器 is now a global N setting page; default N=2 and only quantity is editable.',
            'Global N is injected into analyze_multi, single analyze/analyze_bars, scanner payload, and recursive chart display bounds.',
            'seg2_bsp..segN_bsp backend rows are parsed into ChanSnapshot.recursiveSegBsps so frontend labels use backend B/S + 1,1p,2,2s,3a,3b types.',
            'seg{N}_endpoint_bsp compatibility labels remain fallback-only and are not mixed into real recursive BSP rows.',
        ],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
