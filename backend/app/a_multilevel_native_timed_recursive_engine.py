from __future__ import annotations

from collections import deque
from time import perf_counter
from typing import Any

from .a_multilevel_native_engine import (
    _load_aligned_bars_by_level,
    _max_step_frames,
    _native_once_response,
    _normalize_levels,
    _prepare_native_chan,
    _snapshot_from_chan,
)
from .a_multilevel_native_timed_engine import (
    _add_elapsed_ms,
    _cache_timing_meta,
    _compact_frame_current_time,
    _elapsed_ms,
    _merge_timing,
    _timed_compact_snapshot_from_chan,
    _timed_native_failure_response,
)
from .a_recursive_seg_manager import (
    RecursiveSegRuntimeState,
    _export_bsp_list,
    _max_level_from_config,
    build_recursive_seg_payload,
)
from .chanpy_engine import _export_bsp
from .easy_tdx_provider import infer_market, normalize_symbol, reset_easy_tdx_cache_stats


def _level_recognition_position(level_payload: dict[str, Any]) -> tuple[int | None, str | None]:
    bars = level_payload.get('bars')
    if isinstance(bars, list) and bars:
        row = bars[-1] if isinstance(bars[-1], dict) else {}
        raw = row.get('index', len(bars) - 1)
        try:
            raw_index = int(raw)
        except (TypeError, ValueError):
            raw_index = len(bars) - 1
        value = row.get('dt') or row.get('time') or row.get('date')
        return raw_index, None if value is None else str(value)
    try:
        visible_count = int(level_payload.get('visible_count'))
    except (TypeError, ValueError):
        visible_count = 0
    return (visible_count - 1 if visible_count > 0 else None), None


def _capture_base_bsp_history(
    history: dict[tuple[str, int, bool], dict[str, Any]],
    rows: list[dict[str, Any]],
    *,
    recognized_raw_index: int | None,
    recognized_time: str | None,
    materialize: bool = True,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    delta: list[dict[str, Any]] = []
    if recognized_raw_index is not None:
        for row in rows:
            try:
                anchor = int(row.get('anchor_raw_index', row.get('raw_index')))
            except (TypeError, ValueError):
                continue
            type_text = str(row.get('type') or '')
            is_buy = bool(row.get('is_buy', type_text.lower().startswith(('b', 'buy'))))
            level = str(row.get('level') or 'bi').lower()
            key = (level, anchor, is_buy)
            if key in history:
                continue
            frozen = dict(row)
            frozen.update({
                'index': len(history),
                'anchor_raw_index': anchor,
                'anchor_time': row.get('time'),
                'recognized_raw_index': recognized_raw_index,
                'recognized_time': recognized_time,
                'raw_index': recognized_raw_index,
                'time': recognized_time or row.get('time'),
                'is_buy': is_buy,
                'first_recognition': True,
                'as_of_step': True,
                'source': 'base_bsp_step_history',
            })
            history[key] = frozen
            delta.append(dict(frozen))
    if not materialize:
        return [], delta
    ordered = sorted(
        (dict(row) for row in history.values()),
        key=lambda row: (
            int(row.get('recognized_raw_index', row.get('raw_index', -1))),
            int(row.get('anchor_raw_index', -1)),
            str(row.get('level') or ''),
        ),
    )
    for index, row in enumerate(ordered):
        row['index'] = index
    return ordered, delta


def _latest_level_position(level_obj: Any) -> tuple[int | None, str | None]:
    try:
        containers = list(level_obj)
    except TypeError:
        containers = []
    for container in reversed(containers):
        rows = getattr(container, 'lst', None)
        try:
            items = list(rows if rows is not None else container)
        except TypeError:
            items = []
        if not items:
            continue
        klu = items[-1]
        raw = getattr(klu, 'idx', None)
        value = getattr(klu, 'time', None)
        try:
            raw_index = int(raw)
        except (TypeError, ValueError):
            raw_index = None
        return raw_index, None if value is None else str(value)
    return None, None


def _advance_step_histories_light(
    *,
    exporter: Any,
    chan: Any,
    kl_types: list[Any],
    level_order: list[str],
    config: dict[str, Any] | None,
    runtime_states: dict[str, RecursiveSegRuntimeState],
    base_bsp_histories: dict[str, dict[tuple[str, int, bool], dict[str, Any]]],
) -> None:
    """Advance full-window as-of state without serializing a discarded frame."""
    for level_name, kl_type in zip(level_order, kl_types):
        level_obj = exporter.get_level(chan, kl_type)
        recognized_raw_index, recognized_time = _latest_level_position(level_obj)
        state = runtime_states.get(level_name)
        if state is None:
            state = RecursiveSegRuntimeState(
                max_level=_max_level_from_config(config),
                config=config,
            )
            runtime_states[level_name] = state
        state.update(level_obj)
        for layer in range(2, state.max_level + 1):
            rows = _export_bsp_list(state.bsp_objects.get(layer), layer=layer)
            state.capture_bsp_history(
                layer=layer,
                rows=rows,
                recognized_raw_index=recognized_raw_index,
                recognized_time=recognized_time,
                materialize=False,
            )
        base_rows = [row for row in _export_bsp(level_obj) if isinstance(row, dict)]
        _capture_base_bsp_history(
            base_bsp_histories.setdefault(level_name, {}),
            base_rows,
            recognized_raw_index=recognized_raw_index,
            recognized_time=recognized_time,
            materialize=False,
        )


def _compact_step_bsp_history_frame(
    frame: dict[str, Any], *, seed: bool
) -> dict[str, Any]:
    """Return one history seed followed by per-frame deltas for compact replay."""
    levels = frame.get('levels')
    if not isinstance(levels, dict):
        return frame
    patched_levels: dict[str, Any] = {}
    for level_name, raw_payload in levels.items():
        if not isinstance(raw_payload, dict):
            patched_levels[level_name] = raw_payload
            continue
        payload = dict(raw_payload)
        if not seed:
            base_delta = [
                dict(row) for row in payload.get('bsp_delta', []) if isinstance(row, dict)
            ]
            payload['bsp_history'] = base_delta
            payload['bsp'] = base_delta
            recursive_delta = payload.get('seg_bsp_delta_layers')
            payload['seg_bsp_history_layers'] = (
                dict(recursive_delta) if isinstance(recursive_delta, dict) else {}
            )
        payload['bsp_history_seed'] = seed
        payload['bsp_history_format'] = 'seed_delta_v1'
        patched_levels[level_name] = payload
    patched = dict(frame)
    patched['levels'] = patched_levels
    return patched


def _attach_recursive_seg_layers(
    *,
    result: dict[str, Any],
    exporter: Any,
    chan: Any,
    kl_types: list[Any],
    level_order: list[str],
    config: dict[str, Any] | None,
    timing: dict[str, Any],
    runtime_states: dict[str, RecursiveSegRuntimeState] | None = None,
    base_bsp_histories: dict[str, dict[tuple[str, int, bool], dict[str, Any]]] | None = None,
) -> dict[str, Any]:
    levels = result.get('levels')
    if not isinstance(levels, dict):
        return result

    recursive_start = perf_counter()
    patched_levels: dict[str, Any] = {}
    first_meta: dict[str, Any] | None = None
    total_layer_rows = 0

    for level_name, kl_type in zip(level_order, kl_types):
        level_payload = levels.get(level_name)
        if not isinstance(level_payload, dict):
            patched_levels[level_name] = level_payload
            continue
        recognized_raw_index, recognized_time = _level_recognition_position(level_payload)
        try:
            level_obj = exporter.get_level(chan, kl_type)
            state = None
            if runtime_states is not None:
                state = runtime_states.get(level_name)
                if state is None:
                    state = RecursiveSegRuntimeState(
                        max_level=_max_level_from_config(config),
                        config=config,
                    )
                    runtime_states[level_name] = state
            recursive_payload = build_recursive_seg_payload(
                level_obj=level_obj,
                structures=level_payload,
                config=config,
                runtime_state=state,
                recognized_raw_index=recognized_raw_index,
                recognized_time=recognized_time,
            )
        except Exception as exc:  # noqa: BLE001 - export-only feature must not break native analysis
            recursive_payload = {
                'seg_layers': {'1': list(level_payload.get('seg') or []), '2': []},
                'recursive_seg_meta': {
                    'max_level': 2,
                    'native_layers': ['1'],
                    'generated_layers': [],
                    'errors': {'attach': f'{type(exc).__name__}: {exc}'},
                    'bsp_policy': 'recursive segment layers do not generate BSP; native bsp/segbsp stay authoritative',
                },
            }
        next_level = dict(level_payload)
        if base_bsp_histories is not None:
            base_history = base_bsp_histories.setdefault(level_name, {})
            base_current = [
                dict(row) for row in level_payload.get('bsp', []) if isinstance(row, dict)
            ]
            base_rows, base_delta = _capture_base_bsp_history(
                base_history,
                base_current,
                recognized_raw_index=recognized_raw_index,
                recognized_time=recognized_time,
            )
            next_level['bsp_current'] = base_current
            next_level['bsp_delta'] = base_delta
            next_level['bsp_history'] = base_rows
            next_level['bsp'] = base_rows
        next_level.update(recursive_payload)
        meta = recursive_payload.get('recursive_seg_meta')
        if isinstance(meta, dict) and first_meta is None:
            first_meta = meta
        seg_layers = recursive_payload.get('seg_layers')
        if isinstance(seg_layers, dict):
            for rows in seg_layers.values():
                if isinstance(rows, list):
                    total_layer_rows += len(rows)
        patched_levels[level_name] = next_level

    _add_elapsed_ms(timing, 'backend_recursive_seg_export_ms', recursive_start)

    patched = dict(result)
    patched['levels'] = patched_levels
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update({
        'recursive_seg_layers_enabled': True,
        'recursive_seg_layer_policy': 'layer1=native seg_list, layer2=native segseg_list, layer>=3 chan.py segment-list recursion on deepcopy input',
        'recursive_seg_bsp_policy': 'stateful seg2..segN CBSPointList results are exported separately from endpoint candidates',
        'recursive_seg_layer_rows_total': total_layer_rows,
    })
    if first_meta is not None:
        meta['recursive_seg_max_level'] = first_meta.get('max_level')
        meta['recursive_seg_generated_layers_sample'] = first_meta.get('generated_layers')
    patched['meta'] = meta
    return patched


def _recursive_timed_native_step_response(
    *,
    exporter: Any,
    chan: Any,
    kl_types: list[Any],
    level_order: list[str],
    bars_by_level: dict[str, list[dict[str, Any]]],
    data_meta: dict[str, Any],
    prepared_code: str,
    code: str,
    market_name: str,
    adjust: str,
    main: str,
    clock: str,
    config: dict[str, Any] | None,
    timing: dict[str, Any],
) -> dict[str, Any]:
    step_iter = getattr(chan, 'step_load', None)
    if not callable(step_iter):
        raise RuntimeError('native CChan(lv_list) does not expose step_load')
    max_frames = _max_step_frames(config)
    frame_buffer: deque[dict[str, Any]] = deque(maxlen=max_frames)
    total_frames = 0
    last_chan: Any | None = None
    iterator = iter(step_iter())
    recursive_states: dict[str, RecursiveSegRuntimeState] = {}
    base_bsp_histories: dict[str, dict[tuple[str, int, bool], dict[str, Any]]] = {}
    cursor = 0
    expected_frames = len(bars_by_level.get(clock, []))
    retain_from = max(0, expected_frames - max_frames)
    while True:
        iter_start = perf_counter()
        try:
            cur_chan = next(iterator)
        except StopIteration:
            _add_elapsed_ms(timing, 'backend_step_export_iter_ms', iter_start)
            break
        _add_elapsed_ms(timing, 'backend_step_export_iter_ms', iter_start)
        last_chan = cur_chan

        if cursor < retain_from:
            light_start = perf_counter()
            _advance_step_histories_light(
                exporter=exporter,
                chan=cur_chan,
                kl_types=kl_types,
                level_order=level_order,
                config=config,
                runtime_states=recursive_states,
                base_bsp_histories=base_bsp_histories,
            )
            _add_elapsed_ms(timing, 'backend_step_history_light_ms', light_start)
            total_frames += 1
            cursor += 1
            continue

        frame_start = perf_counter()
        frame = _timed_compact_snapshot_from_chan(
            exporter=exporter,
            chan=cur_chan,
            kl_types=kl_types,
            level_order=level_order,
            bars_by_level=bars_by_level,
            main=main,
            clock=clock,
            mode_name='step',
            timing=timing,
            cursor=cursor,
        )
        current_time_start = perf_counter()
        frame['meta']['current_time'] = _compact_frame_current_time(frame, main, bars_by_level)
        _add_elapsed_ms(timing, 'backend_step_export_current_time_ms', current_time_start)
        frame['meta']['frame_index'] = cursor
        frame = _attach_recursive_seg_layers(
            result=frame,
            exporter=exporter,
            chan=cur_chan,
            kl_types=kl_types,
            level_order=level_order,
            config=config,
            timing=timing,
            runtime_states=recursive_states,
            base_bsp_histories=base_bsp_histories,
        )
        frame = _compact_step_bsp_history_frame(
            frame,
            seed=cursor == retain_from,
        )
        frame_buffer.append(frame)
        total_frames += 1
        cursor += 1
        _add_elapsed_ms(timing, 'backend_step_export_frame_build_ms', frame_start)

    frames = list(frame_buffer)
    if not frames or last_chan is None:
        raise RuntimeError('native CChan(lv_list) step_load returned no frames')

    final_start = perf_counter()
    final = _snapshot_from_chan(
        exporter=exporter,
        chan=last_chan,
        kl_types=kl_types,
        level_order=level_order,
        bars_by_level=bars_by_level,
        config=config,
        main=main,
        clock=clock,
        mode_name='step',
        cursor=total_frames - 1,
    )
    final = _attach_recursive_seg_layers(
        result=final,
        exporter=exporter,
        chan=last_chan,
        kl_types=kl_types,
        level_order=level_order,
        config=config,
        timing=timing,
        runtime_states=recursive_states,
        base_bsp_histories=base_bsp_histories,
    )
    _add_elapsed_ms(timing, 'backend_step_export_final_snapshot_ms', final_start)

    meta = dict(final['meta'])
    meta.update({
        'symbol': f'{code}.{market_name}',
        'name': code,
        'adjust': adjust.upper(),
        'prepared_code': prepared_code,
        'native_step_frames': True,
        'native_step_frames_total': total_frames,
        'native_step_frames_returned': len(frames),
        'native_step_frames_limit': max_frames,
        'native_step_frames_truncated': total_frames > len(frames),
        'native_data_window': data_meta,
        'native_csv_time_policy': 'effective-time sort/dedupe; non-intraday parent levels are written to CSV at 23:59 while UI bars keep original times',
        'warnings': ['native CChan(lv_list).step_load() path is active'],
        'backend_step_export_total_frames': total_frames,
        'backend_step_export_returned_frames': len(frames),
        'step_frame_format': 'compact_v1',
        'compact_first_step_frame_export': True,
    })
    return {
        'ok': True,
        'main_level': main,
        'levels': final['levels'],
        'relations': final['relations'],
        'frames': frames,
        'meta': meta,
    }


def analyze_multi_native_timed_recursive(
    *,
    symbol: str,
    market: str | None,
    levels: list[str] | str | None,
    adjust: str = 'QFQ',
    mode: str = 'once',
    main_level: str | None = None,
    clock_level: str | None = None,
    start: str | None = None,
    end: str | None = None,
    count: int = 50000,
    config: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Timed native multi-level analysis with export-only recursive seg layers."""
    total_start = perf_counter()
    timing: dict[str, Any] = {}
    reset_easy_tdx_cache_stats()
    try:
        code = normalize_symbol(symbol)
        market_name = (market or infer_market(code)).upper()
        level_order = _normalize_levels(levels)
        main = (main_level or level_order[0]).upper()
        if main not in level_order:
            main = level_order[0]
        clock = (clock_level or main).upper()
        if clock not in level_order:
            clock = main
        mode_name = (mode or 'once').lower()

        data_start = perf_counter()
        bars_by_level, data_meta = _load_aligned_bars_by_level(
            code=code,
            market_name=market_name,
            level_order=level_order,
            adjust=adjust,
            count=count,
            start=start,
            end=end,
        )
        timing['backend_native_data_load_ms'] = _elapsed_ms(data_start)
        timing.update(_cache_timing_meta())

        prepare_start = perf_counter()
        exporter, chan, kl_types, prepared_code = _prepare_native_chan(
            code=code,
            level_order=level_order,
            bars_by_level=bars_by_level,
            adjust=adjust,
            config=config,
            trigger_step=mode_name == 'step',
        )
        timing['backend_native_prepare_chan_ms'] = _elapsed_ms(prepare_start)

        if mode_name == 'step':
            step_start = perf_counter()
            result = _recursive_timed_native_step_response(
                exporter=exporter,
                chan=chan,
                kl_types=kl_types,
                level_order=level_order,
                bars_by_level=bars_by_level,
                data_meta=data_meta,
                prepared_code=prepared_code,
                code=code,
                market_name=market_name,
                adjust=adjust,
                main=main,
                clock=clock,
                config=config,
                timing=timing,
            )
            timing['backend_native_step_export_ms'] = _elapsed_ms(step_start)
        else:
            once_start = perf_counter()
            result = _native_once_response(
                exporter=exporter,
                chan=chan,
                kl_types=kl_types,
                level_order=level_order,
                bars_by_level=bars_by_level,
                data_meta=data_meta,
                prepared_code=prepared_code,
                code=code,
                market_name=market_name,
                adjust=adjust,
                main=main,
                clock=clock,
                config=config,
            )
            result = _attach_recursive_seg_layers(
                result=result,
                exporter=exporter,
                chan=chan,
                kl_types=kl_types,
                level_order=level_order,
                config=config,
                timing=timing,
            )
            timing['backend_native_once_export_ms'] = _elapsed_ms(once_start)

        timing['backend_native_total_ms'] = _elapsed_ms(total_start)
        return _merge_timing(result, timing)
    except Exception as exc:
        timing.update(_cache_timing_meta())
        timing['backend_native_total_ms'] = _elapsed_ms(total_start)
        failure = _timed_native_failure_response(
            symbol=symbol,
            market=market,
            levels=levels,
            adjust=adjust,
            mode=mode,
            main_level=main_level,
            clock_level=clock_level,
            exc=exc,
        )
        return _merge_timing(failure, timing)
