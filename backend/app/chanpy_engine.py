from __future__ import annotations

from typing import Any

from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_symbol


def _empty_chan_result(*, bars: list[dict[str, Any]], symbol: str, market: str, freq: str, adjust: str, mode: str) -> dict[str, Any]:
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
            'note': 'origin_vespa_tdx uses Python chan.py as the only calculation source; this adapter defines the stable JSON contract.',
        },
    }


def analyze_once(*, symbol: str, market: str | None, freq: str, adjust: str, start: str | None, end: str | None, count: int = 5000) -> dict[str, Any]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    bars = load_easy_tdx_bars(symbol=code, market=market_name, period=freq, adjust=adjust, count=count, start=start, end=end)
    return _empty_chan_result(bars=bars, symbol=code, market=market_name, freq=freq, adjust=adjust, mode='once')


def analyze_step(*, symbol: str, market: str | None, freq: str, adjust: str, start: str | None, end: str | None, count: int = 5000) -> dict[str, Any]:
    result = analyze_once(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count)
    result['meta']['mode'] = 'step'
    result['meta']['step_note'] = 'strict step mode will be backed by CChanConfig(trigger_step=True) + CChan.step_load().'
    return result
