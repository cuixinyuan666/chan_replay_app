from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any


RHYTHM_RATIO = 1.382
RHYTHM_CALC_MODE_TRANSITION = 'transition'
RHYTHM_CALC_MODE_STRICT_1382 = 'strict1382'
RHYTHM_CALC_MODES = {
    RHYTHM_CALC_MODE_TRANSITION,
    RHYTHM_CALC_MODE_STRICT_1382,
}
RHYTHM_SOURCE_LABELS = {
    'fx': '分型',
    'fract': '分型',
    'bi': '笔',
    'seg': '线段',
    'segseg': '二段',
}


@dataclass(frozen=True)
class _Line:
    level: str
    index: int
    begin_x: int
    end_x: int
    begin_val: float
    end_val: float
    direction: str


def _to_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _to_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _finite(value: Any) -> bool:
    try:
        return math.isfinite(float(value))
    except (TypeError, ValueError):
        return False


def _enabled(config: dict[str, Any] | None) -> bool:
    raw = (config or {}).get('enable_rhythm_1382', True)
    if isinstance(raw, bool):
        return raw
    return str(raw).strip().lower() not in {'0', 'false', 'no', 'off'}


def _calc_mode(config: dict[str, Any] | None) -> str:
    value = str((config or {}).get('rhythm_calc_mode') or RHYTHM_CALC_MODE_STRICT_1382).strip()
    if value == 'normal' or value not in RHYTHM_CALC_MODES:
        return RHYTHM_CALC_MODE_STRICT_1382
    return value


def _deprecated_calc_mode_note(config: dict[str, Any] | None) -> str:
    value = str((config or {}).get('rhythm_calc_mode') or '').strip()
    if value == 'normal':
        return 'normal is deprecated; treated as strict1382'
    if value and value not in RHYTHM_CALC_MODES:
        return f'{value} is invalid; treated as strict1382'
    return ''


def _level_label(level: str) -> str:
    return RHYTHM_SOURCE_LABELS.get(level, level)


def _bar_time(row: Any) -> str:
    if not isinstance(row, dict):
        return ''
    return str(row.get('dt') or row.get('datetime') or row.get('time') or row.get('date') or '')


def _bar_high(row: Any) -> float | None:
    if not isinstance(row, dict):
        return None
    value = row.get('high') if 'high' in row else row.get('h')
    return None if value is None else _to_float(value)


def _bar_low(row: Any) -> float | None:
    if not isinstance(row, dict):
        return None
    value = row.get('low') if 'low' in row else row.get('l')
    return None if value is None else _to_float(value)


def _raw(row: dict[str, Any], *keys: str, default: int = -1) -> int:
    for key in keys:
        value = row.get(key)
        if value is not None:
            return _to_int(value, default)
    return default


def _price(row: dict[str, Any], *keys: str) -> float | None:
    for key in keys:
        value = row.get(key)
        if value is not None:
            return _to_float(value)
    return None


def _direction(start_val: float, end_val: float, raw: Any = None) -> str:
    text = str(raw or '').strip().lower()
    if 'up' in text or '上' in text:
        return 'UP'
    if 'down' in text or '下' in text:
        return 'DOWN'
    return 'UP' if end_val >= start_val else 'DOWN'


def _opposite(direction: str) -> str:
    return 'DOWN' if direction == 'UP' else 'UP'


def _line_key(level: str, line: _Line) -> str:
    return f'{level}|{line.index}|{line.begin_x}|{line.end_x}|{line.direction}'


def _ratio_text(value: float) -> str:
    text = f'{value:.3f}'
    return text.rstrip('0').rstrip('.') if '.' in text else text


def _line_from_row(row: Any, level: str, seq: int) -> _Line | None:
    if not isinstance(row, dict):
        return None
    begin_x = _raw(row, 'start_raw_index', 'startRawIndex', 'x1')
    end_x = _raw(row, 'end_raw_index', 'endRawIndex', 'x2')
    begin_val = _price(row, 'start_price', 'startPrice', 'y1')
    end_val = _price(row, 'end_price', 'endPrice', 'y2')
    if begin_x < 0 or end_x < 0 or begin_x == end_x or begin_val is None or end_val is None:
        return None
    return _Line(
        level=level,
        index=_to_int(row.get('index'), seq),
        begin_x=begin_x,
        end_x=end_x,
        begin_val=float(begin_val),
        end_val=float(end_val),
        direction=_direction(float(begin_val), float(end_val), row.get('direction') or row.get('dir')),
    )


def _line_rows(rows: Any, level: str) -> list[_Line]:
    if not isinstance(rows, list):
        return []
    result = [_line_from_row(row, level, i) for i, row in enumerate(rows)]
    return sorted([line for line in result if line is not None], key=lambda line: (line.begin_x, line.end_x, line.index))


def _fx_side(row: dict[str, Any]) -> str:
    text = str(row.get('type') or row.get('fx') or row.get('side') or '').strip().lower()
    if 'top' in text or 'ding' in text or '顶' in text:
        return 'top'
    if 'bottom' in text or 'di' in text or '底' in text:
        return 'bottom'
    return ''


def _fx_lines(payload: dict[str, Any]) -> list[_Line]:
    rows = payload.get('fx')
    if not isinstance(rows, list):
        return []
    points: list[tuple[int, int, str, float]] = []
    for i, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        raw_index = _raw(row, 'raw_index', 'rawIndex', 'x')
        side = _fx_side(row)
        value = row.get('price')
        if raw_index >= 0 and side in {'top', 'bottom'} and value is not None:
            points.append((raw_index, _to_int(row.get('index'), i), side, _to_float(value)))
    points.sort(key=lambda item: (item[0], item[1]))
    lines: list[_Line] = []
    for i, (a, b) in enumerate(zip(points, points[1:])):
        a_x, _a_idx, a_side, a_val = a
        b_x, _b_idx, b_side, b_val = b
        if a_x == b_x or a_side == b_side:
            continue
        lines.append(_Line(
            level='fx',
            index=i,
            begin_x=a_x,
            end_x=b_x,
            begin_val=a_val,
            end_val=b_val,
            direction='UP' if a_side == 'bottom' else 'DOWN',
        ))
    return lines


def _segseg_lines(payload: dict[str, Any]) -> list[_Line]:
    seg_layers = payload.get('seg_layers')
    if not isinstance(seg_layers, dict):
        return []
    rows = seg_layers.get('2') or seg_layers.get(2)
    return _line_rows(rows, 'segseg')


def _child_lines_for_parent(parent: _Line, children: list[_Line]) -> list[_Line]:
    picked: dict[str, _Line] = {}
    for child in children:
        # Matches a_replay_trainer.py child_lines_for_parent_rhythm(): the
        # child line may cross the parent right edge if its begin point is still
        # inside the parent line. This completes the next turning segment.
        if child.begin_x >= parent.begin_x and (child.end_x <= parent.end_x or child.begin_x <= parent.end_x):
            picked[_line_key(child.level, child)] = child
    return sorted(picked.values(), key=lambda line: (line.begin_x, line.end_x, line.index))


def _alternating_sequence(children: list[_Line], parent_dir: str) -> list[_Line]:
    if parent_dir not in {'UP', 'DOWN'}:
        return []
    result: list[_Line] = []
    expected = parent_dir
    started = False
    for child in children:
        if child.direction not in {'UP', 'DOWN'}:
            continue
        if not started:
            if child.direction != parent_dir:
                continue
            started = True
        if child.direction != expected:
            continue
        result.append(child)
        expected = _opposite(expected)
    return result


def _threshold(direction: str, *, prev_same_val: float, opposite_val: float) -> float:
    if direction == 'UP':
        return opposite_val + (prev_same_val - opposite_val) * RHYTHM_RATIO
    if direction == 'DOWN':
        return opposite_val - (opposite_val - prev_same_val) * RHYTHM_RATIO
    return float('nan')


def _retrace_allowed(
    mode: str,
    direction: str,
    *,
    a_val: float,
    b_val: float,
    c_val: float,
    d_val: float,
    threshold: float,
) -> bool:
    """Enforce transition first; strict1382 then adds its threshold gate."""
    if not _monotonic_rhythm_triplet(
        direction,
        first_start=a_val,
        first_end=b_val,
        retrace_end=c_val,
        current_end=d_val,
    ):
        return False
    if mode == RHYTHM_CALC_MODE_TRANSITION:
        return True
    eps = 1e-12
    if direction == 'UP':
        return mode == RHYTHM_CALC_MODE_STRICT_1382 and d_val + eps >= threshold
    if direction == 'DOWN':
        return mode == RHYTHM_CALC_MODE_STRICT_1382 and d_val - eps <= threshold
    return False


def _monotonic_rhythm_triplet(
    direction: str,
    *,
    first_start: float,
    first_end: float,
    retrace_end: float,
    current_end: float,
) -> bool:
    """Accept only rising UP-DOWN-UP or falling DOWN-UP-DOWN structures."""
    eps = 1e-12
    if direction == 'UP':
        return retrace_end > first_start + eps and current_end > first_end + eps
    if direction == 'DOWN':
        return retrace_end < first_start - eps and current_end < first_end - eps
    return False


def _find_hits(
    bars: list[Any],
    *,
    chart_level: str,
    source_kind: str,
    parent_level: str,
    line_id: str,
    direction: str,
    start_raw_index: int,
    threshold: float,
) -> list[dict[str, Any]]:
    if not bars or not _finite(threshold):
        return []
    hits: list[dict[str, Any]] = []
    for raw_index in range(max(0, int(start_raw_index) + 1), len(bars)):
        row = bars[raw_index]
        if direction == 'UP':
            price = _bar_high(row)
            touched = price is not None and price >= threshold
            field = 'H'
        else:
            price = _bar_low(row)
            touched = price is not None and price <= threshold
            field = 'L'
        if not touched:
            continue
        hit_id = f'{line_id}|1382|{raw_index}|{len(hits) + 1}'
        trigger_price = float(price if price is not None else threshold)
        hits.append({
            'id': hit_id,
            'line_id': line_id,
            'level': chart_level,
            'source_kind': source_kind,
            'parent_level': parent_level,
            'parent_label': _level_label(parent_level),
            'raw_index': raw_index,
            'time': _bar_time(row),
            'price': trigger_price,
            'threshold': float(threshold),
            'dir': direction,
            'display_label': f'{_level_label(source_kind)}1382',
            'detail': (
                f'{_level_label(source_kind)}1382\n'
                f'时间：{_bar_time(row)}\n'
                f'父结构：{_level_label(parent_level)}\n'
                f'方向：{"上升" if direction == "UP" else "下降"}\n'
                f'阈值价：{float(threshold):.3f}\n'
                f'触发价：{field}={trigger_price:.3f}'
            ),
        })
    return hits


def _build_parent_entries(
    *,
    chart_level: str,
    child_level: str,
    parent_level: str,
    parent: _Line,
    children: list[_Line],
    bars: list[Any],
    mode: str,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    parent_key = _line_key(parent_level, parent)
    lines: list[dict[str, Any]] = []
    hits: list[dict[str, Any]] = []
    for rhythm_dir in ('UP', 'DOWN'):
        seq = _alternating_sequence(children, rhythm_dir)
        if len(seq) < 4:
            continue
        a0 = float(seq[0].begin_val)
        max_round = max(0, (len(seq) - 2) // 2)

        for round_current in range(1, max_round + 1):
            d_line = seq[2 * round_current]
            d_val = float(d_line.end_val)
            gate_b = seq[2 * (round_current - 1)]
            gate_c = seq[2 * (round_current - 1) + 1]
            gate_threshold = _threshold(
                rhythm_dir,
                prev_same_val=gate_b.end_val,
                opposite_val=gate_c.end_val,
            )
            if not _finite(gate_threshold) or not _retrace_allowed(
                mode,
                rhythm_dir,
                a_val=gate_b.begin_val,
                b_val=gate_b.end_val,
                c_val=gate_c.end_val,
                d_val=d_val,
                threshold=gate_threshold,
            ):
                continue

            # ABCD confirms the rhythm. E is the next opposite child endpoint
            # and defines the rendered C->E span, including a parent turn.
            line_end = seq[2 * round_current + 1]
            self_line_id = ''
            self_threshold = float(gate_threshold)
            self_c = gate_c

            for round_ref in range(1, round_current + 1):
                b_line = seq[2 * (round_ref - 1)]
                c_line = seq[2 * (round_ref - 1) + 1]
                b_val = float(b_line.end_val)
                c_val = float(c_line.end_val)
                if rhythm_dir == 'UP':
                    denom = b_val - a0
                    if abs(denom) <= 1e-12:
                        continue
                    ratio = (b_val - c_val) / denom
                    rhythm_price = d_val - (d_val - a0) * ratio
                else:
                    denom = a0 - b_val
                    if abs(denom) <= 1e-12:
                        continue
                    ratio = (c_val - b_val) / denom
                    rhythm_price = d_val + (a0 - d_val) * ratio
                threshold = _threshold(
                    rhythm_dir,
                    prev_same_val=b_val,
                    opposite_val=c_val,
                )
                if ratio < 0 or not (_finite(rhythm_price) and _finite(threshold)):
                    continue
                layer = max(0, round_current - round_ref)
                line_id = (
                    f'rhythm|{parent_key}|{child_level}|{rhythm_dir}|'
                    f'{round_current}|{round_ref}|{layer}'
                )
                lines.append({
                    'id': line_id,
                    'key': line_id,
                    'level': chart_level,
                    'structure_level': child_level,
                    'parent_level': parent_level,
                    'parent_key': parent_key,
                    'parent_label': _level_label(parent_level),
                    'source_kind': child_level,
                    'source_label': _level_label(child_level),
                    'calc_mode': mode,
                    'dir': rhythm_dir,
                    'ratio': float(ratio),
                    'threshold_ratio': RHYTHM_RATIO,
                    'threshold': float(threshold),
                    'price': float(rhythm_price),
                    'display_label': f'节奏线{round_ref}-{layer}',
                    'round_current': round_current,
                    'round_ref': round_ref,
                    'layer': layer,
                    'label_left': f'{round_ref}-{layer}',
                    'label_right': _ratio_text(float(ratio)),
                    'color_group': f'{child_level}-{rhythm_dir}-rhythm{round_ref}',
                    # Every line in one round_ref group shares its C-point time.
                    'x1': int(c_line.end_x),
                    'y1': float(rhythm_price),
                    # D confirms; the next opposite child endpoint E renders.
                    'x2': int(line_end.end_x),
                    'y2': float(rhythm_price),
                    'backend_authority': 'python_backend_monotonic_rhythm_overlay',
                })
                if round_ref == round_current:
                    self_line_id = line_id
                    self_threshold = float(threshold)
                    self_c = c_line

            if self_line_id:
                hits.extend(_find_hits(
                    bars,
                    chart_level=chart_level,
                    source_kind=child_level,
                    parent_level=parent_level,
                    line_id=self_line_id,
                    direction=rhythm_dir,
                    start_raw_index=self_c.end_x,
                    threshold=self_threshold,
                ))
    return lines, hits


def _mappings(payload: dict[str, Any]) -> list[tuple[str, str, list[_Line], list[_Line]]]:
    fx_children = _fx_lines(payload)
    bi_lines = _line_rows(payload.get('bi'), 'bi')
    seg_lines = _line_rows(payload.get('seg'), 'seg')
    segseg_lines = _segseg_lines(payload)
    result: list[tuple[str, str, list[_Line], list[_Line]]] = [
        ('fx', 'bi', fx_children, bi_lines),
        ('bi', 'seg', bi_lines, seg_lines),
    ]
    if segseg_lines:
        result.append(('seg', 'segseg', seg_lines, segseg_lines))
    return result


def _build_structures(chart_level: str, payload: dict[str, Any], mode: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    bars = payload.get('bars') if isinstance(payload.get('bars'), list) else []
    all_lines: list[dict[str, Any]] = []
    all_hits: list[dict[str, Any]] = []
    for child_level, parent_level, children, parents in _mappings(payload):
        if not children or not parents:
            continue
        for parent in parents:
            picked_children = _child_lines_for_parent(parent, children)
            lines, hits = _build_parent_entries(
                chart_level=chart_level,
                child_level=child_level,
                parent_level=parent_level,
                parent=parent,
                children=picked_children,
                bars=bars,
                mode=mode,
            )
            all_lines.extend(lines)
            all_hits.extend(hits)
    all_lines.sort(key=lambda line: (
        int(line.get('x1') or 0),
        int(line.get('round_ref') or 0),
        int(line.get('round_current') or 0),
        str(line.get('id') or ''),
    ))
    dedup: dict[str, dict[str, Any]] = {}
    for hit in sorted(all_hits, key=lambda item: (
        int(item.get('raw_index') or 0),
        str(item.get('line_id') or ''),
        str(item.get('id') or ''),
    )):
        dedup[str(hit.get('id') or '')] = hit
    return all_lines, list(dedup.values())


def with_level_rhythm_overlay(level: str, level_payload: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    if not _enabled(config):
        return level_payload
    chart_level = str(level).upper()
    mode = _calc_mode(config)
    lines, hits = _build_structures(chart_level, level_payload, mode)
    patched = dict(level_payload)
    patched['rhythm_lines'] = lines
    patched['rhythm_hits'] = hits
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update({
        'rhythm_1382_enabled': True,
        'rhythm_calc_mode': mode,
        'rhythm_calc_mode_compat_note': _deprecated_calc_mode_note(config),
        'rhythm_line_count': len(lines),
        'rhythm_hit_count': len(hits),
        'rhythm_policy': 'backend parent-child rhythm overlay ported from chan_month5 full-optimization a_replay_trainer.py; Dart only parses/renders',
        'rhythm_mapping_policy': 'fx->bi, bi->seg, seg->segseg; only rising UP-DOWN-UP or falling DOWN-UP-DOWN child structures qualify, independent of parent direction',
        'rhythm_group_anchor_policy': 'numbering resets per parent_key; ABCD confirms and each line renders C-to-E using the next opposite child endpoint',
        'rhythm_level_field_policy': 'line.level/hit.level is chart timeframe; source_kind is structure kind',
        'rhythm_1382_cap_policy': 'trainer parity: backend rhythm export is uncapped; Flutter may still display a subset for performance',
    })
    patched['meta'] = meta
    return patched


def with_multilevel_rhythm_overlay(result: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    if not _enabled(config) or not isinstance(result, dict):
        return result

    mode = _calc_mode(config)
    compat_note = _deprecated_calc_mode_note(config)

    def patch_snapshot(snapshot: Any) -> Any:
        if not isinstance(snapshot, dict):
            return snapshot
        levels = snapshot.get('levels')
        if not isinstance(levels, dict):
            return snapshot
        next_levels: dict[str, Any] = {}
        total_lines = 0
        total_hits = 0
        for level_name, payload in levels.items():
            if isinstance(payload, dict):
                patched_level = with_level_rhythm_overlay(str(level_name).upper(), payload, config)
                total_lines += len(patched_level.get('rhythm_lines') or [])
                total_hits += len(patched_level.get('rhythm_hits') or [])
                next_levels[level_name] = patched_level
            else:
                next_levels[level_name] = payload
        patched = dict(snapshot)
        patched['levels'] = next_levels
        meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
        meta.update({
            'rhythm_1382_enabled': True,
            'rhythm_calc_mode': mode,
            'rhythm_calc_mode_compat_note': compat_note,
            'rhythm_1382_total_lines': total_lines,
            'rhythm_1382_total_hits': total_hits,
            'rhythm_1382_scope': 'multi_level_snapshot_levels_and_step_frames',
            'rhythm_1382_overlay_source': 'a_replay_trainer_parent_child_port',
        })
        patched['meta'] = meta
        return patched

    patched_result = patch_snapshot(result)
    frames = patched_result.get('frames')
    if isinstance(frames, list):
        patched_result['frames'] = [patch_snapshot(frame) for frame in frames]
    return patched_result
