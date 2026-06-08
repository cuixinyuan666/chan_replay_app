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


def _config_from_query(
    *,
    bi_algo: str,
    bi_strict: bool,
    seg_algo: str,
    zs_algo: str,
    zs_combine: bool,
    zs_combine_mode: str,
    one_bi_zs: bool,
    bs_type: str,
    divergence_rate: float,
    min_zs_cnt: int,
    max_bs2_rate: float,
    bs1_peak: bool,
    bsp2_follow_1: bool,
    bsp3_follow_1: bool,
    bsp3_peak: bool,
    bsp2s_follow_2: bool,
    strict_bsp3: bool,
    bsp3a_max_zs_cnt: int,
    macd_algo: str,
) -> dict[str, Any]:
    return {
        'bi_algo': bi_algo,
        'bi_strict': bi_strict,
        'seg_algo': seg_algo,
        'zs_algo': zs_algo,
        'zs_combine': zs_combine,
        'zs_combine_mode': zs_combine_mode,
        'one_bi_zs': one_bi_zs,
        'bs_type': bs_type,
        'divergence_rate': divergence_rate,
        'min_zs_cnt': min_zs_cnt,
        'max_bs2_rate': max_bs2_rate,
        'bs1_peak': bs1_peak,
        'bsp2_follow_1': bsp2_follow_1,
        'bsp3_follow_1': bsp3_follow_1,
        'bsp3_peak': bsp3_peak,
        'bsp2s_follow_2': bsp2s_follow_2,
        'strict_bsp3': strict_bsp3,
        'bsp3a_max_zs_cnt': bsp3a_max_zs_cnt,
        'macd_algo': macd_algo,
    }


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
    bi_algo: str = Query('normal', description='CChanConfig.bi_algo'),
    bi_strict: bool = Query(True, description='CChanConfig.bi_strict'),
    seg_algo: str = Query('chan', description='CChanConfig.seg_algo'),
    zs_algo: str = Query('normal', description='CChanConfig.zs_algo'),
    zs_combine: bool = Query(True, description='CChanConfig.zs_combine'),
    zs_combine_mode: str = Query('zs', description='CChanConfig.zs_combine_mode'),
    one_bi_zs: bool = Query(False, description='CChanConfig.one_bi_zs'),
    bs_type: str = Query('1,1p,2,2s,3a,3b', description='CChanConfig.bs_type'),
    divergence_rate: float = Query(1.0e18, description='CChanConfig.divergence_rate'),
    min_zs_cnt: int = Query(1, ge=0, description='CChanConfig.min_zs_cnt'),
    max_bs2_rate: float = Query(0.9999, description='CChanConfig.max_bs2_rate'),
    bs1_peak: bool = Query(True, description='CChanConfig.bs1_peak'),
    bsp2_follow_1: bool = Query(True, description='CChanConfig.bsp2_follow_1'),
    bsp3_follow_1: bool = Query(True, description='CChanConfig.bsp3_follow_1'),
    bsp3_peak: bool = Query(False, description='CChanConfig.bsp3_peak'),
    bsp2s_follow_2: bool = Query(False, description='CChanConfig.bsp2s_follow_2'),
    strict_bsp3: bool = Query(False, description='CChanConfig.strict_bsp3'),
    bsp3a_max_zs_cnt: int = Query(1, ge=0, description='CChanConfig.bsp3a_max_zs_cnt'),
    macd_algo: str = Query('peak', description='CChanConfig.macd_algo'),
) -> dict[str, object]:
    config = _config_from_query(
        bi_algo=bi_algo,
        bi_strict=bi_strict,
        seg_algo=seg_algo,
        zs_algo=zs_algo,
        zs_combine=zs_combine,
        zs_combine_mode=zs_combine_mode,
        one_bi_zs=one_bi_zs,
        bs_type=bs_type,
        divergence_rate=divergence_rate,
        min_zs_cnt=min_zs_cnt,
        max_bs2_rate=max_bs2_rate,
        bs1_peak=bs1_peak,
        bsp2_follow_1=bsp2_follow_1,
        bsp3_follow_1=bsp3_follow_1,
        bsp3_peak=bsp3_peak,
        bsp2s_follow_2=bsp2s_follow_2,
        strict_bsp3=strict_bsp3,
        bsp3a_max_zs_cnt=bsp3a_max_zs_cnt,
        macd_algo=macd_algo,
    )
    if mode.lower() == 'step':
        return analyze_step(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count, config=config)
    return analyze_once(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count, config=config)


@app.post('/api/chan/analyze_bars')
def chan_analyze_bars(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    bars = payload.get('bars') or []
    if not isinstance(bars, list):
        return {'ok': False, 'error': 'bars 必须是数组', 'bars': [], 'merged_bars': [], 'fx': [], 'bi': [], 'seg': [], 'zs': [], 'bsp': [], 'frames': []}
    config = payload.get('config') if isinstance(payload.get('config'), dict) else {}
    return analyze_bars(
        bars=bars,
        symbol=str(payload.get('symbol') or 'local_csv'),
        market=str(payload.get('market') or 'LOCAL'),
        freq=str(payload.get('freq') or payload.get('period') or 'DAILY'),
        adjust=str(payload.get('adjust') or 'QFQ'),
        mode=str(payload.get('mode') or 'once'),
        config=config,
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
