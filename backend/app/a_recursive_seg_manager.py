from __future__ import annotations

import copy
from typing import Any, Iterable


DEFAULT_RECURSIVE_SEG_MAX_LEVEL = 4
_MAX_RECURSIVE_SEG_LEVEL = 8


def _attr(obj: Any, names: Iterable[str], default: Any = None) -> Any:
    for name in names:
        if hasattr(obj, name):
            return getattr(obj, name)
    return default


def _call_any(obj: Any, names: Iterable[str], default: Any = None) -> Any:
    for name in names:
        value = getattr(obj, name, None)
        if callable(value):
            try:
                return value()
            except TypeError:
                continue
        if value is not None:
            return value
    return default


def _as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, tuple):
        return list(value)
    try:
        return list(value)
    except TypeError:
        return []


def _to_float(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _idx(obj: Any) -> int | None:
    value = _attr(obj, ('idx', 'index', 'klu_idx', 'id'), None)
    return value if isinstance(value, int) else None


def _time(obj: Any) -> str | None:
    value = _attr(obj, ('time', 'time_begin', 'date', 'dt'), None)
    return None if value is None else str(value)


def _line_direction(line: Any) -> str:
    direction = str(_attr(line, ('dir', 'direction', 'bi_dir'), '')).lower()
    if 'up' in direction:
        return 'up'
    if 'down' in direction:
        return 'down'
    is_up = getattr(line, 'is_up', None)
    if callable(is_up):
        try:
            if is_up():
                return 'up'
        except TypeError:
            pass
    is_down = getattr(line, 'is_down', None)
    if callable(is_down):
        try:
            if is_down():
                return 'down'
        except TypeError:
            pass
    return direction


def _begin_line(line: Any) -> Any:
    return _attr(line, ('start_bi', 'begin_bi', 'start_seg', 'begin_seg', 'begin', 'start'), None)


def _end_line(line: Any) -> Any:
    return _attr(line, ('end_bi', 'end_seg', 'end'), None)


def _export_line_list(lines: Any, *, layer: int, input_layer: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for i, line in enumerate(_as_list(lines)):
        begin_line = _begin_line(line)
        end_line = _end_line(line)
        begin_klu = _call_any(line, ('get_begin_klu',), None)
        end_klu = _call_any(line, ('get_end_klu',), None)
        rows.append({
            'index': _idx(line) if _idx(line) is not None else i,
            'layer': layer,
            'input_layer': input_layer,
            'start_parent_index': _idx(begin_line),
            'end_parent_index': _idx(end_line),
            'start_raw_index': _idx(begin_klu),
            'end_raw_index': _idx(end_klu),
            'start_time': _time(begin_klu),
            'end_time': _time(end_klu),
            'start_price': _to_float(_call_any(line, ('get_begin_val',), None)),
            'end_price': _to_float(_call_any(line, ('get_end_val',), None)),
            'direction': _line_direction(line),
            'is_sure': bool(_attr(line, ('is_sure', 'confirmed'), True)),
            'repr': repr(line),
        })
    return rows


def _max_level_from_config(config: dict[str, Any] | None) -> int:
    raw = (config or {}).get('recursive_seg_max_level')
    if raw is None:
        raw = (config or {}).get('seg_recursive_max_level')
    try:
        value = int(raw)
    except (TypeError, ValueError):
        value = DEFAULT_RECURSIVE_SEG_MAX_LEVEL
    return max(2, min(_MAX_RECURSIVE_SEG_LEVEL, value))


def _native_container(level_obj: Any, names: Iterable[str]) -> Any:
    for name in names:
        value = _attr(level_obj, (name,), None)
        if value is not None:
            return value
    return None


def _seg_config(level_obj: Any, template: Any) -> Any:
    config = _attr(template, ('config', 'seg_config', 'seg_conf'), None)
    if config is not None:
        return config
    chan_config = _attr(level_obj, ('config', 'conf'), None)
    return _attr(chan_config, ('seg_conf', 'seg_config'), None)


def _seg_type_seg() -> Any:
    try:
        from Common.CEnum import SEG_TYPE  # type: ignore

        return getattr(SEG_TYPE, 'SEG')
    except Exception:  # noqa: BLE001 - optional external chan.py dependency
        return None


def _new_seg_list(template: Any, seg_config: Any) -> Any:
    cls = type(template)
    seg_lv = _seg_type_seg()
    attempts: list[tuple[tuple[Any, ...], dict[str, Any]]] = []
    if seg_config is not None and seg_lv is not None:
        attempts.append(((), {'seg_config': seg_config, 'lv': seg_lv}))
        attempts.append(((seg_config, seg_lv), {}))
    if seg_config is not None:
        attempts.append(((), {'seg_config': seg_config}))
        attempts.append(((seg_config,), {}))
    attempts.append(((), {}))

    last_error: Exception | None = None
    for args, kwargs in attempts:
        try:
            return cls(*args, **kwargs)
        except Exception as exc:  # noqa: BLE001 - reflection compatibility path
            last_error = exc
    if last_error is not None:
        raise last_error
    return None


def _deepcopy_lines(lines: Any) -> Any:
    return copy.deepcopy(lines)


def _update_seg_list(dst: Any, src: Any) -> None:
    update = getattr(dst, 'update', None)
    if not callable(update):
        raise TypeError(f'{type(dst).__name__} does not expose update()')
    update(src)


class RecursiveSegManager:
    """Export recursive segment layers without modifying chan.py source code.

    Layer 1 and layer 2 are read from chan.py native ``seg_list`` and
    ``segseg_list``. Layers >= 3 are best-effort recursive applications of the
    same chan.py segment-list class, using a deepcopy of the previous layer as
    the input so App export does not write parent/seg indexes back into the
    native level object.
    """

    def __init__(self, max_level: int = DEFAULT_RECURSIVE_SEG_MAX_LEVEL):
        self.max_level = max(2, min(_MAX_RECURSIVE_SEG_LEVEL, int(max_level)))

    def export(self, level_obj: Any, native_seg_rows: list[dict[str, Any]] | None = None) -> dict[str, Any]:
        native_seg_list = _native_container(level_obj, ('seg_list', 'seg_lst'))
        native_segseg_list = _native_container(level_obj, ('segseg_list', 'seg_seg_list', 'segseg_lst'))
        layers: dict[str, list[dict[str, Any]]] = {}
        status: dict[str, Any] = {
            'max_level': self.max_level,
            'native_layers': ['1'],
            'generated_layers': [],
            'errors': {},
            'bsp_policy': 'recursive segment layers do not generate BSP; native bsp/segbsp stay authoritative',
            'pollution_guard': 'layers >= 3 use deepcopy input before invoking chan.py segment update()',
        }

        layers['1'] = list(native_seg_rows or _export_line_list(native_seg_list, layer=1, input_layer=0))
        if native_segseg_list is None:
            layers['2'] = []
            status['errors']['2'] = 'native segseg_list not available on level object'
            return {'seg_layers': layers, 'recursive_seg_meta': status}

        layers['2'] = _export_line_list(native_segseg_list, layer=2, input_layer=1)
        status['native_layers'].append('2')

        if self.max_level <= 2:
            return {'seg_layers': layers, 'recursive_seg_meta': status}

        template = native_segseg_list or native_seg_list
        seg_config = _seg_config(level_obj, template)
        src = native_segseg_list
        for layer in range(3, self.max_level + 1):
            try:
                src_copy = _deepcopy_lines(src)
                dst = _new_seg_list(template, seg_config)
                _update_seg_list(dst, src_copy)
                layers[str(layer)] = _export_line_list(dst, layer=layer, input_layer=layer - 1)
                status['generated_layers'].append(str(layer))
                src = dst
            except Exception as exc:  # noqa: BLE001 - expose diagnostic, keep native output stable
                layers[str(layer)] = []
                status['errors'][str(layer)] = f'{type(exc).__name__}: {exc}'
                for rest in range(layer + 1, self.max_level + 1):
                    layers[str(rest)] = []
                    status['errors'][str(rest)] = 'skipped because previous recursive layer failed'
                break
        return {'seg_layers': layers, 'recursive_seg_meta': status}


def build_recursive_seg_payload(
    *,
    level_obj: Any,
    structures: dict[str, Any],
    config: dict[str, Any] | None,
) -> dict[str, Any]:
    manager = RecursiveSegManager(max_level=_max_level_from_config(config))
    native_seg_rows = structures.get('seg') if isinstance(structures.get('seg'), list) else []
    return manager.export(level_obj, native_seg_rows=native_seg_rows)
