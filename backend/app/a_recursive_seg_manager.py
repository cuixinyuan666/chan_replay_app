from __future__ import annotations

import copy
from typing import Any, Iterable


DEFAULT_RECURSIVE_SEG_MAX_LEVEL = 2


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
    cfg = config or {}
    raw = cfg.get('level_promoter_max_level')
    if raw is None:
        raw = cfg.get('recursive_seg_max_level')
    if raw is None:
        raw = cfg.get('seg_recursive_max_level')
    try:
        value = int(raw)
    except (TypeError, ValueError):
        value = DEFAULT_RECURSIVE_SEG_MAX_LEVEL
    return max(2, value)


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


def _recursive_update_layer(*, template: Any, seg_config: Any, src: Any) -> Any:
    src_copy = _deepcopy_lines(src)
    dst = _new_seg_list(template, seg_config)
    _update_seg_list(dst, src_copy)
    return dst


def _int_value(row: dict[str, Any], *keys: str) -> int | None:
    for key in keys:
        value = row.get(key)
        if value is None:
            continue
        try:
            return int(value)
        except (TypeError, ValueError):
            continue
    return None


def _float_value(row: dict[str, Any], *keys: str) -> float | None:
    for key in keys:
        value = row.get(key)
        if value is None:
            continue
        parsed = _to_float(value)
        if parsed is not None:
            return parsed
    return None


def _text_value(row: dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = row.get(key)
        if value is not None:
            return str(value)
    return ''


def _bool_value(row: dict[str, Any], *keys: str, default: bool = True) -> bool:
    for key in keys:
        value = row.get(key)
        if isinstance(value, bool):
            return value
        if value is None:
            continue
        text = str(value).strip().lower()
        if text in {'true', '1', 'yes', 'y', 'on'}:
            return True
        if text in {'false', '0', 'no', 'n', 'off'}:
            return False
    return default


def _bsp_type_for_seg(layer: int, direction: str) -> tuple[str, bool]:
    normalized = (direction or '').strip().lower()
    if 'down' in normalized:
        return f'SEG{layer}_B', True
    if 'up' in normalized:
        return f'SEG{layer}_S', False
    return f'SEG{layer}_BSP', True


def _export_seg_layer_bsp(layer: int, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Build independent segN_bsp fields from exported recursive segment endpoints.

    These rows are endpoint-derived, traceable candidates for the App level
    promoter. They are deliberately not mixed into native chan.py ``bsp`` output.
    """
    result: list[dict[str, Any]] = []
    seen: set[tuple[int, str, int]] = set()
    for fallback_index, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        raw_index = _int_value(row, 'end_raw_index', 'endRawIndex')
        price = _float_value(row, 'end_price', 'endPrice')
        if raw_index is None or price is None:
            continue
        segment_index = _int_value(row, 'index')
        if segment_index is None:
            segment_index = fallback_index
        type_text, is_buy = _bsp_type_for_seg(layer, _text_value(row, 'direction'))
        key = (raw_index, type_text, segment_index)
        if key in seen:
            continue
        seen.add(key)
        result.append({
            'index': len(result),
            'raw_index': raw_index,
            'time': row.get('end_time') or row.get('endTime'),
            'price': price,
            'type': type_text,
            'level': f'seg{layer}',
            'bi_index': None,
            'seg_index': segment_index,
            'zs_index': None,
            'confirmed': _bool_value(row, 'is_sure', 'confirmed', default=True),
            'recursive_seg_layer': layer,
            'recursive_seg_index': segment_index,
            'source': 'recursive_seg_layer_endpoint',
            'derived': True,
            'direction': _text_value(row, 'direction'),
            'is_buy': is_buy,
            'evidence_key': f'seg{layer}#{segment_index}@raw={raw_index}',
            'candidate_policy': 'segN_bsp is an independent recursive-segment endpoint candidate; native chan.py bsp remains unchanged',
        })
    return result


def _export_all_seg_layer_bsp(layers: dict[str, list[dict[str, Any]]]) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {}
    for key, rows in layers.items():
        try:
            layer = int(key)
        except (TypeError, ValueError):
            continue
        if layer < 2:
            continue
        result[str(layer)] = _export_seg_layer_bsp(layer, rows if isinstance(rows, list) else [])
    return result


class RecursiveSegManager:
    """Export recursive segment layers without modifying chan.py source code.

    Layer 1 is read from chan.py native ``seg_list``. Layer 2 prefers native
    ``segseg_list`` when it exists; otherwise it is generated by recursively
    applying the same chan.py segment-list class to a deepcopy of layer 1.
    Layers >= 3 are generated from the previous layer in the same non-polluting
    way. ``max_level`` is intentionally user-configurable and is not capped at 4,
    so the App can request 3段、4段、...、N段.
    """

    def __init__(self, max_level: int = DEFAULT_RECURSIVE_SEG_MAX_LEVEL):
        self.max_level = max(2, int(max_level))

    def _payload(self, layers: dict[str, list[dict[str, Any]]], status: dict[str, Any]) -> dict[str, Any]:
        seg_bsp_layers = _export_all_seg_layer_bsp(layers)
        result: dict[str, Any] = {
            'seg_layers': layers,
            'seg_bsp_layers': seg_bsp_layers,
            'recursive_seg_meta': status,
        }
        for layer, rows in seg_bsp_layers.items():
            result[f'seg{layer}_bsp'] = rows
        return result

    def export(self, level_obj: Any, native_seg_rows: list[dict[str, Any]] | None = None) -> dict[str, Any]:
        native_seg_list = _native_container(level_obj, ('seg_list', 'seg_lst'))
        native_segseg_list = _native_container(level_obj, ('segseg_list', 'seg_seg_list', 'segseg_lst'))
        layers: dict[str, list[dict[str, Any]]] = {}
        status: dict[str, Any] = {
            'max_level': self.max_level,
            'native_layers': ['1'],
            'generated_layers': [],
            'errors': {},
            'bsp_policy': 'seg2_bsp..segN_bsp are independent recursive segment endpoint candidates; native bsp/segbsp stay authoritative and unchanged',
            'bsp_fields_policy': 'seg_bsp_layers plus dynamic seg{N}_bsp fields are exported for every layer N >= 2',
            'layer2_policy': 'native segseg_list preferred; generated from native seg_list when segseg_list is unavailable',
            'pollution_guard': 'layers >= 2 generated paths use deepcopy input before invoking chan.py segment update(); chan.py source and native level objects are not written',
        }

        layers['1'] = list(native_seg_rows or _export_line_list(native_seg_list, layer=1, input_layer=0))
        if not layers['1']:
            layers['2'] = []
            status['errors']['1'] = 'native seg_list not available or empty; recursive promotion cannot start'
            for rest in range(3, self.max_level + 1):
                layers[str(rest)] = []
                status['errors'][str(rest)] = 'skipped because layer 1 is empty'
            return self._payload(layers, status)

        template = native_segseg_list or native_seg_list
        seg_config = _seg_config(level_obj, template)

        if native_segseg_list is not None:
            layers['2'] = _export_line_list(native_segseg_list, layer=2, input_layer=1)
            status['native_layers'].append('2')
            src = native_segseg_list
        else:
            try:
                layer2 = _recursive_update_layer(template=template, seg_config=seg_config, src=native_seg_list)
                layers['2'] = _export_line_list(layer2, layer=2, input_layer=1)
                status['generated_layers'].append('2')
                status['errors']['2_native'] = 'native segseg_list not available; layer 2 generated from native seg_list'
                src = layer2
            except Exception as exc:  # noqa: BLE001 - expose diagnostic, keep native output stable
                layers['2'] = []
                status['errors']['2'] = f'{type(exc).__name__}: {exc}'
                for rest in range(3, self.max_level + 1):
                    layers[str(rest)] = []
                    status['errors'][str(rest)] = 'skipped because recursive layer 2 generation failed'
                return self._payload(layers, status)

        if self.max_level <= 2:
            return self._payload(layers, status)

        for layer in range(3, self.max_level + 1):
            try:
                dst = _recursive_update_layer(template=template, seg_config=seg_config, src=src)
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
        return self._payload(layers, status)


def build_recursive_seg_payload(
    *,
    level_obj: Any,
    structures: dict[str, Any],
    config: dict[str, Any] | None,
) -> dict[str, Any]:
    manager = RecursiveSegManager(max_level=_max_level_from_config(config))
    native_seg_rows = structures.get('seg') if isinstance(structures.get('seg'), list) else []
    return manager.export(level_obj, native_seg_rows=native_seg_rows)
