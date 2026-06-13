#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
PANEL = ROOT / 'lib' / 'ui' / 'widgets' / 'multi_level_interval_signal_panel.dart'

REQUIRED_SUBSTRINGS = {
    'strategy_default': "String _ruleMode = 'strategy';",
    'strategy_rule_default': "String _strategyRuleName = 'DAILY_2B_MIN30_1B';",
    'receiver_one_click_label': "const Text('S1一键复制')",
    'payload_button_label': "button: S1一键复制",
    'payload_status': 'status: s1_evidence_exported',
    'debug_copy_tools_flag': 'debug_copy_tools: de_emphasized',
    'debug_signal_button': "Debug: Copy Signal",
    'debug_time_log_button': "Debug: Copy Time Log",
    'debug_result_validation_button': "Debug: Copy Result Validation",
    'time_log_section': '--- Copy Time Log ---',
    'p0_section': '--- Copy P0 Summary ---',
    'step_section': '--- Copy Step Summary ---',
    'result_validation_section': '--- Copy Result Validation ---',
    'signal_section': '--- Copy Signal ---',
}

FORBIDDEN_SUBSTRINGS = {
    'pending_runtime_acceptance': 'pending_runtime_acceptance',
    'primary_copy_s1_evidence_label': "const Text('Copy S1 Evidence')",
    'dummy_merged_bar': '_dummyMergedBar',
}

FORBIDDEN_CALC_PATTERNS = {
    'dart_check_fx': r'\bcheckFx\b|\bcheck_fx\b',
    'dart_check_bi': r'\bcheckBi\b|\bcheck_bi\b',
    'dart_build_seg': r'\bbuildSeg\b|\bbuild_seg\b',
    'dart_build_zs': r'\bbuildZs\b|\bbuild_zs\b',
}


def _result(ok: bool, **extra: Any) -> dict[str, Any]:
    return {
        'ok': ok,
        'validator': 'tools/validate_r1_receiver_burden.py',
        'target': str(PANEL.relative_to(ROOT)),
        **extra,
    }


def main() -> int:
    if not PANEL.exists():
        print(json.dumps(_result(False, error='panel file not found'), ensure_ascii=False, indent=2), file=sys.stderr)
        return 1

    text = PANEL.read_text(encoding='utf-8')
    missing = [name for name, needle in REQUIRED_SUBSTRINGS.items() if needle not in text]
    forbidden = [name for name, needle in FORBIDDEN_SUBSTRINGS.items() if needle in text]
    forbidden_calc = [name for name, pattern in FORBIDDEN_CALC_PATTERNS.items() if re.search(pattern, text)]

    ok = not missing and not forbidden and not forbidden_calc
    payload_sections = [
        'Copy Time Log',
        'Copy P0 Summary',
        'Copy Step Summary',
        'Copy Result Validation',
        'Copy Signal',
    ]
    output = _result(
        ok,
        rule_mode_default='strategy' if "String _ruleMode = 'strategy';" in text else 'unknown',
        strategy_rule_default='DAILY_2B_MIN30_1B' if "String _strategyRuleName = 'DAILY_2B_MIN30_1B';" in text else 'unknown',
        one_click_label='S1一键复制' if "const Text('S1一键复制')" in text else 'missing',
        debug_copy_buttons=[
            label for label in ['Debug: Copy Signal', 'Debug: Copy Time Log', 'Debug: Copy Result Validation'] if label in text
        ],
        evidence_status='s1_evidence_exported' if 'status: s1_evidence_exported' in text else 'missing',
        evidence_sections=payload_sections,
        debug_copy_tools='de_emphasized' if 'debug_copy_tools: de_emphasized' in text else 'missing',
        missing=missing,
        forbidden=forbidden,
        forbidden_dart_calc_patterns=forbidden_calc,
        chan_recalculated=False,
        dart_chan_calculation_authority=False,
    )
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
