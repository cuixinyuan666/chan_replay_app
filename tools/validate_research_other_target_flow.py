#!/usr/bin/env python3
"""Validate the research page's other-target backend flow.

This script exercises the same backend chain used by the Flutter research page when
"其它标的" is selected:

    health -> analyze_multi -> BSP features -> ML score -> backtest -> pipeline
           -> segN composite backtest

It intentionally uses only Python's standard library so it can run in the user's
existing environment without extra test dependencies.
"""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_BASE_URL = 'http://127.0.0.1:8000'
DEFAULT_SYMBOL = '600340'
DEFAULT_MARKET = 'SH'
DEFAULT_LEVEL = 'MIN5'
DEFAULT_START = '2025-09-01'
DEFAULT_END = '2026-06-18'


@dataclass
class HttpResult:
    status: int
    payload: dict[str, Any]


class ValidationError(RuntimeError):
    pass


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _json_post(base_url: str, endpoint: str, payload: dict[str, Any], timeout: int = 300) -> HttpResult:
    data = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
    request = urllib.request.Request(
        f'{base_url.rstrip("/")}{endpoint}',
        data=data,
        headers={'content-type': 'application/json'},
        method='POST',
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode('utf-8')
            decoded = json.loads(body)
            if not isinstance(decoded, dict):
                raise ValidationError(f'{endpoint} response is not a JSON object')
            return HttpResult(status=response.status, payload=decoded)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode('utf-8', errors='replace')
        raise ValidationError(f'{endpoint} HTTP {exc.code}: {body}') from exc


def _json_get(base_url: str, endpoint: str, timeout: int = 10) -> HttpResult:
    try:
        with urllib.request.urlopen(f'{base_url.rstrip("/")}{endpoint}', timeout=timeout) as response:
            body = response.read().decode('utf-8')
            decoded = json.loads(body)
            if not isinstance(decoded, dict):
                raise ValidationError(f'{endpoint} response is not a JSON object')
            return HttpResult(status=response.status, payload=decoded)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode('utf-8', errors='replace')
        raise ValidationError(f'{endpoint} HTTP {exc.code}: {body}') from exc


def _pick_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(('127.0.0.1', 0))
        return int(sock.getsockname()[1])


def _start_backend(port: int) -> subprocess.Popen[str]:
    root = _repo_root()
    env = os.environ.copy()
    env.setdefault('PYTHONIOENCODING', 'utf-8')
    env['PYTHONPATH'] = f'{root}{os.pathsep}{env.get("PYTHONPATH", "")}'.rstrip(os.pathsep)
    return subprocess.Popen(
        [
            sys.executable,
            '-m',
            'uvicorn',
            'backend.app.main:app',
            '--host',
            '127.0.0.1',
            '--port',
            str(port),
        ],
        cwd=str(root),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding='utf-8',
        errors='replace',
    )


def _wait_health(base_url: str, process: subprocess.Popen[str] | None, timeout: int = 45) -> dict[str, Any]:
    deadline = time.time() + timeout
    last_error: str | None = None
    while time.time() < deadline:
        if process is not None and process.poll() is not None:
            output = ''
            if process.stdout is not None:
                try:
                    output = process.stdout.read() or ''
                except Exception:
                    output = ''
            raise ValidationError(f'backend process exited early with code {process.returncode}\n{output}')
        try:
            health = _json_get(base_url, '/health', timeout=3).payload
            if health.get('ok') is True:
                return health
            last_error = f'/health returned ok={health.get("ok")!r}'
        except Exception as exc:  # noqa: BLE001 - preserve probe detail
            last_error = str(exc)
        time.sleep(0.5)
    raise ValidationError(f'backend did not become healthy: {last_error}')


def _assert_ok(name: str, payload: dict[str, Any]) -> None:
    if payload.get('ok') is False:
        raise ValidationError(f'{name} returned ok=false: {payload.get("error") or payload}')


def _list_len(value: Any, key: str | None = None) -> int:
    source = value.get(key) if isinstance(value, dict) and key else value
    return len(source) if isinstance(source, list) else 0


def _level_payload(levels: Any, level: str) -> dict[str, Any]:
    if not isinstance(levels, dict):
        raise ValidationError('analyze_multi response missing levels object')
    candidates = [level, level.upper(), level.lower()]
    for candidate in candidates:
        value = levels.get(candidate)
        if isinstance(value, dict):
            return dict(value)
    for key, value in levels.items():
        if str(key).strip().upper() == level.upper() and isinstance(value, dict):
            return dict(value)
    raise ValidationError(f'analyze_multi response missing level payload: {level}')


def _normalize_analysis(raw: dict[str, Any], *, symbol: str, market: str, level: str, adjust: str) -> dict[str, Any]:
    analysis = dict(raw)
    meta = dict(analysis.get('meta')) if isinstance(analysis.get('meta'), dict) else {}
    normalized_level = level.strip().upper()
    meta.update({
        'symbol': symbol,
        'market': market,
        'freq': normalized_level,
        'period': normalized_level,
        'adjust': adjust,
        'main_level': normalized_level,
        'levels': [normalized_level],
        'source': 'tools.validate_research_other_target_flow',
        'research_other_target': True,
        'chan_py_polluted': False,
    })
    analysis['meta'] = meta
    analysis['symbol'] = symbol
    analysis['market'] = market
    analysis['freq'] = normalized_level
    analysis['period'] = normalized_level
    analysis['adjust'] = adjust
    if not isinstance(analysis.get('bsp'), list) and isinstance(analysis.get('bsps'), list):
        analysis['bsp'] = analysis['bsps']
    if analysis.get('seg_bsp_history_layers') is None and analysis.get('seg_bsp_layers') is not None:
        analysis['seg_bsp_history_layers'] = analysis['seg_bsp_layers']
    return analysis


def _base_payload(args: argparse.Namespace) -> dict[str, Any]:
    return {
        'symbol': args.symbol,
        'market': args.market.upper(),
        'levels': [args.level.upper()],
        'level': args.level.upper(),
        'main_level': args.level.upper(),
        'clock_level': args.level.upper(),
        'adjust': args.adjust,
        'start': args.start,
        'end': args.end,
        'count': args.count,
        'config': {
            'bi_algo': args.bi_algo,
            'seg_algo': args.seg_algo,
            'zs_algo': args.zs_algo,
            'recursive_seg_max_level': args.recursive_seg_max_level,
        },
    }


def _seg_composite_payload(args: argparse.Namespace) -> dict[str, Any]:
    payload = _base_payload(args)
    payload.update({
        'entry_rule': {
            'conditions': [
                {'layer': 2, 'side': 'buy', 'types': ['1']},
                {'layer': 3, 'side': 'buy', 'types': ['3a']},
            ],
            'dedupe': True,
        },
        'exit_rule': {
            'conditions': [
                {'layer': 2, 'side': 'sell', 'types': ['1']},
            ],
            'dedupe': True,
        },
        'options': {
            'max_hold_days': args.horizon,
            'fee_bps': 3,
            'slippage_bps': 2,
        },
    })
    return payload


def validate(args: argparse.Namespace) -> dict[str, Any]:
    process: subprocess.Popen[str] | None = None
    base_url = args.base_url.rstrip('/')
    if args.start_backend:
        port = _pick_free_port()
        process = _start_backend(port)
        base_url = f'http://127.0.0.1:{port}'
    try:
        health = _wait_health(base_url, process, timeout=args.startup_timeout)
        if health.get('backend') != 'origin_vespa_tdx' or health.get('research_api') is not True:
            raise ValidationError(f'incompatible backend health: {health}')

        analyze_payload = _base_payload(args)
        analyze_payload['mode'] = 'once'
        analyze = _json_post(base_url, '/api/chan/analyze_multi', analyze_payload, timeout=args.timeout).payload
        _assert_ok('analyze_multi', analyze)
        raw_level = _level_payload(analyze.get('levels'), args.level)
        analysis = _normalize_analysis(
            raw_level,
            symbol=args.symbol,
            market=args.market.upper(),
            level=args.level.upper(),
            adjust=args.adjust,
        )
        if _list_len(analysis.get('bars')) <= 0:
            raise ValidationError('normalized analysis has no bars')

        features = _json_post(
            base_url,
            '/api/research/bsp/features',
            {'analysis': analysis, 'label_horizon': args.horizon, 'include_labels': True},
            timeout=args.timeout,
        ).payload
        _assert_ok('features', features)
        feature_rows = features.get('features')
        if not isinstance(feature_rows, list):
            raise ValidationError('features response missing features list')

        scores = _json_post(
            base_url,
            '/api/research/ml/score',
            {'analysis': analysis, 'label_horizon': args.horizon, 'model': args.model},
            timeout=args.timeout,
        ).payload
        _assert_ok('scores', scores)
        score_rows = scores.get('scores')
        if not isinstance(score_rows, list):
            raise ValidationError('score response missing scores list')

        backtest = _json_post(
            base_url,
            '/api/research/backtest',
            {
                'analysis': analysis,
                'horizon': args.horizon,
                'fee_rate': args.fee_rate,
                'slippage': args.slippage,
                'initial_cash': args.initial_cash,
            },
            timeout=args.timeout,
        ).payload
        _assert_ok('backtest', backtest)

        pipeline = _json_post(
            base_url,
            '/api/research/pipeline',
            {
                'analysis': analysis,
                'horizon': args.horizon,
                'model': args.model,
                'fee_rate': args.fee_rate,
                'slippage': args.slippage,
                'initial_cash': args.initial_cash,
            },
            timeout=args.timeout,
        ).payload
        _assert_ok('pipeline', pipeline)
        if not isinstance(pipeline.get('features'), dict) or not isinstance(pipeline.get('scores'), dict):
            raise ValidationError('pipeline response missing nested features/scores objects')

        seg_composite = _json_post(
            base_url,
            '/api/research/seg-composite/backtest',
            _seg_composite_payload(args),
            timeout=args.timeout,
        ).payload
        _assert_ok('seg-composite', seg_composite)

        return {
            'ok': True,
            'base_url': base_url,
            'symbol': args.symbol,
            'market': args.market.upper(),
            'level': args.level.upper(),
            'start': args.start,
            'end': args.end,
            'health': {
                'backend': health.get('backend'),
                'engine': health.get('engine'),
                'research_api': health.get('research_api'),
            },
            'analyze_multi': {
                'bars': _list_len(analysis.get('bars')),
                'bsp': _list_len(analysis.get('bsp')),
                'bi': _list_len(analysis.get('bi')),
                'seg': _list_len(analysis.get('seg')),
                'zs': _list_len(analysis.get('zs')),
                'has_seg_bsp_history_layers': analysis.get('seg_bsp_history_layers') is not None,
            },
            'features': {
                'rows': len(feature_rows),
                'registry': (features.get('meta') or {}).get('feature_registry'),
                'segn_source': (features.get('meta') or {}).get('segn_feature_source'),
            },
            'scores': {
                'rows': len(score_rows),
                'segn_features_supported': (scores.get('meta') or {}).get('segn_features_supported'),
            },
            'backtest': {
                'trades': _list_len(backtest.get('trades'), 'trades'),
                'summary': backtest.get('summary') if isinstance(backtest.get('summary'), dict) else {},
            },
            'pipeline': {
                'features': _list_len(pipeline.get('features'), 'features'),
                'scores': _list_len(pipeline.get('scores'), 'scores'),
                'trades': _list_len((pipeline.get('backtest') or {}).get('trades'), 'trades')
                if isinstance(pipeline.get('backtest'), dict)
                else 0,
                'summary': (pipeline.get('backtest') or {}).get('summary')
                if isinstance(pipeline.get('backtest'), dict)
                else {},
            },
            'seg_composite': {
                'entry_events': _list_len(seg_composite.get('entry_events')),
                'exit_events': _list_len(seg_composite.get('exit_events')),
                'trades': _list_len(seg_composite.get('trades')),
                'summary': seg_composite.get('summary') if isinstance(seg_composite.get('summary'), dict) else {},
                'evaluated_step_frames': (seg_composite.get('meta') or {}).get('evaluated_step_frames')
                if isinstance(seg_composite.get('meta'), dict)
                else None,
            },
            'meta': {
                'validator': 'tools/validate_research_other_target_flow.py',
                'chain': 'health->analyze_multi->features->score->backtest->pipeline->seg_composite',
                'chan_py_polluted': False,
            },
        }
    finally:
        if process is not None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-url', default=DEFAULT_BASE_URL)
    parser.add_argument('--start-backend', action='store_true', help='Start uvicorn on a temporary local port before validating.')
    parser.add_argument('--startup-timeout', type=int, default=45)
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--symbol', default=DEFAULT_SYMBOL)
    parser.add_argument('--market', default=DEFAULT_MARKET)
    parser.add_argument('--level', default=DEFAULT_LEVEL)
    parser.add_argument('--start', default=DEFAULT_START)
    parser.add_argument('--end', default=DEFAULT_END)
    parser.add_argument('--count', type=int, default=50000)
    parser.add_argument('--adjust', default='QFQ')
    parser.add_argument('--horizon', type=int, default=10)
    parser.add_argument('--model', default='logistic_v1')
    parser.add_argument('--fee-rate', type=float, default=0.0005)
    parser.add_argument('--slippage', type=float, default=0.0)
    parser.add_argument('--initial-cash', type=float, default=100000.0)
    parser.add_argument('--bi-algo', default='fx')
    parser.add_argument('--seg-algo', default='chan')
    parser.add_argument('--zs-algo', default='normal')
    parser.add_argument('--recursive-seg-max-level', type=int, default=4)
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        report = validate(args)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    except Exception as exc:  # noqa: BLE001 - command-line validator should report all failures
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))
