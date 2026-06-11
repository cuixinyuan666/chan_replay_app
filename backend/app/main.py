from __future__ import annotations

import json
from typing import Any

from fastapi import Body, FastAPI, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

from .a_backtest_engine import run_bsp_backtest
from .a_bsp_feature_engine import extract_bsp_features
from .a_bsp_scanner import scan_bsp, scan_bsp_events
from .a_indicator_export import build_display_indicators, indicator_source_meta
from .a_ml_bridge import score_bsp_features
from .a_multilevel_engine import analyze_multi
from .chanpy_engine import analyze_bars, analyze_once, analyze_step
from .easy_tdx_provider import infer_market, load_easy_tdx_bars, normalize_symbol

app = FastAPI(title='Chan Replay origin_vespa_tdx Backend', version='0.6.0')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)

_CONTROL_QUERY_KEYS = {'mode', 'symbol', 'market', 'freq', 'period', 'adjust', 'count', 'start', 'end'}
_BOOL_TRUE = {'1', 'true', 'yes', 'y', 'on'}
_BOOL_FALSE = {'0', 'false', 'no', 'n', 'off'}


def _boolish(value: Any) -> Any:
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    if text in _BOOL_TRUE:
        return True
    if text in _BOOL_FALSE:
        return False
    return value


def _intish(value: Any, default: int, *, minimum: int, maximum: int) -> int:
    try:
        number = int(value)
    except (TypeError, ValueError):
        number = default
    return max(minimum, min(number, maximum))


def _config_from_request(request: Request) -> dict[str, Any]:
    config: dict[str, Any] = {}
    for key, value in request.query_params.items():
        if key in _CONTROL_QUERY_KEYS:
            continue
        text = str(value).strip()
        if not text:
            continue
        config[key] = _boolish(text)
    return config


def _with_display_indicators(result: dict[str, object], config: dict[str, Any] | None) -> dict[str, object]:
    """Attach display-only indicators without changing chan.py structures."""
    bars = result.get('bars')
    if isinstance(bars, list):
        result = dict(result)
        result['indicators'] = build_display_indicators(bars, config)
        meta = dict(result.get('meta')) if isinstance(result.get('meta'), dict) else {}
        sources = dict(meta.get('indicator_sources')) if isinstance(meta.get('indicator_sources'), dict) else {}
        sources.update(indicator_source_meta())
        meta['indicator_sources'] = sources
        result['meta'] = meta
        frames = result.get('frames')
        if isinstance(frames, list):
            patched_frames: list[Any] = []
            for frame in frames:
                if not isinstance(frame, dict):
                    patched_frames.append(frame)
                    continue
                next_frame = dict(frame)
                frame_bars = next_frame.get('bars')
                if isinstance(frame_bars, list):
                    next_frame['indicators'] = build_display_indicators(frame_bars, config)
                patched_frames.append(next_frame)
            result['frames'] = patched_frames
    return result


def _payload_int(payload: dict[str, Any], key: str, default: int, *, minimum: int, maximum: int) -> int:
    return _intish(payload.get(key, default), default, minimum=minimum, maximum=maximum)


def _payload_bool(payload: dict[str, Any], key: str, default: bool) -> bool:
    value = payload.get(key, default)
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in _BOOL_TRUE


def _payload_symbols(value: Any) -> list[Any] | None:
    if isinstance(value, str):
        rows = [part.strip() for part in value.replace('，', ',').split(',') if part.strip()]
        return rows or None
    if isinstance(value, list):
        return value
    return None


def _scanner_args(payload: dict[str, Any] | None) -> dict[str, Any]:
    body = payload or {}
    config = body.get('config') if isinstance(body.get('config'), dict) else {}
    return {
        'limit': _payload_int(body, 'limit', 300, minimum=1, maximum=5000),
        'days': _payload_int(body, 'days', 365, minimum=30, maximum=5000),
        'recent_days': _payload_int(body, 'recent_days', 3, minimum=1, maximum=120),
        'bi_strict': _payload_bool(body, 'bi_strict', True),
        'symbols': _payload_symbols(body.get('symbols')),
        'config': config,
    }


def _analysis_from_payload(payload: dict[str, Any]) -> dict[str, Any]:
    analysis = payload.get('analysis')
    return analysis if isinstance(analysis, dict) else payload


@app.get('/health')
def health() -> dict[str, object]:
    return {
        'ok': True,
        'backend': 'origin_vespa_tdx',
        'data_source': 'easy-tdx',
        'engine': 'chan.py',
        'version': '0.6.0',
        'research_api': True,
    }


@app.get('/')
def root() -> dict[str, object]:
    return {
        'ok': True,
        'backend': 'origin_vespa_tdx',
        'version': '0.6.0',
        'note': 'Python chan.py is the only Chan calculation source. Flutter only renders JSON results.',
        'endpoints': [
            '/health',
            '/api/tdx/kline',
            '/api/chan/analyze',
            '/api/chan/analyze_bars',
            '/api/chan/analyze_multi',
            '/api/research/bsp/features',
            '/api/research/ml/score',
            '/api/research/backtest',
            '/api/research/pipeline',
            '/api/scanner/bsp/scan',
            '/api/scanner/bsp/scan_stream',
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
    count: int = Query(50000, ge=10),
    start: str | None = Query(None, description='yyyy-MM-dd，可选'),
    end: str | None = Query(None, description='yyyy-MM-dd，可选'),
) -> dict[str, object]:
    config = _config_from_request(request)
    if mode.lower() == 'step':
        result = analyze_step(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count, config=config)
    else:
        result = analyze_once(symbol=symbol, market=market, freq=freq, adjust=adjust, start=start, end=end, count=count, config=config)
    return _with_display_indicators(result, config)


@app.post('/api/chan/analyze_bars')
def chan_analyze_bars(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    bars = payload.get('bars') or []
    if not isinstance(bars, list):
        empty = {'ok': False, 'error': 'bars 必须是数组', 'bars': [], 'merged_bars': [], 'fx': [], 'bi': [], 'seg': [], 'zs': [], 'bsp': [], 'frames': []}
        return _with_display_indicators(empty, {})
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
    return _with_display_indicators(result, config)


@app.post('/api/chan/analyze_multi')
def chan_analyze_multi(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    config = payload.get('config') if isinstance(payload.get('config'), dict) else {}
    levels = payload.get('lv_list') or payload.get('levels') or payload.get('level_order')
    return analyze_multi(
        symbol=str(payload.get('symbol') or '000001'),
        market=payload.get('market'),
        levels=levels,
        adjust=str(payload.get('adjust') or 'QFQ'),
        mode=str(payload.get('mode') or 'once'),
        main_level=payload.get('main_level') or payload.get('mainLevel'),
        clock_level=payload.get('clock_level') or payload.get('clockLevel'),
        start=payload.get('start'),
        end=payload.get('end'),
        count=_payload_int(payload, 'count', 50000, minimum=10, maximum=200000),
        config=config,
    )


@app.post('/api/research/bsp/features')
def research_bsp_features(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    analysis = _analysis_from_payload(payload)
    return extract_bsp_features(
        analysis,
        label_horizon=_payload_int(payload, 'label_horizon', 5, minimum=1, maximum=250),
        include_labels=_payload_bool(payload, 'include_labels', True),
    )


@app.post('/api/research/ml/score')
def research_ml_score(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    raw_features = payload.get('features')
    if not isinstance(raw_features, list):
        analysis = _analysis_from_payload(payload)
        raw_features = extract_bsp_features(
            analysis,
            label_horizon=_payload_int(payload, 'label_horizon', 5, minimum=1, maximum=250),
            include_labels=_payload_bool(payload, 'include_labels', False),
        )['features']
    model = payload.get('model') if isinstance(payload.get('model'), dict) else None
    return score_bsp_features([row for row in raw_features if isinstance(row, dict)], model=model)


@app.post('/api/research/backtest')
def research_backtest(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    analysis = _analysis_from_payload(payload)
    if isinstance(payload.get('scores'), list):
        analysis = {**analysis, 'scores': payload['scores']}
    elif isinstance(payload.get('features'), list):
        analysis = {**analysis, 'features': payload['features']}
    options = payload.get('options') if isinstance(payload.get('options'), dict) else {}
    return run_bsp_backtest(analysis, options=options)


@app.post('/api/research/pipeline')
def research_pipeline(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    analysis = _analysis_from_payload(payload)
    feature_result = extract_bsp_features(
        analysis,
        label_horizon=_payload_int(payload, 'label_horizon', 5, minimum=1, maximum=250),
        include_labels=_payload_bool(payload, 'include_labels', True),
    )
    model = payload.get('model') if isinstance(payload.get('model'), dict) else None
    score_result = score_bsp_features(feature_result['features'], model=model)
    options = payload.get('options') if isinstance(payload.get('options'), dict) else {}
    backtest_result = run_bsp_backtest({**analysis, 'scores': score_result['scores']}, options=options)
    return {
        'ok': True,
        'features': feature_result['features'],
        'scores': score_result['scores'],
        'backtest': backtest_result,
        'meta': {
            'source': 'origin_vespa_tdx.backend.research_pipeline',
            'chan_py_polluted': False,
        },
    }


@app.post('/api/scanner/bsp/scan')
def scanner_bsp_scan(payload: dict[str, Any] | None = Body(default=None)) -> dict[str, object]:
    return scan_bsp(**_scanner_args(payload))


@app.post('/api/scanner/bsp/scan_stream')
def scanner_bsp_scan_stream(payload: dict[str, Any] | None = Body(default=None)) -> StreamingResponse:
    args = _scanner_args(payload)

    def events():
        for event in scan_bsp_events(**args):
            yield f'data: {json.dumps(event, ensure_ascii=False)}\n\n'

    return StreamingResponse(events(), media_type='text/event-stream')


@app.get('/api/tdx/kline')
def tdx_kline(
    symbol: str = Query('000001'),
    market: str | None = Query(None),
    period: str = Query('DAILY'),
    adjust: str = Query('QFQ'),
    count: int = Query(50000, ge=10),
    start: str | None = Query(None),
    end: str | None = Query(None),
) -> dict[str, object]:
    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    bars = load_easy_tdx_bars(symbol=code, market=market_name, period=period, adjust=adjust, count=count, start=start, end=end)
    return {
        'ok': True,
        'symbol': f'{code}.{market_name}',
        'bars': bars,
    }
