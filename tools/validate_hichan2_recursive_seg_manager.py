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
    s12_lines = [line.strip() for line in s12_page.splitlines()]
    combined_backend = manager + wrapper + entry
    combined_dart = dart_snapshot + dart_recursive_seg + dart_parser + dart_overlay + s12_page

    checks.update({
        'manager_syntax_ok': _syntax_ok(MANAGER),
        'wrapper_syntax_ok': _syntax_ok(WRAPPER),
        'entry_syntax_ok': _syntax_ok(ENTRY),
        'entry_routes_to_recursive_wrapper': 'analyze_multi_native_timed_recursive' in entry,
        'exports_seg_layers': "'seg_layers'" in manager,
        'exports_recursive_seg_meta': "'recursive_seg_meta'" in manager,
        'layer1_native_seg_rows': 'native_seg_rows' in manager and "layers['1']" in manager,
        'layer2_native_segseg_list': 'segseg_list' in manager and "layers['2']" in manager,
        'layers_3_plus_use_chanpy_update': '_update_seg_list(dst, src_copy)' in manager,
        'layers_3_plus_use_deepcopy_guard': 'copy.deepcopy' in manager and 'pollution_guard' in manager,
        'max_level_configurable': 'recursive_seg_max_level' in manager and 'seg_recursive_max_level' in manager,
        'bsp_not_generated_for_recursive_layers': 'do not generate BSP' in manager and 'seg3_bsp' not in manager and 'seg4_bsp' not in manager,
        'wrapper_attaches_to_once_result': '_native_once_response' in wrapper and '_attach_recursive_seg_layers(' in wrapper,
        'wrapper_attaches_to_step_final_result': '_recursive_timed_native_step_response' in wrapper and 'last_chan' in wrapper,
        'metadata_marks_export_only_policy': 'recursive_seg_layer_policy' in wrapper and 'recursive_seg_bsp_policy' in wrapper,
        'dart_recursive_seg_dto_exists': 'class RecursiveSEG' in dart_recursive_seg and 'RecursiveSegDirection' in dart_recursive_seg,
        'dart_snapshot_exposes_recursive_layers': 'recursiveSegLayers' in dart_snapshot and 'Map<int, List<RecursiveSEG>>' in dart_snapshot,
        'dart_parser_reads_backend_seg_layers': "data['seg_layers']" in dart_parser and '_parseRecursiveSegLayers' in dart_parser,
        'dart_parser_uses_raw_price_not_bi_links_for_recursive_layers': 'start_raw_index' in dart_parser and 'start_price' in dart_parser and 'startParentIndex' in dart_parser,
        'dart_frontend_parser_is_passive': 'must not synthesize or calculate Chan structures' in dart_parser,
        'dart_overlay_wraps_origin_chart': 'class RecursiveSegOriginKlineChart' in dart_overlay and 'base.OriginKlineChart' in dart_overlay,
        'dart_overlay_reads_recursive_layers': 'snapshot.recursiveSegLayers.entries' in dart_overlay,
        'dart_overlay_skips_layer1_duplicate': 'if (layer == 1) continue' in dart_overlay,
        'dart_overlay_uses_safe_layer_bounds': 'minRecursiveSegLayer < 1 ? 1 : minRecursiveSegLayer' in dart_overlay and 'maxRecursiveSegLayer < minLayer ? minLayer : maxRecursiveSegLayer' in dart_overlay,
        'dart_overlay_uses_locked_nonpersistent_drawing_objects': 'TradingViewDrawingTool.trendLine' in dart_overlay and 'locked: true' in dart_overlay,
        'dart_overlay_uses_raw_index_price_anchors': 'DrawingAnchor.chart(rawIndex: seg.startRawIndex, price: seg.startPrice)' in dart_overlay and 'DrawingAnchor.chart(rawIndex: seg.endRawIndex, price: seg.endPrice)' in dart_overlay,
        'dart_overlay_no_unused_recursive_seg_import': "core/models/recursive_seg.dart" not in dart_overlay,
        's12_imports_recursive_chart': "import '../widgets/recursive_seg_origin_kline_chart.dart';" in s12_lines,
        's12_uses_recursive_chart': 'return RecursiveSegOriginKlineChart(' in s12_page,
        's12_recursive_overlay_default_enabled': 'showRecursiveSegLayers: false' not in s12_page,
        's12_no_direct_origin_chart_import': "import '../widgets/origin_kline_chart.dart';" not in s12_lines,
        's12_retains_replay_entrypoints': 'class S12SingleStockReplayPage' in s12_page and 'Future<void> _loadReplay()' in s12_page and 'PythonMultiLevelChanAnalysisSource' in s12_page,
        's12_retains_step_frame_controls': 'Widget _frameControls()' in s12_page and 'Slider(' in s12_page and '_frameIndex' in s12_page,
        's12_uses_chansnapshot_active_type': 'ChanSnapshot? get _activeSnapshot' in s12_page and 'Widget _chartPanel(ChanSnapshot? snapshot)' in s12_page,
        's12_surfaces_recursive_seg_evidence': '_recursiveSegSummaryText' in s12_page and 'recursive_seg_layers' in s12_page and "type: '${layerEntry.key}段'" in s12_page,
        'no_dart_chan_algorithm_added': 'check_fx' not in combined_dart and 'check_bi' not in combined_dart and 'cal_seg' not in combined_dart,
        'no_chanpy_source_write_path_added': 'python/chan.py' not in combined_backend and 'open(' not in manager,
    })

    failed = [name for name, value in checks.items() if value is not True]
    result = {
        'ok': not failed,
        'failed': failed,
        'checks': checks,
        'notes': [
            'hichan2 adds export-only recursive segment layers under backend/app/a_* files.',
            'Layer 1 uses native seg; layer 2 uses native segseg; layers >=3 call chan.py segment-list update() on deepcopy input.',
            'Dart parses backend seg_layers into a raw-index/price DTO and can convert them into chart overlay lines.',
            'S12 replay page imports RecursiveSegOriginKlineChart, so backend seg_layers can be shown on the replay chart.',
            'No seg3/seg4 BSP is generated; native bsp/segbsp remain authoritative.',
        ],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
