from __future__ import annotations

import csv
import os
import re
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


def _safe_code(value: str) -> str:
    text = re.sub(r'[^0-9A-Za-z_]+', '_', value.strip())
    return text.strip('_') or 'local_csv'


def _bars_to_csv(bars: list[dict[str, Any]], symbol: str) -> Path:
    root = Path(tempfile.gettempdir()) / 'chan_replay_app_origin'
    root.mkdir(parents=True, exist_ok=True)
    path = root / f'{_safe_code(symbol)}_input.csv'
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


def _config_dict(*, trigger_step: bool) -> dict[str, Any]:
    return {
        'trigger_step': trigger_step,
        'skip_step': 0,
        'seg_algo': 'chan',
        'bi_algo': 'normal',
        'bi_strict': True,
        'zs_algo': 'normal',
        'zs_combine': True,
        'zs_combine_mode': 'zs',
        'one_bi_zs': False,
    }


def _export_level(exporter: Any, level: Any) -> dict[str, Any]:
    return {
        'fx': exporter.export_fx(level),
        'bi': exporter.export_bi(level),
        'seg': exporter.export_seg(level),
        'zs': exporter.export_zs(level),
    }


def _prepare_chan(*, bars: list[dict[str, Any]], code: str, freq: str, adjust: str, trigger_step: bool) -> tuple[Any, Any, Any]:
    exporter = _load_exporter()
    chanpy_root = exporter.add_chanpy_path(_chanpy_path())
    CChan, CChanConfig, AUTYPE, DATA_SRC, KL_TYPE = exporter.import_chanpy()
    kl_type = exporter.pick_kl_type(KL_TYPE, freq)
    autype = exporter.pick_autype(AUTYPE, adjust)
    csv_path = _bars_to_csv(bars, code)
    prepared_code = exporter.prepare_chanpy_csv(str(csv_path), chanpy_root, kl_type, f'origin_{_safe_code(code)}')
    config = CChanConfig(_config_dict(trigger_step=trigger_step))
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
    return exporter, chan, kl_type


def _run_chanpy_export(*, bars: list[dict[str, Any]], code: str, freq: str, adjust: str) -> dict[str, Any]:
    exporter, chan, kl_type = _prepare_chan(bars=bars, code=code, freq=freq, adjust=adjust, trigger_step=False)
    level = exporter.get_level(chan, kl_type)
    return _export_level(exporter, level)


def _run_chanpy_step_export(*, bars: list[dict[str, Any]], code: str, freq: str, adjust: str) -> dict[str, Any]:
    exporter, chan, kl_type = _prepare_chan(bars=bars, code=code, freq=freq, adjust=adjust, trigger_step=True)
    frames: list[dict[str, Any]] = []
    last_structures: dict[str, Any] = {'fx': [], 'bi': [], 'seg': [], 'zs': []}
    step_iter = getattr(chan, 'step_load', None)
    if not callable(step_iter):
        return {**_run_chanpy_export(bars=bars, code=code, freq=freq, adjust=adjust), 'frames': []}
    for i, cur_chan in enumerate(step_iter()):
        level = exporter.get_level(cur_chan, kl_type)
        structures = _export_level(exporter, level)
        frame_bars = bars[: min(i + 1, len(bars))]
        frames.append({'bars': frame_bars, **structures})
        last_structures = structures
    return {**last_structures, 'frames': frames}


def _fallback_result(*, bars: list[dict[str, Any]], symbol: str, market: str, freq: str, adjust: str, mode: str, error: Exception) -> dict[str, Any]:
    return {
        'ok': True,
        'bars': bars,
        'fx': [],
        'bi': [],
        'seg': [],
        'zs': [],
        'bsp': [],
        'frames': [],
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


def _result(*, bars: list[dict[str, Any]], structures: dict[str, Any], code: str, market: str, freq: str, adjust: str, mode: str) -> dict[str, Any]:
    return {
        'ok': True,
        'bars': bars,
        'fx': structures.get('fx', []),
        'bi': structures.get('bi', []),
        'seg': structures.get('seg', []),
        'zs': structures.get('zs', []),
        'bsp': structures.get('bsp', []),
        'frames': structures.get('frames', []),
        'meta': {
            'engine': 'chan.py',
            'version': 'external',
            'symbol': f'{code}.{market}',
            'name': code,
            'freq': freq.upper(),
            'adjust': adjust.upper(),
            'mode': mode,
        },
    }


def analyze_bars(*, bars: list[dict[str, Any]], symbol: str = 'local_csv', market: str = 'LOCAL', freq: str = 'DAILY', adjust: str = 'QFQ', mode: str = 'once') -> dict[str, Any]:
    code = _safe_code(symbol or 'local_csv')
    market_name = (market or 'LOCAL').upper()
    mode_name = (mode or 'once').lower()
    try:
        structures = _run_chanpy_step_export(bars=bars, code=code, freq=freq, adjust=adjust) if mode_name == 'step' else _run_chanpy_export(bars=bars, code=code, freq=freq, adjust=adjust)
    except Exception as exc:
        return _fallback_result(bars=bars, symbol=code, market=market_name, freq=freq, adjust=adjust, mode=mode_name, error=exc)
    return _result(bars=bars, structures=structures, code=code, market=market_name, freq=freq, adjust=adjust, mode=mode_name)


def analyze_once(*, symbol: str, market: str | None, freq: str, adjust: str, start: str | None, end: str | None, count: int = 5000) -> dict[str, Any]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    bars = load_easy_tdx_bars(symbol=code, market=market_name, period=freq, adjust=adjust, count=count, start=start, end=end)
    return analyze_bars(bars=bars, symbol=code, market=market_name, freq=freq, adjust=adjust, mode='once')


def analyze_step(*, symbol: str, market: str | None, freq: str, adjust: str, start: str | None, end: str | None, count: int = 5000) -> dict[str, Any]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    bars = load_easy_tdx_bars(symbol=code, market=market_name, period=freq, adjust=adjust, count=count, start=start, end=end)
    return analyze_bars(bars=bars, symbol=code, market=market_name, freq=freq, adjust=adjust, mode='step')
