from __future__ import annotations

from typing import Any

from fastapi import Body, FastAPI, Query, Request
from fastapi.middleware.cors import CORSMiddleware

from .a_bsp_scanner import scan_bsp
from .a_easy_tdx_indicators import build_easy_tdx_indicators, easy_tdx_indicator_meta
from .chanpy_engine import analyze_bars, analyze_once, analyze_step
from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_symbol

app = FastAPI(title='Chan Replay origin_vespa_tdx Backend', version='0.5.1')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

_BSP_ADVANCED_QUERY_KEYS = {
    'divergence_rate',
    'min_zs_cnt',
    'bsp1_only_multibi_zs',
    'max_bs2_rate',
    'macd_algo',
    'bs1_peak',
    'bs_type',
    'bsp2_follow_1',
    'bsp3_follow_1',
    'bsp3_peak',
    'bsp2s_follow_2',
    'max_bsp2s_lv',
    'strict_bsp3',
    'bsp3a_max_zs_cnt',
}
_BSP_ADVANCED_QUERY_SUFFIXES = {'buy', 'sell', 'segbuy', 'segsell', 'seg'}


def _bsp_advanced_config_from_query(request: Request) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in request.query_params.items():
        if '-' not in key:
            continue
        name, suffix = key.rsplit('-', 1)
        if name in _BSP_ADVANCED_QUERY_KEYS and suffix in _BSP_ADVANCED_QUERY_SUFFIXES:
            if str(value).strip():
                result[key] = value
    return result


def _config_from_query(
    *,
    skip_step: int,
    bi_algo: str,
    bi_strict: bool,
    bi_fx_check: str,
    gap_as_kl: bool,
    bi_end_is_peak: bool,
    bi_allow_sub_peak: bool,
    seg_algo: str,
    left_seg_method: str,
    zs_algo: str,
    zs_combine: bool,
    zs_combine_mode: str,
    one_bi_zs: bool,
    kl_data_check: bool,
    max_kl_misalgin_cnt: int,
    max_kl_inconsistent_cnt: int,
    auto_skip_illegal_sub_lv: bool,
    print_warning: bool,
    print_err_time: bool,
    mean_metrics: str,
    trend_metrics: str,
    macd_fast: int,
    macd_slow: int,
    macd_signal: int,
    cal_demark: bool,
    cal_rsi: bool,
    cal_kdj: bool,
    rsi_cycle: int,
    kdj_cycle: int,
    demark_len: int,
    demark_setup_bias: int,
    demark_countdown_bias: int,
    demark_max_countdown: int,
    demark_tiaokong_st: bool,
    demark_setup_cmp2close: bool,
    demark_countdown_cmp2close: bool,
    boll_n: int,
    bs_type: str,
    divergence_rate: float,
    min_zs_cnt: int,
    bsp1_only_multibi_zs: bool,
    max_bs2_rate: float,
    bs1_peak: bool,
    bsp2_follow_1: bool,
    bsp3_follow_1: bool,
    bsp3_peak: bool,
    bsp2s_follow_2: bool,
    max_bsp2s_lv: str | None,
    strict_bsp3: bool,
    bsp3a_max_zs_cnt: int,
    macd_algo: str,
) -> dict[str, Any]:
    return {
        'skip_step': skip_step,
        'bi_algo': bi_algo,
        'bi_strict': bi_strict,
        'bi_fx_check': bi_fx_check,
        'gap_as_kl': gap_as_kl,
        'bi_end_is_peak': bi_end_is_peak,
        'bi_allow_sub_peak': bi_allow_sub_peak,
        'seg_algo': seg_algo,
        'left_seg_method': left_seg_method,
        'zs_algo': zs_algo,
        'zs_combine': zs_combine,
        'zs_combine_mode': zs_combine_mode,
        'one_bi_zs': one_bi_zs,
        'kl_data_check': kl_data_check,
        'max_kl_misalgin_cnt': max_kl_misalgin_cnt,
        'max_kl_inconsistent_cnt': max_kl_inconsistent_cnt,
        'auto_skip_illegal_sub_lv': auto_skip_illegal_sub_lv,
        'print_warning': print_warning,
        'print_err_time': print_err_time,
        'mean_metrics': mean_metrics,
        'trend_metrics': trend_metrics,
        'macd_fast': macd_fast,
        'macd_slow': macd_slow,
        'macd_signal': macd_signal,
        'cal_demark': cal_demark,
        'cal_rsi': cal_rsi,
        'cal_kdj': cal_kdj,
        'rsi_cycle': rsi_cycle,
        'kdj_cycle': kdj_cycle,
        'demark_len': demark_len,
        'demark_setup_bias': demark_setup_bias,
        'demark_countdown_bias': demark_countdown_bias,
        'demark_max_countdown': demark_max_countdown,
        'demark_tiaokong_st': demark_tiaokong_st,
        'demark_setup_cmp2close': demark_setup_cmp2close,
        'demark_countdown_cmp2close': demark_countdown_cmp2close,
        'boll_n': boll_n,
        'bs_type': bs_type,
        'divergence_rate': divergence_rate,
        'min_zs_cnt': min_zs_cnt,
        'bsp1_only_multibi_zs': bsp1_only_multibi_zs,
        'max_bs2_rate': max_bs2_rate,
        'bs1_peak': bs1_peak,
        'bsp2_follow_1': bsp2_follow_1,
        'bsp3_follow_1': bsp3_follow_1,
        'bsp3_peak': bsp3_peak,
        'bsp2s_follow_2': bsp2s_follow_2,
        'max_bsp2s_lv': max_bsp2s_lv,
        'strict_bsp3': strict_bsp3,
        'bsp3a_max_zs_cnt': bsp3a_max_zs_cnt,
        'macd_algo': macd_algo,
    }


def _payload_int(payload: dict[str, Any], key: str, default: int, *, minimum: int, maximum: int) -> int:
    try:
        value = int(payload.get(key, default))
    except (TypeError, ValueError):
        value = default
    return max(minimum, min(value, maximum))


def _payload_bool(payload: dict[str, Any], key: str, default: bool) -> bool:
    value = payload.get(key, default)
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {'1', 'true', 'yes', 'y', 'on'}


def _payload_symbols(value: Any) -> list[Any] | None:
    if isinstance(value, str):
        rows = [part.strip() for part in value.replace('，', ',').split(',') if part.strip()]
        return rows or None
    if isinstance(value, list):
        return value
    return None


def _config_int(config: dict[str, Any], key: str, default: int) -> int:
    try:
        return int(config.get(key) or default)
    except (TypeError, ValueError):
        return default


def _merge_indicator_meta(result: dict[str, Any]) -> None:
    patch = easy_tdx_indicator_meta()
    meta = result.get('meta')
    if not isinstance(meta, dict):
        result['meta'] = patch
        return
    indicator_sources = patch.get('indicator_sources')
    if isinstance(indicator_sources, dict):
        meta['indicator_sources'] = indicator_sources
    if 'indicator_warning' in patch:
        meta['indicator_warning'] = patch['indicator_warning']


def _append_warning(result: dict[str, Any], warning: str) -> None:
    meta = result.setdefault('meta', {})
    if not isinstance(meta, dict):
        result['meta'] = {'warnings': [warning]}
        return
    warnings = meta.setdefault('warnings', [])
    if isinstance(warnings, list):
        warnings.append(warning)
    else:
        meta['warnings'] = [warning]


def _with_easy_tdx_indicators(result: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    bars = result.get('bars')
    if not isinstance(bars, list):
        result.setdefault('indicators', {})
        return result
    rows = [row for row in bars if isinstance(row, dict)]
    cfg = config or {}
    try:
        result['indicators'] = build_easy_tdx_indicators(
            rows,
            boll_window=_config_int(cfg, 'boll_n', 20),
            macd_fast=_config_int(cfg, 'macd_fast', 12),
            macd_slow=_config_int(cfg, 'macd_slow', 26),
            macd_signal=_config_int(cfg, 'macd_signal', 9),
        )
        _merge_indicator_meta(result)
    except Exception as exc:  # pragma: no cover - defensive display fallback
        result['indicators'] = {}
        _append_warning(result, f'easy-tdx indicator build failed: {exc}')
    return result


@app.get('/health')
def health() -> dict[str, object]:
    return {
        'ok': True,
        'backend': 'origin_vespa_tdx',
        'data_source': 'easy-tdx',
        'engine': 'chan.py',
        'version': '0.5.1',
    }


@app.get('/')
def root() -> dict[str, object]:
    return {
        'ok': True,
        'backend': 'origin_vespa_tdx',
        'version': '0.5.1',
        'note': 'Python chan.py is the only Chan calculation source. Flutter only renders JSON results.',
        'endpoints': [
            '/health',
            '/api/tdx/kline',
            '/api/chan/analyze',
            '/api/chan/analyze_bars',
            '/api/scanner/bsp/scan',
            '/docs',
        ],
    }


@app.get('/api/chan/analyze')
def chan_analyze(
    request: Request,
    mode: str = Query('once', description='once / step'),
    symbol: str = Query('000001', description='股票代码，支持 000001 或 000001.SZ'),
    market: str | None = Query(None, description='SZ / SH；留空时按代码自动推断'),
    freq: str = Query('DAILY', description='MIN1/MIN5/MIN15/MIN30/MIN60/DAILY/WEEKLY/MONTHLY'),
    adjust: str = Query('QFQ', description='QFQ/HFQ/NONE'),
    count: int = Query(5000, ge=10, le=5000),
    start: str | None = Query(None, description='yyyy-MM-dd，可选'),
    end: str | None = Query(None, description='yyyy-MM-dd，可选'),
    skip_step: int = Query(0, ge=0, description='CChanConfig.skip_step'),
    bi_algo: str = Query('normal', description='CBiConfig.bi_algo: normal / fx'),
    bi_strict: bool = Query(True, description='CBiConfig.bi_strict'),
    bi_fx_check: str = Query('strict', description='CBiConfig.bi_fx_check: strict/loss/half/totally'),
    gap_as_kl: bool = Query(False, description='CBiConfig.gap_as_kl'),
    bi_end_is_peak: bool = Query(True, description='CBiConfig.bi_end_is_peak'),
    bi_allow_sub_peak: bool = Query(True, description='CBiConfig.bi_allow_sub_peak'),
    seg_algo: str = Query('chan', description='CSegConfig.seg_algo: chan/1+1/break'),
    left_seg_method: str = Query('peak', description='CSegConfig.left_seg_method: peak/all'),
    zs_algo: str = Query('normal', description='CZSConfig.zs_algo'),
    zs_combine: bool = Query(True, description='CZSConfig.zs_combine'),
    zs_combine_mode: str = Query('zs', description='CZSConfig.zs_combine_mode: zs/peak'),
    one_bi_zs: bool = Query(False, description='CZSConfig.one_bi_zs'),
    kl_data_check: bool = Query(True, description='CChanConfig.kl_data_check'),
    max_kl_misalgin_cnt: int = Query(2, ge=0, description='CChanConfig.max_kl_misalgin_cnt'),
    max_kl_inconsistent_cnt: int = Query(5, ge=0, description='CChanConfig.max_kl_inconsistent_cnt'),
    auto_skip_illegal_sub_lv: bool = Query(False, description='CChanConfig.auto_skip_illegal_sub_lv'),
    print_warning: bool = Query(True, description='CChanConfig.print_warning'),
    print_err_time: bool = Query(True, description='CChanConfig.print_err_time'),
    mean_metrics: str = Query('', description='CChanConfig.mean_metrics，逗号分隔整数'),
    trend_metrics: str = Query('', description='CChanConfig.trend_metrics，逗号分隔整数'),
    macd_fast: int = Query(12, ge=1, description='CChanConfig.macd.fast'),
    macd_slow: int = Query(26, ge=1, description='CChanConfig.macd.slow'),
    macd_signal: int = Query(9, ge=1, description='CChanConfig.macd.signal'),
    cal_demark: bool = Query(False, description='CChanConfig.cal_demark'),
    cal_rsi: bool = Query(False, description='CChanConfig.cal_rsi'),
    cal_kdj: bool = Query(False, description='CChanConfig.cal_kdj'),
    rsi_cycle: int = Query(14, ge=1, description='CChanConfig.rsi_cycle'),
    kdj_cycle: int = Query(9, ge=1, description='CChanConfig.kdj_cycle'),
    demark_len: int = Query(9, ge=1, description='CChanConfig.demark.demark_len'),
    demark_setup_bias: int = Query(4, ge=1, description='CChanConfig.demark.setup_bias'),
    demark_countdown_bias: int = Query(2, ge=1, description='CChanConfig.demark.countdown_bias'),
    demark_max_countdown: int = Query(13, ge=1, description='CChanConfig.demark.max_countdown'),
    demark_tiaokong_st: bool = Query(True, description='CChanConfig.demark.tiaokong_st'),
    demark_setup_cmp2close: bool = Query(True, description='CChanConfig.demark.setup_cmp2close'),
    demark_countdown_cmp2close: bool = Query(True, description='CChanConfig.demark.countdown_cmp2close'),
    boll_n: int = Query(20, ge=1, description='CChanConfig.boll_n'),
    bs_type: str = Query('1,1p,2,2s,3a,3b', description='CBSPointConfig.bs_type'),
    divergence_rate: float = Query(1.0e18, description='CBSPointConfig.divergence_rate'),
    min_zs_cnt: int = Query(1, ge=0, description='CBSPointConfig.min_zs_cnt'),
    bsp1_only_multibi_zs: bool = Query(True, description='CBSPointConfig.bsp1_only_multibi_zs'),
    max_bs2_rate: float = Query(0.9999, description='CBSPointConfig.max_bs2_rate'),
    bs1_peak: bool = Query(True, description='CBSPointConfig.bs1_peak'),
    bsp2_follow_1: bool = Query(True, description='CBSPointConfig.bsp2_follow_1'),
    bsp3_follow_1: bool = Query(True, description='CBSPointConfig.bsp3_follow_1'),
    bsp3_peak: bool = Query(False, description='CBSPointConfig.bsp3_peak'),
    bsp2s_follow_2: bool = Query(False, description='CBSPointConfig.bsp2s_follow_2'),
    max_bsp2s_lv: str | None = Query(None, description='CBSPointConfig.max_bsp2s_lv，空为 None'),
    strict_bsp3: bool = Query(False, description='CBSPointConfig.strict_bsp3'),
    bsp3a_max_zs_cnt: int = Query(1, ge=1, description='CBSPointConfig.bsp3a_max_zs_cnt'),
    macd_algo: str = Query('peak', description='CBSPointConfig.macd_algo'),
) -> dict[str, object]:
    config = _config_from_query(
        skip_step=skip_step,
        bi_algo=bi_algo,
        bi_strict=bi_strict,
        bi_fx_check=bi_fx_check,
        gap_as_kl=gap_as_kl,
        bi_end_is_peak=bi_end_is_peak,
        bi_allow_sub_peak=bi_allow_sub_peak,
        seg_algo=seg_algo,
        left_seg_method=left_seg_method,
        zs_algo=zs_algo,
        zs_combine=zs_combine,
        zs_combine_mode=zs_combine_mode,
        one_bi_zs=one_bi_zs,
        kl_data_check=kl_data_check,
        max_kl_misalgin_cnt=max_kl_misalgin_cnt,
        max_kl_inconsistent_cnt=max_kl_inconsistent_cnt,
        auto_skip_illegal_sub_lv=auto_skip_illegal_sub_lv,
        print_warning=print_warning,
        print_err_time=print_err_time,
        mean_metrics=mean_metrics,
        trend_metrics=trend_metrics,
        macd_fast=macd_fast,
        macd_slow=macd_slow,
        macd_signal=macd_signal,
        cal_demark=cal_demark,
        cal_rsi=cal_rsi,
        cal_kdj=cal_kdj,
        rsi_cycle=rsi_cycle,
        kdj_cycle=kdj_cycle,
        demark_len=demark_len,
        demark_setup_bias=demark_setup_bias,
        demark_countdown_bias=demark_countdown_bias,
        demark_max_countdown=demark_max_countdown,
        demark_tiaokong_st=demark_tiaokong_st,
        demark_setup_cmp2close=demark_setup_cmp2close,
        demark_countdown_cmp2close=demark_countdown_cmp2close,
        boll_n=boll_n,
        bs_type=bs_type,
        divergence_rate=divergence_rate,
        min_zs_cnt=min_zs_cnt,
        bsp1_only_multibi_zs=bsp1_only_multibi_zs,
        max_bs2_rate=max_bs2_rate,
        bs1_peak=bs1_peak,
        bsp2_follow_1=bsp2_follow_1,
        bsp3_follow_1=bsp3_follow_1,
        bsp3_peak=bsp3_peak,
        bsp2s_follow_2=bsp2s_follow_2,
        max_bsp2s_lv=max_bsp2s_lv,
        strict_bsp3=strict_bsp3,
        bsp3a_max_zs_cnt=bsp3a_max_zs_cnt,
        macd_algo=macd_algo,
    )
    config.update(_bsp_advanced_config_from_query(request))
    if mode.lower() == 'step':
        result = analyze_step(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count, config=config)
    else:
        result = analyze_once(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count, config=config)
    return _with_easy_tdx_indicators(result, config)


@app.post('/api/chan/analyze_bars')
def chan_analyze_bars(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    bars = payload.get('bars') or []
    if not isinstance(bars, list):
        return {
            'ok': False,
            'error': 'bars 必须是数组',
            'bars': [],
            'merged_bars': [],
            'fx': [],
            'bi': [],
            'seg': [],
            'zs': [],
            'bsp': [],
            'indicators': {},
            'frames': [],
        }
    config = payload.get('config') if isinstance(payload.get('config'), dict) else {}
    result = analyze_bars(
        bars=bars,
        symbol=str(payload.get('symbol') or 'local_csv'),
        market=str(payload.get('market') or 'LOCAL'),
        freq=str(payload.get('freq') or payload.get('period') or 'DAILY'),
        adjust=str(payload.get('adjust') or 'QFQ'),
        mode=str(payload.get('mode') or 'once'),
        config=config,
    )
    return _with_easy_tdx_indicators(result, config)


@app.post('/api/scanner/bsp/scan')
def scanner_bsp_scan(payload: dict[str, Any] | None = Body(None)) -> dict[str, object]:
    body = payload or {}
    config = body.get('config') if isinstance(body.get('config'), dict) else {}
    return scan_bsp(
        limit=_payload_int(body, 'limit', 300, minimum=1, maximum=5000),
        days=_payload_int(body, 'days', 365, minimum=30, maximum=5000),
        recent_days=_payload_int(body, 'recent_days', 3, minimum=1, maximum=120),
        bi_strict=_payload_bool(body, 'bi_strict', True),
        symbols=_payload_symbols(body.get('symbols')),
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
    result: dict[str, Any] = {
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
    return _with_easy_tdx_indicators(result, {'boll_n': 20, 'macd_fast': 12, 'macd_slow': 26, 'macd_signal': 9})
