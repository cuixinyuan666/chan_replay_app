from __future__ import annotations

import copy
import re
from typing import Any, Iterable


DEFAULT_RECURSIVE_SEG_MAX_LEVEL = 2


def custom_seg_level_num(level: Any) -> int | None:
    """Return the recursive segment level number for segseg/seg3..segN labels."""
    text = str(level or '').strip().lower()
    if text == 'segseg':
        return 2
    matched = re.fullmatch(r'seg(\d+)', text)
    if matched is None:
        return None
    value = int(matched.group(1))
    return value if value >= 3 else None


def seg_level_id(num: int) -> str:
    value = int(num)
    return 'segseg' if value == 2 else f'seg{value}'


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


def _begin_klu(line: Any) -> Any:
    return _call_any(line, ('get_begin_klu',), None)


def _end_klu(line: Any) -> Any:
    return _call_any(line, ('get_end_klu',), None)


def _export_line_list(lines: Any, *, layer: int, input_layer: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for i, line in enumerate(_as_list(lines)):
        begin_line = _begin_line(line)
        end_line = _end_line(line)
        begin_klu = _begin_klu(line)
        end_klu = _end_klu(line)
        rows.append({
            'index': _idx(line) if _idx(line) is not None else i,
            'layer': layer,
            'level': seg_level_id(layer) if layer >= 2 else 'seg',
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


def _max_extra_level_needed(config: dict[str, Any] | None, visible_max_level: int) -> int:
    """Need one hidden upper layer to calculate ZS/BSP for the visible max layer."""
    cfg = config or {}
    raw = cfg.get('recursive_seg_internal_max_level') or cfg.get('seg_recursive_internal_max_level')
    try:
        configured = int(raw)
    except (TypeError, ValueError):
        configured = int(visible_max_level) + 1
    return max(3, int(visible_max_level) + 1, configured)


def _native_container(level_obj: Any, names: Iterable[str]) -> Any:
    for name in names:
        value = _attr(level_obj, (name,), None)
        if value is not None:
            return value
    return None


def _chan_config(level_obj: Any) -> Any:
    config = _attr(level_obj, ('config', 'conf'), None)
    if config is not None:
        return config
    owner = _attr(level_obj, ('chan', 'parent', 'owner'), None)
    return _attr(owner, ('config', 'conf'), None)


def _empty_zs_list(zs_conf: Any) -> Any:
    from ZS.ZSList import CZSList  # type: ignore

    return CZSList(zs_config=zs_conf)


def _empty_bsp_list(bsp_conf: Any) -> Any:
    from BuySellPoint.BSPointList import CBSPointList  # type: ignore

    return CBSPointList(bs_point_config=bsp_conf)


def build_level_zs(base_lines: Any, upper_lines: Any, zs_conf: Any) -> Any:
    """Calculate ZS for one recursive level using chan.py CZSList."""
    from KLine.KLine_List import update_zs_in_seg  # type: ignore
    from ZS.ZSList import CZSList  # type: ignore

    zs_list = CZSList(zs_config=zs_conf)
    zs_list.cal_bi_zs(base_lines, upper_lines)
    update_zs_in_seg(base_lines, upper_lines, zs_list)
    return zs_list


def build_level_bsp(base_lines: Any, upper_lines: Any, bsp_conf: Any) -> Any:
    """Calculate BSP for one recursive level using chan.py CBSPointList."""
    from BuySellPoint.BSPointList import CBSPointList  # type: ignore

    bsp_list = CBSPointList(bs_point_config=bsp_conf)
    bsp_list.cal(base_lines, upper_lines)
    return bsp_list


def ensure_recursive_seg_klc_anchors(line: Any) -> None:
    """Give CSeg[CSeg] enough begin_klc/end_klc anchors for chan.py cal_seg."""
    if line is None:
        return
    start = _attr(line, ('start_bi', 'begin_bi', 'start_seg', 'begin_seg', 'begin', 'start'), None)
    end = _attr(line, ('end_bi', 'end_seg', 'end'), None)
    if start is None or end is None:
        return
    ensure_recursive_seg_klc_anchors(start)
    ensure_recursive_seg_klc_anchors(end)
    begin_klc = _attr(start, ('begin_klc',), None)
    end_klc = _attr(end, ('end_klc',), None)
    if begin_klc is not None:
        try:
            line.begin_klc = begin_klc
        except Exception:  # noqa: BLE001
            pass
    if end_klc is not None:
        try:
            line.end_klc = end_klc
        except Exception:  # noqa: BLE001
            pass


def prepare_recursive_seg_source(source_lines: Any) -> None:
    for line in _as_list(source_lines):
        ensure_recursive_seg_klc_anchors(line)


def build_hidden_seg_layer(source_lines: Any, conf: Any) -> Any:
    """Classic chan.py recursion: apply cal_seg to the previous segment layer."""
    from Common.CEnum import SEG_TYPE  # type: ignore
    from KLine.KLine_List import cal_seg, get_seglist_instance  # type: ignore

    hidden_seg_list = get_seglist_instance(seg_config=conf.seg_conf, lv=SEG_TYPE.SEG)
    prepare_recursive_seg_source(source_lines)
    cal_seg(source_lines, hidden_seg_list, -1)
    return hidden_seg_list


def build_extra_seg_chain(base_segseg: Any, conf: Any, max_extra_level: int) -> dict[str, Any]:
    """Build seg3..segN with chan.py cal_seg, starting from native segseg."""
    if int(max_extra_level) < 3:
        return {}
    out: dict[str, Any] = {}
    prev = base_segseg
    for level_num in range(3, int(max_extra_level) + 1):
        level = seg_level_id(level_num)
        prev = build_hidden_seg_layer(prev, conf)
        out[level] = prev
    return out


def build_extra_zs_and_bsp(
    extra_lines: dict[str, Any],
    conf: Any,
    *,
    min_level: int = 2,
    max_level: int,
) -> tuple[dict[str, Any], dict[str, Any]]:
    """Build segN_zs/segN_bsp for visible recursive levels with upper parent lines."""
    extra_zs: dict[str, Any] = {}
    extra_bsp: dict[str, Any] = {}
    for level_num in range(max(2, int(min_level)), int(max_level) + 1):
        level = seg_level_id(level_num)
        upper = extra_lines.get(seg_level_id(level_num + 1))
        base = extra_lines.get(level)
        if base is None or upper is None:
            continue
        extra_zs[level] = build_level_zs(base, upper, conf.zs_conf)
        extra_bsp[level] = build_level_bsp(base, upper, conf.seg_bs_point_conf)
    return extra_zs, extra_bsp


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


def _bsp_container_items(container: Any) -> list[Any]:
    if container is None:
        return []
    for method_name in ('getSortedBspList', 'get_latest_bsp', 'bsp_iter', 'bsp_iter_v2'):
        method = getattr(container, method_name, None)
        if not callable(method):
            continue
        try:
            rows = method(0) if method_name == 'get_latest_bsp' else method()
        except TypeError:
            continue
        rows = _as_list(rows)
        if rows:
            return rows
    return _as_list(container)


def _bsp_type_text(item: Any, is_buy: bool) -> str:
    type2str = getattr(item, 'type2str', None)
    if callable(type2str):
        try:
            text = str(type2str())
        except TypeError:
            text = ''
    else:
        raw = _attr(item, ('type', 'bsp_type', 'bs_type', 'name'), '')
        if isinstance(raw, list):
            text = ','.join(str(getattr(x, 'value', x)) for x in raw)
        else:
            text = str(getattr(raw, 'value', raw))
    prefix = 'B' if is_buy else 'S'
    return f'{prefix}{text or "SP"}'


def _bsp_price(item: Any, klu: Any, line: Any, is_buy: bool) -> float | None:
    if klu is not None:
        klu_price = _to_float(_attr(klu, ('low', 'close'), None)) if is_buy else _to_float(_attr(klu, ('high', 'close'), None))
        if klu_price is not None:
            return klu_price
    direct = _to_float(_attr(item, ('price', 'val', 'value'), None))
    if direct is not None:
        return direct
    return _to_float(_call_any(line, ('get_end_val',), None)) if line is not None else None


def _export_bsp_list(bsp_list: Any, *, layer: int) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[tuple[int, str, int | None]] = set()
    for item in _bsp_container_items(bsp_list):
        line = _attr(item, ('bi', 'seg', 'relate_bi', 'related_bi'), None)
        klu = _attr(item, ('klu', 'kl', 'point', 'kline'), None) or _call_any(item, ('get_klu',), None)
        if klu is None and line is not None:
            klu = _call_any(line, ('get_end_klu',), None)
        is_buy = bool(_attr(item, ('is_buy',), False))
        raw_index = _idx(klu)
        price = _bsp_price(item, klu, line, is_buy)
        if raw_index is None or price is None:
            continue
        type_text = _bsp_type_text(item, is_buy)
        line_index = _idx(line)
        key = (raw_index, type_text, line_index)
        if key in seen:
            continue
        seen.add(key)
        result.append({
            'index': len(result),
            'raw_index': raw_index,
            'time': _time(klu),
            'price': price,
            'type': type_text,
            'level': seg_level_id(layer),
            'bi_index': None,
            'seg_index': line_index,
            'zs_index': None,
            'confirmed': bool(_attr(item, ('is_sure', 'confirmed'), True)),
            'recursive_seg_layer': layer,
            'recursive_seg_index': line_index,
            'source': 'recursive_seg_bsp',
            'derived': False,
            'is_buy': is_buy,
            'repr': repr(item),
        })
    return sorted(result, key=lambda row: (row['raw_index'], row['type']))


def _export_zs_list(zs_list: Any, *, layer: int) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for i, zs in enumerate(_as_list(zs_list)):
        begin_line = _attr(zs, ('begin_bi', 'start_bi', 'bi_in'), None)
        end_line = _attr(zs, ('end_bi', 'bi_out'), None)
        begin = _begin_klu(begin_line) or _attr(zs, ('begin',), None)
        end = _end_klu(end_line) or _attr(zs, ('end',), None)
        is_one_bi_zs = False
        fn = getattr(zs, 'is_one_bi_zs', None)
        if callable(fn):
            try:
                is_one_bi_zs = bool(fn())
            except TypeError:
                is_one_bi_zs = False
        result.append({
            'index': _idx(zs) if _idx(zs) is not None else i,
            'level': seg_level_id(layer),
            'start_parent_index': _idx(begin_line),
            'end_parent_index': _idx(end_line),
            'start_raw_index': _idx(begin),
            'end_raw_index': _idx(end),
            'zg': _to_float(_attr(zs, ('high', 'zg'), None)),
            'zd': _to_float(_attr(zs, ('low', 'zd'), None)),
            'gg': _to_float(_attr(zs, ('peak_high', 'gg'), None)),
            'dd': _to_float(_attr(zs, ('peak_low', 'dd'), None)),
            'high': _to_float(_attr(zs, ('high', 'zg'), None)),
            'low': _to_float(_attr(zs, ('low', 'zd'), None)),
            'is_sure': bool(_attr(zs, ('is_sure', 'confirmed'), True)),
            'is_one_bi_zs': is_one_bi_zs,
            'recursive_seg_layer': layer,
            'source': 'recursive_seg_zs',
            'repr': repr(zs),
        })
    return result


def _bsp_type_for_seg(layer: int, direction: str) -> tuple[str, bool]:
    normalized = (direction or '').strip().lower()
    if 'down' in normalized:
        return f'SEG{layer}_B', True
    if 'up' in normalized:
        return f'SEG{layer}_S', False
    return f'SEG{layer}_BSP', True


def _export_seg_layer_endpoint_bsp(layer: int, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Compatibility endpoint candidates; real recursive BSP is exported separately."""
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
            'level': seg_level_id(layer),
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
            'candidate_policy': 'endpoint candidate kept for compatibility; seg_bsp_layers contains chan.py CBSPointList.cal output when available',
        })
    return result


def _export_all_endpoint_bsp(layers: dict[str, list[dict[str, Any]]], max_level: int) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {}
    for level in range(2, int(max_level) + 1):
        rows = layers.get(str(level), [])
        result[str(level)] = _export_seg_layer_endpoint_bsp(level, rows if isinstance(rows, list) else [])
    return result


class RecursiveSegRuntimeState:
    """Persistent seg2..segN calculation state shared by replay frames.

    Native chan.py already keeps incremental state for seg1/seg2. This object
    extends the same contract to higher recursive layers and preserves each
    layer's last confirmed boundary, ZS list and CBSPointList across step frames.
    """

    def __init__(self, max_level: int = DEFAULT_RECURSIVE_SEG_MAX_LEVEL, config: dict[str, Any] | None = None):
        self.max_level = max(2, int(max_level))
        self.internal_max_level = _max_extra_level_needed(config, self.max_level)
        self.conf: Any | None = None
        self.line_objects: dict[int, Any] = {}
        self.last_sure_seg_start: dict[int, int] = {}
        self.zs_objects: dict[int, Any] = {}
        self.bsp_objects: dict[int, Any] = {}
        self.bsp_history: dict[int, dict[tuple[int, bool], dict[str, Any]]] = {}
        self.bsp_delta: dict[int, list[dict[str, Any]]] = {}
        self.errors: dict[str, str] = {}
        self.update_count = 0

    def capture_bsp_history(
        self,
        *,
        layer: int,
        rows: list[dict[str, Any]],
        recognized_raw_index: int | None,
        recognized_time: str | None,
        materialize: bool = True,
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
        history = self.bsp_history.setdefault(layer, {})
        delta: list[dict[str, Any]] = []
        if recognized_raw_index is not None:
            for row in rows:
                anchor = _int_value(row, 'anchor_raw_index', 'raw_index', 'rawIndex')
                if anchor is None:
                    continue
                key = (anchor, bool(row.get('is_buy', False)))
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
                    'first_recognition': True,
                    'as_of_step': True,
                    'source': 'recursive_seg_bsp_step_history',
                })
                history[key] = frozen
                delta.append(dict(frozen))
        self.bsp_delta[layer] = delta
        if not materialize:
            return [], delta
        ordered = sorted(
            (dict(row) for row in history.values()),
            key=lambda row: (
                _int_value(row, 'recognized_raw_index', 'raw_index') or -1,
                _int_value(row, 'anchor_raw_index') or -1,
                str(row.get('type') or ''),
            ),
        )
        for index, row in enumerate(ordered):
            row['index'] = index
        return ordered, delta

    def _new_seg_list(self) -> Any:
        from Common.CEnum import SEG_TYPE  # type: ignore
        from KLine.KLine_List import get_seglist_instance  # type: ignore

        return get_seglist_instance(seg_config=self.conf.seg_conf, lv=SEG_TYPE.SEG)

    def _record_error(self, key: str, exc: Exception) -> None:
        self.errors[key] = f'{type(exc).__name__}: {exc}'

    def _update_recursive_lines(self) -> None:
        from KLine.KLine_List import cal_seg  # type: ignore

        for level_num in range(3, self.internal_max_level + 1):
            source = self.line_objects.get(level_num - 1)
            if source is None:
                break
            target = self.line_objects.get(level_num)
            if target is None:
                target = self._new_seg_list()
                self.line_objects[level_num] = target
                self.last_sure_seg_start[level_num] = -1
            try:
                prepare_recursive_seg_source(source)
                self.last_sure_seg_start[level_num] = cal_seg(
                    source,
                    target,
                    self.last_sure_seg_start.get(level_num, -1),
                )
                self.errors.pop(f'seg{level_num}', None)
            except Exception as exc:  # noqa: BLE001 - preserve last valid state and report it
                self._record_error(f'seg{level_num}', exc)
                break

    def _update_zs_and_bsp(self) -> None:
        from KLine.KLine_List import update_zs_in_seg  # type: ignore

        for level_num in range(2, self.max_level + 1):
            base = self.line_objects.get(level_num)
            upper = self.line_objects.get(level_num + 1)
            if base is None or upper is None:
                continue

            zs_list = self.zs_objects.get(level_num)
            if zs_list is None:
                zs_list = _empty_zs_list(self.conf.zs_conf)
                self.zs_objects[level_num] = zs_list
            try:
                zs_list.cal_bi_zs(base, upper)
                update_zs_in_seg(base, upper, zs_list)
                self.errors.pop(f'seg{level_num}_zs', None)
            except Exception as exc:  # noqa: BLE001 - retain prior confirmed state and report it
                self._record_error(f'seg{level_num}_zs', exc)

            bsp_list = self.bsp_objects.get(level_num)
            if bsp_list is None:
                bsp_list = _empty_bsp_list(self.conf.seg_bs_point_conf)
                self.bsp_objects[level_num] = bsp_list
            try:
                bsp_list.cal(base, upper)
                self.errors.pop(f'seg{level_num}_bsp', None)
            except Exception as exc:  # noqa: BLE001 - retain prior confirmed state and report it
                self._record_error(f'seg{level_num}_bsp', exc)

    def update(self, level_obj: Any) -> None:
        self.conf = _chan_config(level_obj)
        if self.conf is None:
            self.errors['config'] = 'level object does not expose chan.py config/conf'
            return
        self.errors.pop('config', None)

        native_seg = _native_container(level_obj, ('seg_list', 'seg_lst'))
        native_segseg = _native_container(level_obj, ('segseg_list', 'seg_seg_list', 'segseg_lst'))
        self.line_objects[1] = native_seg if native_seg is not None else []
        if native_segseg is not None:
            self.line_objects[2] = native_segseg
        else:
            layer2 = self.line_objects.get(2)
            if layer2 is None:
                layer2 = self._new_seg_list()
                self.line_objects[2] = layer2
                self.last_sure_seg_start[2] = -1
            try:
                from KLine.KLine_List import cal_seg  # type: ignore

                prepare_recursive_seg_source(self.line_objects[1])
                self.last_sure_seg_start[2] = cal_seg(
                    self.line_objects[1],
                    layer2,
                    self.last_sure_seg_start.get(2, -1),
                )
                self.errors.pop('seg2', None)
            except Exception as exc:  # noqa: BLE001
                self._record_error('seg2', exc)

        self._update_recursive_lines()
        self._update_zs_and_bsp()
        self.update_count += 1


class RecursiveSegManager:
    """Export classic chan.py recursive segment, ZS, and BSP layers.

    Layer 1 is native seg_list. Layer 2 prefers native segseg_list. Layers >= 3
    are generated by recursively applying chan.py cal_seg to the previous layer.
    ZS and BSP for seg2..segN use CZSList.cal_bi_zs and CBSPointList.cal with
    the same CChanConfig zs_conf / seg_bs_point_conf.
    """

    def __init__(
        self,
        max_level: int = DEFAULT_RECURSIVE_SEG_MAX_LEVEL,
        *,
        runtime_state: RecursiveSegRuntimeState | None = None,
        config: dict[str, Any] | None = None,
    ):
        self.max_level = max(2, int(max_level))
        self.internal_max_level = self.max_level + 1
        self.track_step_history = runtime_state is not None
        self.runtime_state = runtime_state or RecursiveSegRuntimeState(self.max_level, config)

    def _payload(
        self,
        *,
        line_rows: dict[str, list[dict[str, Any]]],
        hidden_line_rows: dict[str, list[dict[str, Any]]],
        zs_rows: dict[str, list[dict[str, Any]]],
        bsp_rows: dict[str, list[dict[str, Any]]],
        bsp_history_rows: dict[str, list[dict[str, Any]]],
        bsp_delta_rows: dict[str, list[dict[str, Any]]],
        status: dict[str, Any],
    ) -> dict[str, Any]:
        endpoint_bsp_layers = _export_all_endpoint_bsp(line_rows, self.max_level)
        result: dict[str, Any] = {
            'seg_layers': line_rows,
            'seg_hidden_layers': hidden_line_rows,
            'seg_zs_layers': zs_rows,
            'seg_bsp_layers': bsp_rows,
            'seg_bsp_history_layers': bsp_history_rows,
            'seg_bsp_delta_layers': bsp_delta_rows,
            'seg_endpoint_bsp_layers': endpoint_bsp_layers,
            'recursive_seg_meta': status,
        }
        for layer, rows in zs_rows.items():
            result[f'seg{layer}_zs'] = rows
        for layer, rows in bsp_rows.items():
            result[f'seg{layer}_bsp'] = rows
        for layer, rows in endpoint_bsp_layers.items():
            result[f'seg{layer}_endpoint_bsp'] = rows
        return result

    def export(
        self,
        level_obj: Any,
        native_seg_rows: list[dict[str, Any]] | None = None,
        *,
        recognized_raw_index: int | None = None,
        recognized_time: str | None = None,
    ) -> dict[str, Any]:
        state = self.runtime_state
        state.update(level_obj)
        self.internal_max_level = state.internal_max_level
        line_rows: dict[str, list[dict[str, Any]]] = {}
        hidden_line_rows: dict[str, list[dict[str, Any]]] = {}
        native_segseg = _native_container(level_obj, ('segseg_list', 'seg_seg_list', 'segseg_lst'))

        line_rows['1'] = list(
            native_seg_rows
            or _export_line_list(state.line_objects.get(1), layer=1, input_layer=0)
        )
        for level_num in range(2, self.internal_max_level + 1):
            rows = _export_line_list(
                state.line_objects.get(level_num),
                layer=level_num,
                input_layer=level_num - 1,
            )
            if level_num <= self.max_level:
                line_rows[str(level_num)] = rows
            else:
                hidden_line_rows[str(level_num)] = rows

        zs_rows = {
            str(level_num): _export_zs_list(state.zs_objects.get(level_num), layer=level_num)
            for level_num in range(2, self.max_level + 1)
        }
        bsp_rows = {
            str(level_num): _export_bsp_list(state.bsp_objects.get(level_num), layer=level_num)
            for level_num in range(2, self.max_level + 1)
        }
        if self.track_step_history:
            bsp_history_rows: dict[str, list[dict[str, Any]]] = {}
            bsp_delta_rows: dict[str, list[dict[str, Any]]] = {}
            for level_num in range(2, self.max_level + 1):
                history, delta = state.capture_bsp_history(
                    layer=level_num,
                    rows=bsp_rows.get(str(level_num), []),
                    recognized_raw_index=recognized_raw_index,
                    recognized_time=recognized_time,
                )
                bsp_history_rows[str(level_num)] = history
                bsp_delta_rows[str(level_num)] = delta
        else:
            bsp_history_rows = {}
            bsp_delta_rows = {}
        status: dict[str, Any] = {
            'max_level': self.max_level,
            'internal_max_level': self.internal_max_level,
            'native_layers': ['1', *(['2'] if native_segseg is not None else [])],
            'generated_layers': [
                str(level_num)
                for level_num in range(2 if native_segseg is None else 3, self.max_level + 1)
            ],
            'hidden_layers': [
                str(level_num)
                for level_num in range(self.max_level + 1, self.internal_max_level + 1)
            ],
            'errors': dict(state.errors),
            'classic_recursive_enabled': state.conf is not None,
            'stateful_incremental': True,
            'step_history_enabled': self.track_step_history,
            'bsp_history_policy': 'same layer/anchor/side freezes first recognized label; anchor and recognized raw indexes are both retained',
            'state_update_count': state.update_count,
            'last_sure_seg_start': {
                str(level): value
                for level, value in sorted(state.last_sure_seg_start.items())
            },
            'last_sure_zs_pos': {
                str(level): int(getattr(value, 'last_sure_pos', -1))
                for level, value in sorted(state.zs_objects.items())
            },
            'last_sure_zs_seg_idx': {
                str(level): int(getattr(value, 'last_seg_idx', 0))
                for level, value in sorted(state.zs_objects.items())
            },
            'last_sure_bsp_pos': {
                str(level): int(getattr(value, 'last_sure_pos', -1))
                for level, value in sorted(state.bsp_objects.items())
            },
            'last_sure_bsp_seg_idx': {
                str(level): int(getattr(value, 'last_sure_seg_idx', 0))
                for level, value in sorted(state.bsp_objects.items())
            },
            'line_policy': 'layer1=native seg_list, layer2=native segseg_list when available, layer>=3=chan.py cal_seg(previous_layer)',
            'zs_policy': 'seg2_zs..segN_zs are calculated by CZSList.cal_bi_zs(base_layer, upper_layer) with conf.zs_conf',
            'bsp_policy': 'seg2_bsp..segN_bsp are calculated by CBSPointList.cal(base_layer, upper_layer) with conf.seg_bs_point_conf',
            'endpoint_candidate_policy': 'old endpoint-derived candidates are kept under seg_endpoint_bsp_layers / seg{N}_endpoint_bsp only',
        }
        status['seg_zs_layer_counts'] = {key: len(rows) for key, rows in zs_rows.items()}
        status['seg_bsp_layer_counts'] = {key: len(rows) for key, rows in bsp_rows.items()}
        status['seg_bsp_history_layer_counts'] = {
            key: len(rows) for key, rows in bsp_history_rows.items()
        }
        status['seg_bsp_delta_layer_counts'] = {
            key: len(rows) for key, rows in bsp_delta_rows.items()
        }
        return self._payload(
            line_rows=line_rows,
            hidden_line_rows=hidden_line_rows,
            zs_rows=zs_rows,
            bsp_rows=bsp_rows,
            bsp_history_rows=bsp_history_rows,
            bsp_delta_rows=bsp_delta_rows,
            status=status,
        )


def build_recursive_seg_payload(
    *,
    level_obj: Any,
    structures: dict[str, Any],
    config: dict[str, Any] | None,
    runtime_state: RecursiveSegRuntimeState | None = None,
    recognized_raw_index: int | None = None,
    recognized_time: str | None = None,
) -> dict[str, Any]:
    manager = RecursiveSegManager(
        max_level=_max_level_from_config(config),
        runtime_state=runtime_state,
        config=config,
    )
    native_seg_rows = structures.get('seg') if isinstance(structures.get('seg'), list) else []
    return manager.export(
        level_obj,
        native_seg_rows=native_seg_rows,
        recognized_raw_index=recognized_raw_index,
        recognized_time=recognized_time,
    )
