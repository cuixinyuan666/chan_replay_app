from __future__ import annotations

from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware

from .czsc_adapter import analyze_with_czsc
from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_symbol

app = FastAPI(title='Chan Replay CZSC easy-tdx Backend', version='0.1.0')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)


@app.get('/health')
def health() -> dict[str, object]:
    return {'ok': True, 'backend': 'czsc_easy_tdx', 'version': '0.1.0'}


@app.get('/api/czsc/analyze')
def analyze(
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
    bars = load_easy_tdx_bars(
        symbol=code,
        market=market_name,
        period=freq,
        adjust=adjust,
        count=count,
        start=start,
        end=end,
    )
    payload = analyze_with_czsc(
        bars=bars,
        symbol=f'{code}.{market_name}',
        freq=freq,
    )
    payload['source'] = {
        'name': 'easy-tdx',
        'symbol': f'{code}.{market_name}',
        'freq': freq,
        'adjust': adjust,
        'count': len(bars),
        'start': start,
        'end': end,
    }
    return payload
