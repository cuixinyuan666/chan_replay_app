#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = 'tools/validate_s11_guardrail_regression.py'

REQUIRED_COMMANDS: list[list[str]] = [
    [sys.executable, 'tools/validate_s10_long_history_count_expansion.py'],
    [sys.executable, 'tools/export_s8_strategy_batch_candidates.py'],
    [sys.executable, 'tools/validate_s8_strategy_batch_candidates.py'],
    [sys.executable, 'tools/validate_s8_app_batch_navigation.py'],
    [sys.executable, 'tools/audit_global_lazy_loading.py', '--strict'],
    [sys.executable, 'tools/check_chanpy_guardrails.py'],
]

OPTIONAL_SCRIPT_COMMANDS: list[list[str]] = [
    [sys.executable, 'tools/audit_dart_algorithm_usage.py'],
    [sys.executable, 'tools/audit_bsp_label_layout_usage.py', '--strict'],
    [sys.executable, 'tools/audit_origin_kline_global_label_layout_usage.py', '--strict'],
]

FORBIDDEN_GENERATED_PATHS = [
    Path('validate_s10_long_history_count_expansion.py'),
    Path('a_multilevel_native_engine_s10.py'),
]

GENERATED_OUTPUT_PATHS = [
    Path('test/fixtures/derived/s8_strategy_batch_candidates_v1.json'),
]


def _command_label(command: list[str]) -> str:
    display = list(command)
    if display and display[0] == sys.executable:
        display[0] = 'python'
    return ' '.join(display)


def _run(command: list[str], *, timeout: int) -> dict[str, Any]:
    proc = subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
    )
    stdout = proc.stdout.strip()
    stderr = proc.stderr.strip()
    return {
        'command': _command_label(command),
        'returncode': proc.returncode,
        'ok': proc.returncode == 0,
        'stdout_tail': stdout[-4000:],
        'stderr_tail': stderr[-2000:],
    }


def _script_exists(command: list[str]) -> bool:
    if len(command) < 2:
        return False
    script = ROOT / command[1]
    return script.exists()


def _path_status() -> dict[str, Any]:
    forbidden_present = [path.as_posix() for path in FORBIDDEN_GENERATED_PATHS if (ROOT / path).exists()]
    generated_present = [path.as_posix() for path in GENERATED_OUTPUT_PATHS if (ROOT / path).exists()]
    return {
        'forbidden_generated_files_present': forbidden_present,
        'local_generated_outputs_present': generated_present,
        'generated_output_policy': 'derived S8 JSON may be generated locally for validation but should not be committed by default',
    }


def main() -> int:
    parser = argparse.ArgumentParser(description='Run S11 guardrail regression after S10 long-history count expansion.')
    parser.add_argument('--timeout', type=int, default=120, help='per-command timeout in seconds')
    parser.add_argument('--include-flutter-analyze', action='store_true', help='also run flutter analyze when Flutter is available')
    args = parser.parse_args()

    required_results: list[dict[str, Any]] = []
    optional_results: list[dict[str, Any]] = []
    skipped_optional: list[str] = []

    for command in REQUIRED_COMMANDS:
        required_results.append(_run(command, timeout=args.timeout))

    for command in OPTIONAL_SCRIPT_COMMANDS:
        if _script_exists(command):
            optional_results.append(_run(command, timeout=args.timeout))
        else:
            skipped_optional.append(_command_label(command))

    flutter_result: dict[str, Any] | None = None
    if args.include_flutter_analyze:
        if shutil.which('flutter'):
            flutter_result = _run(['flutter', 'analyze'], timeout=max(args.timeout, 240))
        else:
            flutter_result = {
                'command': 'flutter analyze',
                'returncode': 127,
                'ok': False,
                'stdout_tail': '',
                'stderr_tail': 'flutter executable not found on PATH',
            }

    path_status = _path_status()
    required_ok = all(item['ok'] for item in required_results)
    optional_ok = all(item['ok'] for item in optional_results)
    flutter_ok = True if flutter_result is None else bool(flutter_result.get('ok'))
    hygiene_ok = not path_status['forbidden_generated_files_present']

    result = {
        'ok': required_ok and optional_ok and flutter_ok and hygiene_ok,
        'command': 'python tools/validate_s11_guardrail_regression.py',
        'validator': VALIDATOR,
        'stage': 'S11 post-S10 guardrail regression bundle',
        'source_policy': 'python/chan.py via native CChan(lv_list); Flutter/Dart display-only for Chan structures',
        'required_results': required_results,
        'optional_results': optional_results,
        'skipped_optional': skipped_optional,
        'flutter_result': flutter_result,
        'path_status': path_status,
        'required_ok': required_ok,
        'optional_ok': optional_ok,
        'flutter_ok': flutter_ok,
        'hygiene_ok': hygiene_ok,
        'chan_recalculated': False,
        'dart_chan_calculation_authority': False,
        'action_required_if_not_ok': '' if required_ok and optional_ok and flutter_ok and hygiene_ok else 'Inspect failed command stderr/stdout tails and remove forbidden generated root-level patch files before acceptance.',
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
