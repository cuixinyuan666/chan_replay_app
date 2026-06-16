from __future__ import annotations

import os
import time
from copy import deepcopy
from dataclasses import dataclass
from threading import RLock
from typing import Any, Callable

_BOOL_TRUE = {'1', 'true', 'yes', 'y', 'on'}
_STRUCTURE_KEYS = ('merged_bars', 'fx', 'bi', 'seg', 'zs', 'bsp')
_TRANSPORT_LAYER_KEYS = ('bars', 'indicators', *_STRUCTURE_KEYS)
_LAYER_ALIASES = {
    'bar': 'bars',
    'bars': 'bars',
    'kline': 'bars',
    'k_line': 'bars',
    'raw': 'bars',
    'raw_bars': 'bars',
    'indicator': 'indicators',
    'indicators': 'indicators',
    'easy_tdx': 'indicators',
    'merged': 'merged_bars',
    'merged_bar': 'merged_bars',
    'merged_bars': 'merged_bars',
    'mergedBars': 'merged_bars',
    'fx': 'fx',
    'fract': 'fx',
    'fractal': 'fx',
    'bi': 'bi',
    'seg': 'seg',
    'segment': 'seg',
    'zs': 'zs',
    'center': 'zs',
    'bsp': 'bsp',
    'bsps': 'bsp',
    'buy_sell_point': 'bsp',
}
_RAW_INDEX_KEYS = (
    'raw_index',
    'start_raw_index',
    'end_raw_index',
    'high_raw_index',
    'low_raw_index',
    'anchor_raw_index',
    'display_raw_index',
    'child_start_raw_index',
    'child_end_raw_index',
)


def _bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in _BOOL_TRUE


def _optional_int(value: Any) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _time_text(row: dict[str, Any] | None) -> str | None:
    if not isinstance(row, dict):
        return None
    value = row.get('dt') or row.get('time') or row.get('date')
    return None if value is None else str(value)


@dataclass
class _KlineCacheEntry:
    value: list[dict[str, Any]]
    created_at: float
    expires_at: float
    hits: int = 0


class _BackendKlineSessionCache:
    def __init__(self) -> None:
        self._lock = RLock()
        self._entries: dict[tuple[Any, ...], _KlineCacheEntry] = {}
        self._hits = 0
        self._misses = 0
        self._expired = 0
        self._evictions = 0
        self._hit_levels: list[str] = []
        self._miss_levels: list[str] = []

    @property
    def ttl_seconds(self) -> int:
        raw = os.environ.get('CHAN_REPLAY_KLINE_CACHE_TTL_SECONDS')
        try:
            return max(1, min(86400, int(raw))) if raw is not None else 900
        except ValueError:
            return 900

    @property
    def max_entries(self) -> int:
        raw = os.environ.get('CHAN_REPLAY_KLINE_CACHE_MAX_ENTRIES')
        try:
            return max(1, min(2048, int(raw))) if raw is not None else 128
        except ValueError:
            return 128

    def _purge_expired_locked(self, now: float) -> None:
        expired_keys = [key for key, entry in self._entries.items() if entry.expires_at <= now]
        for key in expired_keys:
            self._entries.pop(key, None)
            self._expired += 1

    def _evict_if_needed_locked(self) -> None:
        while len(self._entries) > self.max_entries:
            oldest_key = min(
                self._entries,
                key=lambda key: (self._entries[key].hits, self._entries[key].created_at),
            )
            self._entries.pop(oldest_key, None)
            self._evictions += 1

    def get(self, key: tuple[Any, ...], level: str) -> list[dict[str, Any]] | None:
        now = time.time()
        with self._lock:
            self._purge_expired_locked(now)
            entry = self._entries.get(key)
            if entry is None:
                self._misses += 1
                self._miss_levels.append(level)
                return None
            entry.hits += 1
            self._hits += 1
            self._hit_levels.append(level)
            return deepcopy(entry.value)

    def put(self, key: tuple[Any, ...], value: list[dict[str, Any]]) -> list[dict[str, Any]]:
        now = time.time()
        with self._lock:
            self._entries[key] = _KlineCacheEntry(
                value=deepcopy(value),
                created_at=now,
                expires_at=now + self.ttl_seconds,
            )
            self._evict_if_needed_locked()
        return value

    def clear(self) -> None:
        with self._lock:
            self._entries.clear()
            self.reset_request_stats()

    def reset_request_stats(self) -> None:
        with self._lock:
            self._hits = 0
            self._misses = 0
            self._expired = 0
            self._evictions = 0
            self._hit_levels = []
            self._miss_levels = []

    def stats(self) -> dict[str, Any]:
        with self._lock:
            now = time.time()
            self._purge_expired_locked(now)
            return {
                'backend_session_kline_cache_enabled': True,
                'backend_session_kline_cache_scope': 'process-session',
                'backend_session_kline_cache_hits': self._hits,
                'backend_session_kline_cache_misses': self._misses,
                'backend_session_kline_cache_expired': self._expired,
                'backend_session_kline_cache_evictions': self._evictions,
                'backend_session_kline_cache_hit_levels': list(self._hit_levels),
                'backend_session_kline_cache_miss_levels': list(self._miss_levels),
                'backend_session_kline_cache_key_count': len(self._entries),
                'backend_session_kline_cache_ttl_seconds': self.ttl_seconds,
                'backend_session_kline_cache_max_entries': self.max_entries,
                'backend_session_kline_cache_key_policy': 'symbol,market,period,adjust,count,start,end; raw K-line only; no Chan structure/result cache',
            }


_KLINE_SESSION_CACHE = _BackendKlineSessionCache()
_CACHE_INSTALLED = False
_BSP_INSTALLED = False
_ORIGINAL_LOAD_EASY_TDX_BARS: Callable[..., list[dict[str, Any]]] | None = None
_ORIGINAL_GET_EASY_TDX_CACHE_STATS: Callable[[], dict[str, Any]] | None = None
_ORIGINAL_RESET_EASY_TDX_CACHE_STATS: Callable[[], None] | None = None
_ORIGINAL_EXPORT_BSP: Callable[[Any], list[dict[str, Any]]] | None = None


def _kline_cache_key(
    *,
    symbol: str,
    market: str | None,
    period: str,
    adjust: str,
    count: int,
    start: str | None,
    end: str | None,
) -> tuple[Any, ...]:
    return (
        str(symbol).strip().upper().replace('.SZ', '').replace('.SH', ''),
        str(market or '').strip().upper(),
        str(period or 'DAILY').strip().upper(),
        str(adjust or 'QFQ').strip().upper(),
        int(count),
        str(start or '').strip(),
        str(end or '').strip(),
    )


def _cached_load_easy_tdx_bars(
    *,
    symbol: str,
    market: str | None = None,
    period: str = 'DAILY',
    adjust: str = 'QFQ',
    count: int = 800,
    start: str | None = None,
    end: str | None = None,
) -> list[dict[str, Any]]:
    if _ORIGINAL_LOAD_EASY_TDX_BARS is None:
        raise RuntimeError('backend K-line session cache is not installed')
    safe_count = max(1, int(count))
    level = str(period or 'DAILY').strip().upper()
    key = _kline_cache_key(
        symbol=symbol,
        market=market,
        period=level,
        adjust=adjust,
        count=safe_count,
        start=start,
        end=end,
    )
    cached = _KLINE_SESSION_CACHE.get(key, level)
    if cached is not None:
        return cached
    rows = _ORIGINAL_LOAD_EASY_TDX_BARS(
        symbol=symbol,
        market=market,
        period=level,
        adjust=adjust,
        count=safe_count,
        start=start,
        end=end,
    )
    return deepcopy(_KLINE_SESSION_CACHE.put(key, rows))


def _merged_easy_tdx_cache_stats() -> dict[str, Any]:
    base = _ORIGINAL_GET_EASY_TDX_CACHE_STATS() if _ORIGINAL_GET_EASY_TDX_CACHE_STATS else {}
    merged = dict(base)
    merged.update(_KLINE_SESSION_CACHE.stats())
    merged['policy'] = (
        str(base.get('policy') or '')
        + '; session TTL wrapper sits above easy-tdx raw cache and never caches Chan structures'
    ).strip('; ')
    return merged


def _reset_easy_tdx_request_cache_stats() -> None:
    if _ORIGINAL_RESET_EASY_TDX_CACHE_STATS:
        _ORIGINAL_RESET_EASY_TDX_CACHE_STATS()
    _KLINE_SESSION_CACHE.reset_request_stats()


def install_backend_kline_session_cache() -> dict[str, Any]:
    """Install process-session raw K-line caching without caching chan.py structures."""
    global _CACHE_INSTALLED, _ORIGINAL_LOAD_EASY_TDX_BARS, _ORIGINAL_GET_EASY_TDX_CACHE_STATS, _ORIGINAL_RESET_EASY_TDX_CACHE_STATS
    if _CACHE_INSTALLED:
        return _KLINE_SESSION_CACHE.stats()

    from . import a_multilevel_native_engine, a_multilevel_native_timed_engine, chanpy_engine, easy_tdx_provider

    _ORIGINAL_LOAD_EASY_TDX_BARS = easy_tdx_provider.load_easy_tdx_bars
    _ORIGINAL_GET_EASY_TDX_CACHE_STATS = easy_tdx_provider.get_easy_tdx_cache_stats
    _ORIGINAL_RESET_EASY_TDX_CACHE_STATS = easy_tdx_provider.reset_easy_tdx_cache_stats

    easy_tdx_provider.load_easy_tdx_bars = _cached_load_easy_tdx_bars
    chanpy_engine.load_easy_tdx_bars = _cached_load_easy_tdx_bars
    a_multilevel_native_engine.load_easy_tdx_bars = _cached_load_easy_tdx_bars

    easy_tdx_provider.get_easy_tdx_cache_stats = _merged_easy_tdx_cache_stats
    a_multilevel_native_timed_engine.get_easy_tdx_cache_stats = _merged_easy_tdx_cache_stats
    easy_tdx_provider.reset_easy_tdx_cache_stats = _reset_easy_tdx_request_cache_stats
    a_multilevel_native_timed_engine.reset_easy_tdx_cache_stats = _reset_easy_tdx_request_cache_stats

    _CACHE_INSTALLED = True
    return _KLINE_SESSION_CACHE.stats()


def get_backend_kline_session_cache_stats() -> dict[str, Any]:
    return _KLINE_SESSION_CACHE.stats()


def clear_backend_kline_session_cache() -> dict[str, Any]:
    _KLINE_SESSION_CACHE.clear()
    return _KLINE_SESSION_CACHE.stats()


def _enrich_bsp_row(row: dict[str, Any]) -> dict[str, Any]:
    patched = dict(row)
    confirmed = _bool(patched.get('confirmed'), True)
    anchor_raw_index = _optional_int(patched.get('anchor_raw_index'))
    if anchor_raw_index is None:
        anchor_raw_index = _optional_int(patched.get('raw_index'))
    anchor_time = patched.get('anchor_time') if patched.get('anchor_time') is not None else patched.get('time')
    anchor_price = patched.get('anchor_price') if patched.get('anchor_price') is not None else patched.get('price')

    display_raw_index = _optional_int(patched.get('display_raw_index'))
    if display_raw_index is None:
        display_raw_index = anchor_raw_index
    if anchor_raw_index is not None and display_raw_index is not None and display_raw_index > anchor_raw_index:
        display_raw_index = anchor_raw_index

    patched.update({
        'confirmed': confirmed,
        'anchor_raw_index': anchor_raw_index,
        'anchor_time': None if anchor_time is None else str(anchor_time),
        'anchor_price': anchor_price,
        'display_raw_index': display_raw_index,
        'display_time': str(anchor_time) if patched.get('display_time') is None and anchor_time is not None else patched.get('display_time'),
        'display_price': anchor_price if patched.get('display_price') is None else patched.get('display_price'),
        'history_frozen': True,
        'bsp_history_contract': 'anchor_display_confirmed_v1',
        'bsp_freeze_policy': 'anchor/display/confirmed are copied at backend export time; display index is never allowed to move after anchor index',
    })
    patched['anchor'] = {
        'raw_index': patched.get('anchor_raw_index'),
        'time': patched.get('anchor_time'),
        'price': patched.get('anchor_price'),
    }
    patched['display'] = {
        'raw_index': patched.get('display_raw_index'),
        'time': patched.get('display_time'),
        'price': patched.get('display_price'),
    }
    patched['future_safe'] = (
        patched.get('anchor_raw_index') is None
        or patched.get('display_raw_index') is None
        or int(patched['display_raw_index']) <= int(patched['anchor_raw_index'])
    )
    return patched


def _enrich_bsp_list(rows: Any) -> Any:
    if not isinstance(rows, list):
        return rows
    return [_enrich_bsp_row(row) if isinstance(row, dict) else row for row in rows]


def install_bsp_history_contract() -> dict[str, Any]:
    """Add BSP anchor/display/confirmed frozen fields at export time only."""
    global _BSP_INSTALLED, _ORIGINAL_EXPORT_BSP
    if _BSP_INSTALLED:
        return {'bsp_history_contract': 'anchor_display_confirmed_v1', 'installed': True}

    from . import a_multilevel_native_timed_engine, chanpy_engine

    _ORIGINAL_EXPORT_BSP = chanpy_engine._export_bsp

    def _wrapped_export_bsp(level: Any) -> list[dict[str, Any]]:
        if _ORIGINAL_EXPORT_BSP is None:
            return []
        return _enrich_bsp_list(_ORIGINAL_EXPORT_BSP(level))

    chanpy_engine._export_bsp = _wrapped_export_bsp
    a_multilevel_native_timed_engine._export_bsp = _wrapped_export_bsp
    _BSP_INSTALLED = True
    return {'bsp_history_contract': 'anchor_display_confirmed_v1', 'installed': True}


def _visible_count(level_payload: Any) -> int | None:
    if not isinstance(level_payload, dict):
        return None
    visible = _optional_int(level_payload.get('visible_count'))
    if visible is not None:
        return visible
    bars = level_payload.get('bars')
    if isinstance(bars, list):
        return len(bars)
    return None


def _latest_time(level_payload: Any) -> str | None:
    if not isinstance(level_payload, dict):
        return None
    bars = level_payload.get('bars')
    if isinstance(bars, list) and bars:
        return _time_text(bars[-1])
    return None


def _collect_raw_indices(value: Any) -> list[int]:
    indices: list[int] = []
    if isinstance(value, dict):
        for key, item in value.items():
            if key in _RAW_INDEX_KEYS:
                idx = _optional_int(item)
                if idx is not None:
                    indices.append(idx)
            elif isinstance(item, (dict, list)):
                indices.extend(_collect_raw_indices(item))
    elif isinstance(value, list):
        for item in value:
            indices.extend(_collect_raw_indices(item))
    return indices


def _add_violation(state: dict[str, Any], message: str) -> None:
    state['count'] = int(state.get('count') or 0) + 1
    if not state.get('first'):
        state['first'] = message


def _check_levels_for_future(levels: Any, *, scope: str, state: dict[str, Any]) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    if not isinstance(levels, dict):
        _add_violation(state, f'{scope}.levels missing')
        return summary
    for level_name, level_payload in levels.items():
        visible = _visible_count(level_payload)
        summary[str(level_name)] = {
            'visible_count': visible,
            'latest_time': _latest_time(level_payload),
        }
        if visible is None:
            continue
        for layer_key in _STRUCTURE_KEYS:
            if not isinstance(level_payload, dict):
                continue
            layer = level_payload.get(layer_key)
            indices = _collect_raw_indices(layer)
            if indices and max(indices) >= visible:
                _add_violation(
                    state,
                    f'{scope}.{level_name}.{layer_key} max_raw_index={max(indices)} >= visible_count={visible}',
                )
    return summary


def _check_relations_for_future(relations: Any, level_summary: dict[str, Any], state: dict[str, Any]) -> None:
    if not isinstance(relations, list):
        return
    for index, relation in enumerate(relations):
        if not isinstance(relation, dict):
            continue
        child_level = str(relation.get('child_level') or '')
        child_summary = level_summary.get(child_level) if isinstance(level_summary, dict) else None
        child_visible = child_summary.get('visible_count') if isinstance(child_summary, dict) else None
        child_end = _optional_int(relation.get('child_end_raw_index'))
        if isinstance(child_visible, int) and child_end is not None and child_end >= child_visible:
            _add_violation(
                state,
                f'relations[{index}] child_end_raw_index={child_end} >= {child_level}.visible_count={child_visible}',
            )


def _apply_anti_future_meta(result: dict[str, Any]) -> dict[str, Any]:
    patched = dict(result)
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    state: dict[str, Any] = {'count': 0, 'first': ''}

    final_summary = _check_levels_for_future(patched.get('levels'), scope='final', state=state)
    _check_relations_for_future(patched.get('relations'), final_summary, state)

    frames_checked = 0
    frame_summaries: list[dict[str, Any]] = []
    frames = patched.get('frames')
    if isinstance(frames, list):
        frames_checked = len(frames)
        for frame_index, frame in enumerate(frames):
            if not isinstance(frame, dict):
                _add_violation(state, f'frames[{frame_index}] is not object')
                continue
            frame_summary = _check_levels_for_future(frame.get('levels'), scope=f'frames[{frame_index}]', state=state)
            frame_summaries.append({'frame_index': frame_index, 'levels': frame_summary})
            frame_meta = dict(frame.get('meta')) if isinstance(frame.get('meta'), dict) else {}
            frame_meta.update({
                'anti_future_contract': 'multi_level_anti_future_meta_v1',
                'anti_future_checked': True,
                'anti_future_scope': 'returned_step_frame',
                'anti_future_status': 'pass' if int(state.get('count') or 0) == 0 else 'violation',
            })
            frame['meta'] = frame_meta

    meta.update({
        'anti_future_contract': 'multi_level_anti_future_meta_v1',
        'anti_future_checked': True,
        'anti_future_status': 'pass' if int(state.get('count') or 0) == 0 else 'violation',
        'anti_future_violation_count': int(state.get('count') or 0),
        'anti_future_first_violation': state.get('first') or '',
        'anti_future_scope': 'final_levels + returned_step_frames + parent_child_relations',
        'anti_future_policy': 'backend metadata validation only; chan.py remains calculation source; Flutter must not infer future structures',
        'anti_future_final_levels': final_summary,
        'anti_future_frames_checked': frames_checked,
        'anti_future_frame_level_samples': frame_summaries[:5],
    })
    patched['meta'] = meta
    return patched


def _canonical_layer(raw: Any) -> str | None:
    text = str(raw or '').strip()
    if not text:
        return None
    if text.lower() == 'all':
        return 'all'
    return _LAYER_ALIASES.get(text) or _LAYER_ALIASES.get(text.lower())


def _requested_layer_list(raw: Any) -> list[str]:
    if isinstance(raw, str):
        values = [part.strip() for part in raw.replace('，', ',').split(',') if part.strip()]
    elif isinstance(raw, list):
        values = [str(part).strip() for part in raw if str(part).strip()]
    elif isinstance(raw, dict):
        values = [str(key).strip() for key, enabled in raw.items() if _bool(enabled, False)]
    else:
        values = []
    result: list[str] = []
    for value in values:
        canonical = _canonical_layer(value)
        if canonical == 'all':
            return list(_TRANSPORT_LAYER_KEYS)
        if canonical and canonical not in result:
            result.append(canonical)
    return result


def _chart_lazy_source(payload: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    raw = payload.get('chart_lazy_layers')
    if raw is None:
        raw = config.get('chart_lazy_layers')
    raw_layers = payload.get('chart_layers')
    if raw_layers is None:
        raw_layers = config.get('chart_layers')
    if isinstance(raw, dict):
        return {
            'enabled': _bool(raw.get('enabled'), True),
            'layers': raw.get('layers') if raw.get('layers') is not None else raw_layers,
        }
    return {
        'enabled': _bool(raw, False),
        'layers': raw_layers,
    }


def _resolve_chart_layers(payload: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    source = _chart_lazy_source(payload, config)
    enabled = bool(source['enabled'])
    requested = _requested_layer_list(source.get('layers'))
    if enabled and not requested:
        requested = list(_TRANSPORT_LAYER_KEYS)
    display_layers = list(_TRANSPORT_LAYER_KEYS) if not enabled else list(dict.fromkeys(['bars', *requested]))

    forced: list[str] = ['bars']
    transport = set(display_layers)
    if {'fx', 'bi', 'seg'} & transport:
        forced.append('merged_bars')
        transport.add('merged_bars')
    if 'seg' in transport:
        forced.append('bi')
        transport.add('bi')
        transport.add('merged_bars')
    forced = [layer for layer in dict.fromkeys(forced) if layer not in display_layers]
    transport.update(forced)
    ordered_transport = [layer for layer in _TRANSPORT_LAYER_KEYS if layer in transport]
    ordered_display = [layer for layer in _TRANSPORT_LAYER_KEYS if layer in display_layers]
    omitted = [layer for layer in _TRANSPORT_LAYER_KEYS if layer not in ordered_transport]
    return {
        'enabled': enabled,
        'requested': requested,
        'display_layers': ordered_display,
        'transport_layers': ordered_transport,
        'forced_layers': forced,
        'omitted_layers': omitted,
    }


def _layer_counts(level_payload: Any) -> dict[str, int]:
    result: dict[str, int] = {}
    if not isinstance(level_payload, dict):
        return result
    for key in _TRANSPORT_LAYER_KEYS:
        value = level_payload.get(key)
        if value is None and key == 'merged_bars':
            value = level_payload.get('mergedBars')
        if value is None and key == 'bsp':
            value = level_payload.get('bsps')
        result[key] = len(value) if isinstance(value, list) else 0
    if not result.get('bars'):
        visible = _visible_count(level_payload)
        if visible is not None:
            result['bars_visible_count'] = visible
    return result


def _build_layer_manifest(levels: Any) -> dict[str, Any]:
    if not isinstance(levels, dict):
        return {}
    return {str(level): _layer_counts(payload) for level, payload in levels.items()}


def _removed_count(value: Any) -> int:
    if isinstance(value, list):
        return len(value)
    if isinstance(value, dict):
        return len(value)
    return 1 if value is not None else 0


def _prune_level_payload(level_payload: Any, transport_layers: set[str], stats: dict[str, int]) -> Any:
    if not isinstance(level_payload, dict):
        return level_payload
    patched = dict(level_payload)
    aliases = {
        'merged_bars': ('merged_bars', 'mergedBars'),
        'bsp': ('bsp', 'bsps'),
    }
    for layer in _TRANSPORT_LAYER_KEYS:
        if layer == 'bars':
            continue
        keys = aliases.get(layer, (layer,))
        if layer not in transport_layers:
            for key in keys:
                if key in patched:
                    stats[layer] = stats.get(layer, 0) + _removed_count(patched.get(key))
                    patched.pop(key, None)
    return patched


def _prune_levels_map(levels: Any, transport_layers: set[str], stats: dict[str, int]) -> Any:
    if not isinstance(levels, dict):
        return levels
    return {
        key: _prune_level_payload(value, transport_layers, stats)
        for key, value in levels.items()
    }


def _prune_result_chart_layers(result: dict[str, Any], layer_state: dict[str, Any]) -> tuple[dict[str, Any], dict[str, int]]:
    if not layer_state['enabled']:
        return result, {}
    transport_layers = set(layer_state['transport_layers'])
    patched = dict(result)
    stats: dict[str, int] = {}
    patched['levels'] = _prune_levels_map(patched.get('levels'), transport_layers, stats)
    frames = patched.get('frames')
    if isinstance(frames, list):
        patched_frames = []
        for frame in frames:
            if isinstance(frame, dict):
                next_frame = dict(frame)
                next_frame['levels'] = _prune_levels_map(next_frame.get('levels'), transport_layers, stats)
                patched_frames.append(next_frame)
            else:
                patched_frames.append(frame)
        patched['frames'] = patched_frames
    return patched, stats


def _apply_chart_lazy_layers_contract(result: dict[str, Any], payload: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    layer_state = _resolve_chart_layers(payload, config)
    before_manifest = _build_layer_manifest(result.get('levels'))
    patched, pruned_counts = _prune_result_chart_layers(result, layer_state)
    manifest = _build_layer_manifest(patched.get('levels'))
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update({
        'chart_lazy_layers_contract': 'chart_lazy_layers_v2_transport_pruning',
        'chart_lazy_layers_enabled': layer_state['enabled'],
        'chart_lazy_layers_requested': layer_state['requested'],
        'chart_lazy_layers_display_layers': layer_state['display_layers'],
        'chart_lazy_layers_transport_layers': layer_state['transport_layers'],
        'chart_lazy_layers_forced_transport_layers': layer_state['forced_layers'],
        'chart_lazy_layers_omitted_layers': layer_state['omitted_layers'],
        'chart_lazy_layers_pruned_counts': pruned_counts,
        'chart_lazy_layers_available': list(_TRANSPORT_LAYER_KEYS),
        'chart_lazy_layers_manifest_before_prune': before_manifest,
        'chart_lazy_layers_manifest': manifest,
        'chart_lazy_layers_compute_policy': 'chan.py calculation/export still runs on backend; only response transport payload is pruned',
        'chart_lazy_layers_flutter_policy': 'Flutter sends desired layers and renders returned manifest; Flutter must not calculate FX/BI/SEG/ZS/BSP',
        'chart_lazy_layers_endpoint': '/api/chan/analyze_multi',
    })
    patched['layer_manifest'] = manifest
    patched['meta'] = meta
    return patched


def _enrich_existing_bsp_rows(value: Any) -> Any:
    if isinstance(value, dict):
        patched = dict(value)
        if isinstance(patched.get('bsp'), list):
            patched['bsp'] = _enrich_bsp_list(patched['bsp'])
        if isinstance(patched.get('bsps'), list):
            patched['bsps'] = _enrich_bsp_list(patched['bsps'])
        for key, item in list(patched.items()):
            if isinstance(item, (dict, list)):
                patched[key] = _enrich_existing_bsp_rows(item)
        return patched
    if isinstance(value, list):
        return [_enrich_existing_bsp_rows(item) for item in value]
    return value


def apply_analyze_multi_contracts(result: dict[str, Any], payload: dict[str, Any], config: dict[str, Any]) -> dict[str, Any]:
    """Apply transport/cache/history/future-proof contracts without recalculating Chan structures."""
    patched = _enrich_existing_bsp_rows(result)
    patched = _apply_chart_lazy_layers_contract(patched, payload, config)
    patched = _apply_anti_future_meta(patched)
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update({
        'contract_hardening': 'hichanhuancun_v2_chart_lazy_transport',
        'chan_py_core_unchanged': True,
        'flutter_chan_calculation_allowed': False,
        'backend_additions': [
            'session_kline_cache',
            'chart_lazy_layers_transport_pruning',
            'bsp_anchor_display_confirmed',
            'analyze_multi_anti_future_meta',
        ],
        **_KLINE_SESSION_CACHE.stats(),
    })
    patched['meta'] = meta
    return patched
