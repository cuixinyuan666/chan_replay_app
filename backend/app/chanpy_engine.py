from __future__ import annotations

import csv
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any

from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_symbol


def _project_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _load_exporter() -> Any:
    root = _project_root()
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    from tools.chanpy_compare import chanpy_export

    return chanpy_export


def _chanpy_path() -> str:
    env = os.environ.get('CHANPY_PATH') or os.environ.get('CHAN_PY_PATH')
    if env:
        return env
    bundled = _project_root() / 'python' / 'chan.py'
    if bundled.exists():
        return str(bundled)
    local = _project_root() / 'chan.py'
    if local.exists():
        return str(local)
    return str(_project_root().parent / 'chan.py')


def _bars_to_csv(bars: list[dict[str, Any]], symbol: str) -> Path:
    root = Path(tempfile.gettempdir()) / 'chan_replay_app_origin'
    root.mkdir(parents=True, exist_ok=True)
    path = root / f'{symbol}_input.csv'
    with path.open('w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['time', 'open', 'high', 'low', 'close', 'volume'])
        writer.writeheader()
        for bar in bars:
            open_ = float(bar['open'])
            high = float(bar['high'])
            low = float(bar['low'])
            close = float(bar['close'])
            writer.writerow({
                'time': bar.get('dt') or bar.get('time') or bar.get('date'),
                'open': open_,
                'high': max(open_, high, low, close),
                'low': min(open_, high, low, close),
                'close': close,
                'volume': bar.get('vol') or bar.get('volume') or 0,
            })
    return path


def _run_chanpy_export(*, bars: list[dict[str, Any]], code: str, freq: str, adjust: str) -> dict[str, Any]:
    exporter = _load_exporter()
    chanpy_root = exporter.add_chanpy_path(_chanpy_path())
    CChan, CChanConfig, AUTYPE, DATA_SRC, KL_TYPE = exporter.import_chanpy()
    kl_type = exporter.pick_kl_type(KL_TYPE, freq)
    autype = exporter.pick_autype(AUTYPE, adjust)
    csv_path = _bars_to_csv(bars, code)
    prepared_code = exporter.prepare_chanpy_csv(str(csv_path), chanpy_root, kl_type, f'origin_{code}')
    config = CChanConfig({
        'trigger_step': False,
        'skip_step': 0,
        'seg_algo': 'chan',
        'bi_algo': 'normal',
        'bi_strict': True,
        'zs_algo': 'normal',
        'zs_combine': True,
        'zs_combine_mode': 'zs',
        'one_bi_zs': False,
    })
    chan = exporter.make_cchan(CChan, {
        'code': prepared_code,
        'begin_time': None,
        'end_time': None,
        'data_src': DATA_SRC.CSV,
        'lv_list': [kl_type],
        'config': config,
        'autype': autype,
        'extra_kl': None,
    })
    level = exporter.get_level(chan, kl_type)
    return {
        'fx': exporter.export_fx(level),
        'bi': exporter.export_bi(level),
        'seg': exporter.export_seg(level),
        'zs': exporter.export_zs(level),
    }


def _fallback_result(*, bars: list[dict[str, Any]], symbol: str, market: str, freq: str, adjust: str, mode: str, error: Exception) -> dict[str, Any]:
    return {
        'ok': True,
        'bars': bars,
        'fx': [],
        'bi': [],
        'seg': [],
        'zs': [],
        'bsp': [],
        'meta': {
            'engine': 'chan.py',
            'version': 'external',
            'symbol': f'{symbol}.{market}',
            'name': symbol,
            'freq': freq.upper(),
            'adjust': adjust.upper(),
            'mode': mode,
            'warning': f'chan.py unavailable or failed: {error}',
        },
    }


def analyze_once(*, symbol: str, market: str | None, freq: str, adjust: str, start: str | None, end: str | None, count: int = 5000) -> dict[str, Any]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    bars = load_easy_tdx_bars(symbol=code, market=market_name, period=freq, adjust=adjust, count=count, start=start, end=end)
    try:
        structures = _run_chanpy_export(bars=bars, code=code, freq=freq, adjust=adjust)
    except Exception as exc:
        return _fallback_result(bars=bars, symbol=code, market=market_name, freq=freq, adjust=adjust, mode='once', error=exc)
    return {
        'ok': True,
        'bars': bars,
        'fx': structures['fx'],
        'bi': structures['bi'],
        'seg': structures['seg'],
        'zs': structures['zs'],
        'bsp': [],
        'meta': {
            'engine': 'chan.py',
            'version': 'external',
            'symbol': f'{code}.{market_name}',
            'name': code,
            'freq': freq.upper(),
            'adjust': adjust.upper(),
            'mode': 'once',
        },
    }


def analyze_step(*, symbol: str, market: str | None, freq: str, adjust: str, start: str | None, end: str | None, count: int = 5000) -> dict[str, Any]:
    result = analyze_once(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count)
    result['meta'] = dict(result.get('meta') or {})
    result['meta']['mode'] = 'step'
    result['meta']['step_note'] = 'App playback requests step mode. Runtime strict step should be wired to CChanConfig(trigger_step=True) + CChan.step_load().'
    return result
