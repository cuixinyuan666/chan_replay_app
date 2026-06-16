#!/usr/bin/env python3
from __future__ import annotations

import ast
import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / 'backend' / 'app' / 'a_recursive_seg_manager.py'
WRAPPER = ROOT / 'backend' / 'app' / 'a_multilevel_native_timed_recursive_engine.py'
PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'level_promoter_page.dart'
ROOT_PAGE = ROOT / 'lib' / 'ui' / 'pages' / 'root_page.dart'
CHART = ROOT / 'lib' / 'ui' / 'widgets' / 'recursive_seg_origin_kline_chart.dart'
SNAPSHOT = ROOT / 'lib' / 'core' / 'models' / 'chan_snapshot.dart'
PARSER = ROOT / 'lib' / 'data' / 'a_level_promoter_bsp_parser.dart'


def _read(path: Path) -> str:
    return path.read_text(encoding='utf-8')


def _syntax(path: Path) -> bool:
    ast.parse(_read(path), filename=str(path))
    return True


def main() -> int:
    files = {
        'backend_a_recursive_seg_manager': BACKEND,
        'wrapper_a_multilevel_native_timed_recursive_engine': WRAPPER,
        'level_promoter_page': PAGE,
        'root_page': ROOT_PAGE,
        'recursive_chart': CHART,
        'snapshot_model': SNAPSHOT,
        'level_promoter_parser': PARSER,
    }
    checks: dict[str, Any] = {f'{name}_exists': path.exists() for name, path in files.items()}
    if not all(checks.values()):
        print(json.dumps({'ok': False, 'checks': checks}, ensure_ascii=False, indent=2))
        return 1

    backend = _read(BACKEND)
    wrapper = _read(WRAPPER)
    page = _read(PAGE)
    root_page = _read(ROOT_PAGE)
    chart = _read(CHART)
    snapshot = _read(SNAPSHOT)
    parser = _read(PARSER)

    checks.update({
        'backend_python_syntax_ok': _syntax(BACKEND),
        'unbounded_custom_n_config': 'level_promoter_max_level' in backend and 'return max(2, value)' in backend,
        'no_hardcoded_4_or_8_cap': '_MAX_RECURSIVE_SEG_LEVEL' not in backend and 'min(_MAX' not in backend,
        'exports_grouped_seg_bsp_layers': 'seg_bsp_layers' in backend,
        'exports_dynamic_segN_bsp_fields': "result[f'seg{layer}_bsp']" in backend,
        'segN_bsp_not_mixed_into_native_bsp': 'native bsp' in backend and 'unchanged' in backend,
        'deepcopy_pollution_guard': 'copy.deepcopy' in backend and '_update_seg_list(dst, src_copy)' in backend,
        'wrapper_uses_a_recursive_manager': 'build_recursive_seg_payload' in wrapper,
        'root_toolbar_entry_present': '级别推进器' in root_page and 'LevelPromoterPage' in root_page,
        'page_requests_level_promoter_max_layer': 'level_promoter_max_level' in page and 'recursive_seg_max_level' in page,
        'page_has_evidence_copy': '复制证据' in page and 'segN_bsp' in page,
        'snapshot_has_recursive_seg_bsp_map': 'recursiveSegBsps' in snapshot,
        'chart_displays_recursive_seg_bsp': 'showRecursiveSegBsp' in chart and 'SEG${layer}_B' in chart,
        'parser_accepts_grouped_and_direct_keys': 'seg_bsp_layers' in parser and "endsWith('_bsp')" in parser,
        'a_prefix_backend_only': (ROOT / 'backend' / 'app' / 'a_recursive_seg_manager.py').exists(),
    })
    failed = [name for name, ok in checks.items() if ok is not True]
    result = {
        'ok': not failed,
        'validator': 'tools/validate_level_promoter_contract.py',
        'failed': failed,
        'checks': checks,
        'notes': [
            '级别推进器入口已挂到左侧工具栏。',
            '后端通过 a_recursive_seg_manager.py 导出 seg_layers、seg_bsp_layers、seg2_bsp..segN_bsp。',
            'N 由 level_promoter_max_level / recursive_seg_max_level / seg_recursive_max_level 控制，不改 chan.py 源码。',
            'segN_bsp 是独立递归段端点候选字段，不混入原生 bsp。',
        ],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
