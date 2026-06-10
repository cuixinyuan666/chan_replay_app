from __future__ import annotations

from typing import Any, Callable, TypeVar, cast

from .a_easy_tdx_indicators import build_easy_tdx_indicators, easy_tdx_indicator_meta

F = TypeVar('F', bound=Callable[..., dict[str, Any]])


def _config_int(config: dict[str, Any] | None, key: str, default: int) -> int:
    try:
        return int((config or {}).get(key) or default)
    except (TypeError, ValueError):
        return default


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


def _merge_indicator_meta(result: dict[str, Any]) -> None:
    patch = easy_tdx_indicator_meta()
    meta = result.setdefault('meta', {})
    if not isinstance(meta, dict):
        result['meta'] = patch
        return
    indicator_sources = patch.get('indicator_sources')
    if isinstance(indicator_sources, dict):
        meta['indicator_sources'] = indicator_sources
    if 'indicator_warning' in patch:
        meta['indicator_warning'] = patch['indicator_warning']


def _with_easy_tdx_indicators(result: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    bars = result.get('bars')
    if not isinstance(bars, list):
        result.setdefault('indicators', {})
        return result
    rows = [row for row in bars if isinstance(row, dict)]
    try:
        result['indicators'] = build_easy_tdx_indicators(
            rows,
            boll_window=_config_int(config, 'boll_n', 20),
            macd_fast=_config_int(config, 'macd_fast', 12),
            macd_slow=_config_int(config, 'macd_slow', 26),
            macd_signal=_config_int(config, 'macd_signal', 9),
        )
        _merge_indicator_meta(result)
    except Exception as exc:  # pragma: no cover - defensive display fallback
        result['indicators'] = {}
        _append_warning(result, f'easy-tdx indicator build failed: {exc}')
    return result


def _with_frame_indicators(result: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    frames = result.get('frames')
    if isinstance(frames, list):
        for frame in frames:
            if isinstance(frame, dict):
                _with_easy_tdx_indicators(frame, config)
    return result


def _wrap(fn: F) -> F:
    def wrapped(*args: Any, **kwargs: Any) -> dict[str, Any]:
        config = kwargs.get('config') if isinstance(kwargs.get('config'), dict) else None
        result = fn(*args, **kwargs)
        _with_easy_tdx_indicators(result, config)
        _with_frame_indicators(result, config)
        return result

    return cast(F, wrapped)


def install_easy_tdx_indicator_patch() -> None:
    from . import chanpy_engine

    if getattr(chanpy_engine, '_EASY_TDX_INDICATOR_PATCHED', False):
        return
    chanpy_engine.analyze_bars = _wrap(chanpy_engine.analyze_bars)
    chanpy_engine.analyze_once = _wrap(chanpy_engine.analyze_once)
    chanpy_engine.analyze_step = _wrap(chanpy_engine.analyze_step)
    chanpy_engine._EASY_TDX_INDICATOR_PATCHED = True
