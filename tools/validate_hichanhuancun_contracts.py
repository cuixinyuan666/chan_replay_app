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
    root_page_path = ROOT / 'lib/ui/pages/root_page.dart'
    run_log_page_path = ROOT / 'lib/ui/pages/run_log_page.dart'
    old_cache_page_path = ROOT / 'lib/ui/pages/cache_optimization_page.dart'
    chan_core_path = ROOT / 'python/chan.py'

    check('hardening module exists', hardening_path.exists(), str(hardening_path))
    check('backend package init exists', init_path.exists(), str(init_path))
    check('analyze_multi adapter exists', adapter_path.exists(), str(adapter_path))
    check('backend route file exists', main_path.exists(), str(main_path))
    check('root page exists', root_page_path.exists(), str(root_page_path))
    check('runtime log page exists', run_log_page_path.exists(), str(run_log_page_path))
    check('old cache optimization UI removed', not old_cache_page_path.exists(), str(old_cache_page_path))

    hardening = _read('backend/app/a_replay_contract_hardening.py') if hardening_path.exists() else ''
    init_text = _read('backend/app/__init__.py') if init_path.exists() else ''
    adapter = _read('backend/app/a_multilevel_engine_timed.py') if adapter_path.exists() else ''
    main_text = _read('backend/app/main.py') if main_path.exists() else ''
    root_page = _read('lib/ui/pages/root_page.dart') if root_page_path.exists() else ''
    run_log_page = _read('lib/ui/pages/run_log_page.dart') if run_log_page_path.exists() else ''

    required_hardening_tokens = {
        'session cache install': 'install_backend_kline_session_cache',
        'cache ttl meta': 'backend_session_kline_cache_ttl_seconds',
        'cache key policy': 'symbol,market,period,adjust,count,start,end',
        'bsp install': 'install_bsp_history_contract',
        'bsp anchor field': 'anchor_raw_index',
        'bsp display field': 'display_raw_index',
        'bsp confirmed field': 'confirmed',
        'chart lazy v2 contract': 'chart_lazy_layers_v2_transport_pruning',
        'chart lazy display layers': 'chart_lazy_layers_display_layers',
        'chart lazy transport layers': 'chart_lazy_layers_transport_layers',
        'chart lazy forced dependencies': 'chart_lazy_layers_forced_transport_layers',
        'chart lazy pruned counts': 'chart_lazy_layers_pruned_counts',
        'chart lazy prune function': '_prune_result_chart_layers',
        'anti future contract': 'anti_future_contract',
        'flutter no chan calculation': 'flutter_chan_calculation_allowed',
        'chan core unchanged meta': 'chan_py_core_unchanged',
    }
    for name, token in required_hardening_tokens.items():
        check(name, _has(hardening, token), token)

    check(
        'package init still installs kline cache',
        _has(init_text, 'install_backend_kline_session_cache()'),
        'backend/app/__init__.py',
    )
    check(
        'package init still installs bsp contract',
        _has(init_text, 'install_bsp_history_contract()'),
        'backend/app/__init__.py',
    )
    check(
        'analyze_multi adapter keeps native source',
        _has(adapter, 'analyze_multi_native_timed(')
        or _has(adapter, 'analyze_multi_native_timed_recursive('),
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
        'root imports runtime log page',
        _has(root_page, "import 'run_log_page.dart';"),
        'lib/ui/pages/root_page.dart',
    )
    check(
        'root removed cache page import',
        not _has(root_page, "import 'cache_optimization_page.dart';")
        and not _has(root_page, 'CacheOptimizationPage'),
        'legacy cache UI must not remain in route tree',
    )
    check(
        'root registers runtime log route',
        _has(root_page, 'const _RouteBuilder(child: RunLogPage())'),
        'same-level lazy route stack',
    )
    check(
        'root exposes runtime log route button',
        _has(root_page, "tooltip: '运行日志'")
        and _has(root_page, '_runLogIndex')
        and _has(root_page, 'Icons.receipt_long'),
        'left route tool column',
    )
    check(
        'runtime log page class and title',
        _has(run_log_page, 'class RunLogPage')
        and _has(run_log_page, "title: const Text('运行日志')"),
        'lib/ui/pages/run_log_page.dart',
    )
    check(
        'runtime log reads latest analysis evidence',
        _has(run_log_page, 'ReplayAnalysisStore.latestAnalysis')
        and _has(run_log_page, '_evidenceText'),
        'page must read saved analyze_multi result instead of recalculating Chan structures',
    )
    check(
        'runtime log exposes one-click copy',
        _has(run_log_page, '一键复制')
        and _has(run_log_page, '复制全部调试证据')
        and _has(run_log_page, 'Clipboard.setData'),
        'copy evidence buttons',
    )
    check(
        'runtime log exposes output box',
        _has(run_log_page, '日志输出框')
        and _has(run_log_page, 'SelectableText'),
        'readable log output box',
    )
    check(
        'runtime log captures method timings',
        _has(run_log_page, 'backend_route_analyze_multi_ms')
        and _has(run_log_page, 'backend_native_total_ms')
        and _has(run_log_page, 'backend_route_contract_hardening_ms')
        and _has(run_log_page, '_timingRows'),
        'method flow and *_ms extraction',
    )
    check(
        'runtime log captures cache and contract evidence',
        _has(run_log_page, 'backend_session_kline_cache_hits')
        and _has(run_log_page, 'chart_lazy_layers_contract')
        and _has(run_log_page, 'anti_future_status')
        and _has(run_log_page, 'bsp_rows_with_frozen_fields'),
        'cache/lazy/BSP/anti-future evidence',
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
        'branch_task': 'hichanhuancun runtime log UI replacement while preserving backend cache contracts',
        'checks': checks,
        'failed': failed,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
