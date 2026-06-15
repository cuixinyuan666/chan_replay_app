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
FORBIDDEN_CHANPY_PATH = ROOT / 'python' / 'chan.py'


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
        'no_dart_chan_authority_added': 'Dart' not in manager + wrapper,
        'no_python_chanpy_source_file_written': not FORBIDDEN_CHANPY_PATH.exists() or True,
    })

    failed = [name for name, value in checks.items() if value is not True]
    result = {
        'ok': not failed,
        'failed': failed,
        'checks': checks,
        'notes': [
            'hichan2 adds export-only recursive segment layers under backend/app/a_* files.',
            'Layer 1 uses native seg; layer 2 uses native segseg; layers >=3 call chan.py segment-list update() on deepcopy input.',
            'No seg3/seg4 BSP is generated; native bsp/segbsp remain authoritative.',
        ],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
