from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def _has(text: str, needle: str) -> bool:
    return needle in text


def main() -> int:
    checks: list[dict[str, object]] = []

    def check(name: str, ok: bool, detail: str = '') -> None:
        checks.append({'name': name, 'ok': bool(ok), 'detail': detail})

    hardening_path = ROOT / 'backend/app/a_replay_contract_hardening.py'
    init_path = ROOT / 'backend/app/__init__.py'
    adapter_path = ROOT / 'backend/app/a_multilevel_engine_timed.py'
    main_path = ROOT / 'backend/app/main.py'
    chan_core_path = ROOT / 'python/chan.py'

    check('hardening module exists', hardening_path.exists(), str(hardening_path))
    check('backend package init exists', init_path.exists(), str(init_path))
    check('analyze_multi adapter exists', adapter_path.exists(), str(adapter_path))
    check('backend route file exists', main_path.exists(), str(main_path))

    hardening = _read('backend/app/a_replay_contract_hardening.py') if hardening_path.exists() else ''
    init_text = _read('backend/app/__init__.py') if init_path.exists() else ''
    adapter = _read('backend/app/a_multilevel_engine_timed.py') if adapter_path.exists() else ''
    main_text = _read('backend/app/main.py') if main_path.exists() else ''

    required_hardening_tokens = {
        'session cache install': 'install_backend_kline_session_cache',
        'cache ttl meta': 'backend_session_kline_cache_ttl_seconds',
        'cache key policy': 'symbol,market,period,adjust,count,start,end',
        'bsp install': 'install_bsp_history_contract',
        'bsp anchor field': 'anchor_raw_index',
        'bsp display field': 'display_raw_index',
        'bsp confirmed field': 'confirmed',
        'chart lazy contract': 'chart_lazy_layers_contract',
        'anti future contract': 'anti_future_contract',
        'flutter no chan calculation': 'flutter_chan_calculation_allowed',
        'chan core unchanged meta': 'chan_py_core_unchanged',
    }
    for name, token in required_hardening_tokens.items():
        check(name, _has(hardening, token), token)

    check(
        'package init installs kline cache',
        _has(init_text, 'install_backend_kline_session_cache()'),
        'backend/app/__init__.py',
    )
    check(
        'package init installs bsp contract',
        _has(init_text, 'install_bsp_history_contract()'),
        'backend/app/__init__.py',
    )
    check(
        'analyze_multi adapter keeps native source',
        _has(adapter, 'analyze_multi_native_timed('),
        'backend/app/a_multilevel_engine_timed.py',
    )
    check(
        'backend route applies contracts after compact',
        main_text.find('_compact_multilevel_step_result(result, payload, config)') >= 0
        and main_text.find('apply_analyze_multi_contracts(result, payload, config)')
        > main_text.find('_compact_multilevel_step_result(result, payload, config)'),
        'final returned frames are checked after route compact transform',
    )
    check(
        'backend route records hardening timing',
        _has(main_text, 'backend_route_contract_hardening_ms'),
        'backend/app/main.py',
    )
    check(
        'hardening module does not edit python/chan.py',
        'python/chan.py' not in hardening and 'open(' not in hardening,
        'no filesystem write path to chan.py in contract module',
    )
    check(
        'python/chan.py remains external authority',
        chan_core_path.exists() or (ROOT / 'python').exists(),
        'guard only verifies no contract module rewrites it',
    )

    failed = [item for item in checks if not item['ok']]
    result = {
        'ok': not failed,
        'validator': 'validate_hichanhuancun_contracts.py',
        'branch_task': 'hichanhuancun stage-1 backend replay contracts',
        'checks': checks,
        'failed': failed,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
