from __future__ import annotations

import json
from time import perf_counter
from typing import Any

from fastapi import Body, FastAPI, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

from .a_backtest_engine import run_bsp_backtest
from .a_bsp_feature_engine import extract_bsp_features
from .a_bsp_scanner import scan_bsp, scan_bsp_events
from .a_indicator_export import build_display_indicators, indicator_source_meta
from .a_ml_bridge import score_bsp_features
from .a_multilevel_engine_timed import analyze_multi
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
_COMPACT_STRUCTURE_KEYS = ('merged_bars', 'fx', 'bi', 'seg', 'zs', 'bsp')


def _elapsed_ms(start: float) -> int:
    return int((perf_counter() - start) * 1000)


def _merge_meta(result: dict[str, object], extra: dict[str, Any]) -> dict[str, object]:
    patched = dict(result)
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update(extra)
    patched['meta'] = meta
    return patched


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


def _compact_value(payload: dict[str, Any], config: dict[str, Any], key: str, default: Any) -> Any:
    if key in payload:
        return payload.get(key)
    return config.get(key, default)


def _compact_bool(payload: dict[str, Any], config: dict[str, Any], key: str, default: bool) -> bool:
    value = _compact_value(payload, config, key, default)
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in _BOOL_TRUE


def _compact_int(payload: dict[str, Any], config: dict[str, Any], key: str, default: int, *, minimum: int, maximum: int) -> int:
    return _intish(_compact_value(payload, config, key, default), default, minimum=minimum, maximum=maximum)


def _list_len(value: Any) -> int:
    return len(value) if isinstance(value, list) else 0


def _add_compact_mismatch(state: dict[str, Any], message: str) -> None:
    state['count'] = int(state.get('count') or 0) + 1
    if not state.get('first'):
        state['first'] = message


def _compact_multilevel_step_result(
    result: dict[str, object],
    payload: dict[str, Any],
    config: dict[str, Any],
) -> dict[str, object]:
    """Compact transport payload only; original chan.py structures are not recalculated here."""
    if str(payload.get('mode') or 'once').lower() != 'step':
        return result
    frames = result.get('frames')
    if not isinstance(frames, list):
        return result

    include_bars = _compact_bool(payload, config, 'include_bars_in_frames', False)
    include_indicators = _compact_bool(payload, config, 'include_indicators_in_frames', False)
    frame_policy = str(_compact_value(payload, config, 'frame_policy', 'full')).strip().lower() or 'full'
    frame_stride = _compact_int(payload, config, 'frame_stride', 1, minimum=1, maximum=1000)
    frame_start_raw = _compact_value(payload, config, 'frame_start', None)
    frame_end_raw = _compact_value(payload, config, 'frame_end', None)
    max_return_frames = _compact_int(payload, config, 'max_return_frames', len(frames), minimum=1, maximum=5000)

    selected_frames = list(frames)
    if frame_policy == 'stride' and frame_stride > 1:
        selected_frames = [frame for i, frame in enumerate(selected_frames) if i % frame_stride == 0]
    elif frame_policy == 'window':
        start = _intish(frame_start_raw, 0, minimum=0, maximum=10_000_000)
        end = _intish(frame_end_raw, len(selected_frames) - 1, minimum=0, maximum=10_000_000)
        selected_frames = selected_frames[start:end + 1]
    elif frame_policy == 'latest':
        selected_frames = selected_frames[-1:]
    elif frame_policy != 'full':
        frame_policy = 'full'

    if len(selected_frames) > max_return_frames:
        selected_frames = selected_frames[-max_return_frames:]

    meta = dict(result.get('meta')) if isinstance(result.get('meta'), dict) else {}
    native_total = meta.get('native_step_frames_total')
    frames_total = native_total if isinstance(native_total, int) else len(frames)
    frames_returned = len(selected_frames)
    frames_truncated = frames_returned < frames_total

    compact_frames: list[Any] = []
    validation_state: dict[str, Any] = {'count': 0, 'first': ''}
    for frame_index, frame in enumerate(selected_frames):
        if not isinstance(frame, dict):
            _add_compact_mismatch(validation_state, f'frame[{frame_index}] is not object')
            compact_frames.append(frame)
            continue
        next_frame = dict(frame)
        frame_levels = next_frame.get('levels')
        if isinstance(frame_levels, dict):
            next_levels: dict[str, Any] = {}
            for level_name, level_payload in frame_levels.items():
                if not isinstance(level_payload, dict):
                    _add_compact_mismatch(validation_state, f'frame[{frame_index}].{level_name} is not object')
                    next_levels[level_name] = level_payload
                    continue
                next_level = dict(level_payload)
                bars = next_level.get('bars')
                visible_count = len(bars) if isinstance(bars, list) else next_level.get('visible_count', 0)
                next_level['visible_count'] = visible_count
                if not include_bars:
                    next_level.pop('bars', None)
                if not include_indicators:
                    next_level.pop('indicators', None)

                if next_level.get('visible_count') != visible_count:
                    _add_compact_mismatch(validation_state, f'frame[{frame_index}].{level_name}.visible_count changed')
                if not include_bars and 'bars' in next_level:
                    _add_compact_mismatch(validation_state, f'frame[{frame_index}].{level_name}.bars not removed')
                if include_bars and _list_len(next_level.get('bars')) != visible_count:
                    _add_compact_mismatch(validation_state, f'frame[{frame_index}].{level_name}.bars length mismatch')
                if not include_indicators and 'indicators' in next_level:
                    _add_compact_mismatch(validation_state, f'frame[{frame_index}].{level_name}.indicators not removed')
                for key in _COMPACT_STRUCTURE_KEYS:
                    if _list_len(level_payload.get(key)) != _list_len(next_level.get(key)):
                        _add_compact_mismatch(validation_state, f'frame[{frame_index}].{level_name}.{key} length mismatch')
                next_levels[level_name] = next_level
            next_frame['levels'] = next_levels
        else:
            _add_compact_mismatch(validation_state, f'frame[{frame_index}].levels missing')
        frame_meta = dict(next_frame.get('meta')) if isinstance(next_frame.get('meta'), dict) else {}
        frame_meta.update({
            'step_frame_format': 'compact_v1',
            'frame_policy': frame_policy,
            'frame_stride': frame_stride,
            'frames_total': frames_total,
            'frames_returned': frames_returned,
            'frames_truncated': frames_truncated,
            'max_return_frames': max_return_frames,
            'include_bars_in_frames': include_bars,
            'include_indicators_in_frames': include_indicators,
        })
        next_frame['meta'] = frame_meta
        compact_frames.append(next_frame)

    validation_status = 'match' if int(validation_state.get('count') or 0) == 0 else 'mismatch'
    validation_meta = {
        'compact_validation_scope': 'backend_precompact_vs_compact_transport',
        'compact_validation_status': validation_status,
        'compact_validation_mismatch_count': int(validation_state.get('count') or 0),
        'compact_validation_first_mismatch': validation_state.get('first') or '',
    }
    for frame in compact_frames:
        if isinstance(frame, dict):
            frame_meta = dict(frame.get('meta')) if isinstance(frame.get('meta'), dict) else {}
            frame_meta.update(validation_meta)
            frame['meta'] = frame_meta

    next_result = dict(result)
    next_result['frames'] = compact_frames
    meta.update({
        'step_frame_format': 'compact_v1',
        'frame_policy': frame_policy,
        'frame_stride': frame_stride,
        'frame_start': frame_start_raw,
        'frame_end': frame_end_raw,
        'frames_total': frames_total,
        'frames_returned': frames_returned,
        'frames_truncated': frames_truncated,
        'max_return_frames': max_return_frames,
        'include_bars_in_frames': include_bars,
        'include_indicators_in_frames': include_indicators,
        'compact_transport_only': True,
        'chan_py_core_unchanged': True,
        **validation_meta,
    })
    next_result['meta'] = meta
    return next_result


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
    route_start = perf_counter()
    config = payload.get('config') if isinstance(payload.get('config'), dict) else {}
    levels = payload.get('lv_list') or payload.get('levels') or payload.get('level_order')

    analyze_start = perf_counter()
    result = analyze_multi(
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
    analyze_ms = _elapsed_ms(analyze_start)

    compact_start = perf_counter()
    result = _compact_multilevel_step_result(result, payload, config)
    compact_ms = _elapsed_ms(compact_start)

    json_probe_start = perf_counter()
    response_probe = json.dumps(result, ensure_ascii=False, separators=(',', ':'))
    json_probe_ms = _elapsed_ms(json_probe_start)

    result = _merge_meta(result, {
        'backend_route_analyze_multi_ms': analyze_ms,
        'backend_route_compact_transform_ms': compact_ms,
        'backend_route_json_serialize_probe_ms': json_probe_ms,
        'backend_route_response_bytes_probe': len(response_probe.encode('utf-8')),
        'backend_route_total_before_response_ms': _elapsed_ms(route_start),
    })
    return result


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
            include_labels=True,
        )
    model_name = str(payload.get('model') or 'logistic_v1')
    return score_bsp_features(raw_features, model_name=model_name)


@app.post('/api/research/backtest')
def research_backtest(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    analysis = _analysis_from_payload(payload)
    return run_bsp_backtest(
        analysis,
        horizon=_payload_int(payload, 'horizon', 5, minimum=1, maximum=250),
        fee_rate=float(payload.get('fee_rate', 0.0005) or 0.0),
        slippage=float(payload.get('slippage', 0.0) or 0.0),
        initial_cash=float(payload.get('initial_cash', 100000.0) or 100000.0),
    )


@app.post('/api/research/pipeline')
def research_pipeline(payload: dict[str, Any] = Body(...)) -> dict[str, object]:
    analysis = _analysis_from_payload(payload)
    horizon = _payload_int(payload, 'horizon', 5, minimum=1, maximum=250)
    features = extract_bsp_features(
        analysis,
        label_horizon=horizon,
        include_labels=True,
    )
    scored = score_bsp_features(features.get('features', []), model_name=str(payload.get('model') or 'logistic_v1'))
    backtest = run_bsp_backtest(
        analysis,
        horizon=horizon,
        fee_rate=float(payload.get('fee_rate', 0.0005) or 0.0),
        slippage=float(payload.get('slippage', 0.0) or 0.0),
        initial_cash=float(payload.get('initial_cash', 100000.0) or 100000.0),
    )
    return {
        'ok': True,
        'features': features,
        'scores': scored,
        'backtest': backtest,
    }


@app.post('/api/scanner/bsp/scan')
def scanner_bsp_scan(payload: dict[str, Any] | None = Body(None)) -> dict[str, object]:
    return scan_bsp(**_scanner_args(payload))


@app.get('/api/scanner/bsp/scan_stream')
def scanner_bsp_scan_stream(
    limit: int = Query(300, ge=1, le=5000),
    days: int = Query(365, ge=30, le=5000),
    recent_days: int = Query(3, ge=1, le=120),
    bi_strict: bool = Query(True),
) -> StreamingResponse:
    def _iter():
        for event in scan_bsp_events(limit=limit, days=days, recent_days=recent_days, bi_strict=bi_strict):
            yield json.dumps(event, ensure_ascii=False) + '\n'

    return StreamingResponse(_iter(), media_type='application/x-ndjson')
