from __future__ import annotations

from typing import Any

from fastapi import Body, FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

from .chanpy_engine import analyze_bars, analyze_once, analyze_step
from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_symbol

app = FastAPI(title='Chan Replay origin_vespa_tdx Backend', version='0.4.0')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)


@app.get('/health')
def health() -> dict[str, object]:
    return {
        'ok': True,
        'backend': 'origin_vespa_tdx',
        'data_source': 'easy-tdx',
        'engine': 'chan.py',
        'version': '0.4.0',
    }


@app.get('/')
def root() -> dict[str, object]:
    return {
        'ok': True,
        'backend': 'origin_vespa_tdx',
        'version': '0.4.0',
        'note': 'Python chan.py is the only Chan calculation source. Flutter only renders JSON results.',
        'endpoints': [
            '/health',
            '/api/tdx/kline',
            '/api/chan/analyze',
            '/api/chan/analyze_bars',
            '/docs',
        ],
    }


@app.get('/api/chan/analyze')
def chan_analyze(
    mode: str = Query('once', description='once / step'),
    symbol: str = Query('000001', description='股票代码，支持 000001 或 000001.SZ'),
    market: str | None = Query(None, description='SZ / SH；留空时按代码自动推断'),
    freq: str = Query('DAILY', description='MIN1/MIN5/MIN15/MIN30/MIN60/DAILY/WEEKLY/MONTHLY'),
    adjust: str = Query('QFQ', description='QFQ/HFQ/NONE'),
    count: int = Query(5000, ge=10, le=5000),
    start: str | None = Query(None, description='yyyy-MM-dd，可选'),
    end: str | None = Query(None, description='yyyy-MM-dd，可选'),
) -> dict[str, object]:
    if mode.lower() == 'step':
        return analyze_step(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count)
    return analyze_once(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count)


@app.post('/api/chan/analyze_bars')
def chan_analyze_bars(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    bars = payload.get('bars') or []
    if not isinstance(bars, list):
        return {'ok': False, 'error': 'bars 必须是数组', 'bars': [], 'fx': [], 'bi': [], 'seg': [], 'zs': [], 'bsp': [], 'frames': []}
    return analyze_bars(
        bars=bars,
        symbol=str(payload.get('symbol') or 'local_csv'),
        market=str(payload.get('market') or 'LOCAL'),
        freq=str(payload.get('freq') or payload.get('period') or 'DAILY'),
        adjust=str(payload.get('adjust') or 'QFQ'),
        mode=str(payload.get('mode') or 'once'),
    )


@app.get('/api/tdx/kline')
def kline(
    symbol: str = Query('000001', description='股票代码，支持 000001 或 000001.SZ'),
    market: str | None = Query(None, description='SZ / SH；留空时按代码自动推断'),
    freq: str = Query('DAILY', description='MIN1/MIN5/MIN15/MIN30/MIN60/DAILY/WEEKLY/MONTHLY'),
    adjust: str = Query('QFQ', description='QFQ/HFQ/NONE'),
    count: int = Query(800, ge=10, le=5000),
    start: str | None = Query(None, description='yyyy-MM-dd，可选'),
    end: str | None = Query(None, description='yyyy-MM-dd，可选'),
) -> dict[str, object]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    freq_name = freq.upper()
    adjust_name = adjust.upper()
    bars = load_easy_tdx_bars(
        symbol=code,
        market=market_name,
        period=freq_name,
        adjust=adjust_name,
        count=count,
        start=start,
        end=end,
    )
    return {
        'ok': True,
        'engine': 'chan.py',
        'source': {
            'name': 'easy-tdx',
            'symbol': f'{code}.{market_name}',
            'freq': freq_name,
            'adjust': adjust_name,
            'count': len(bars),
            'start': start,
            'end': end,
        },
        'bars': bars,
    }
