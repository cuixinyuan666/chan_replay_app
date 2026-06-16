from __future__ import annotations

from dataclasses import dataclass
from typing import Any


RHYTHM_RATIO = 1.382
RHYTHM_CALC_MODE_NORMAL = 'normal'
RHYTHM_CALC_MODE_TRANSITION = 'transition'
RHYTHM_CALC_MODE_STRICT_1382 = 'strict1382'
RHYTHM_CALC_MODES = {
    RHYTHM_CALC_MODE_NORMAL,
    RHYTHM_CALC_MODE_TRANSITION,
    RHYTHM_CALC_MODE_STRICT_1382,
}

STRUCTURE_LEVEL_LABELS = {
    'fract': '分型',
    'bi': '笔',
    'seg': '线段',
    'segseg': '二段',
}


@dataclass(frozen=True)
class _Pivot:
    raw_index: int
    price: float
    side: str
    source_index: int


@dataclass(frozen=True)
class _Line:
    level: str
    index: int
    start_raw_index: int
    end_raw_index: int
    start_price: float
    end_price: float
    direction: str
    parent_start_index: int | None = None
    parent_end_index: int | None = None

    @property
    def begin_x(self) -> int:
        return self.start_raw_index

    @property
    def end_x(self) -> int:
        return self.end_raw_index

    @property
    def begin_val(self) -> float:
        return self.start_price

    @property
    def end_val(self) -> float:
        return self.end_price


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


def _first(row: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in row and row[key] is not None:
            return row[key]
    return None


def _normalize_calc_mode(config: dict[str, Any] | None) -> str:
    raw = str((config or {}).get('rhythm_calc_mode') or RHYTHM_CALC_MODE_NORMAL).strip()
    return raw if raw in RHYTHM_CALC_MODES else RHYTHM_CALC_MODE_NORMAL


def _enabled(config: dict[str, Any] | None) -> bool:
    raw = (config or {}).get('enable_rhythm_1382', True)
    if isinstance(raw, bool):
        return raw
    return str(raw).strip().lower() not in {'0', 'false', 'no', 'off'}


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


def _bar_time(row: Any) -> str:
    if not isinstance(row, dict):
        return ''
    value = row.get('dt') or row.get('datetime') or row.get('time') or row.get('date') or ''
    return str(value)


def _json_id(text: Any) -> str:
    return str(text).replace('|', '_').replace(' ', '_').replace(':', '_')


def _direction_text(value: Any, *, start_price: float | None = None, end_price: float | None = None) -> str:
    text = str(value or '').strip().upper()
    if 'UP' in text:
        return 'UP'
    if 'DOWN' in text:
        return 'DOWN'
    if start_price is not None and end_price is not None:
        return 'UP' if float(end_price) >= float(start_price) else 'DOWN'
    return ''


def _reverse_dir(direction: str) -> str:
    return 'DOWN' if _direction_text(direction) == 'UP' else 'UP'


def _structure_level_label(level: str) -> str:
    text = str(level or '').strip().lower()
    return STRUCTURE_LEVEL_LABELS.get(text, text)


def _line_key(level: str, line: _Line) -> str:
    return f'{level}|{line.index}|{line.begin_x}|{line.end_x}|{line.direction}'


def _line_rows(raw: Any, level: str) -> list[_Line]:
    if not isinstance(raw, list):
        return []
    lines: list[_Line] = []
    for seq, row in enumerate(raw):
        if not isinstance(row, dict):
            continue
        start_raw = _to_int(_first(row, 'start_raw_index', 'startRawIndex'), -1)
        end_raw = _to_int(_first(row, 'end_raw_index', 'endRawIndex'), -1)
        start_price_raw = row.get('start_price') if 'start_price' in row else row.get('startPrice')
        end_price_raw = row.get('end_price') if 'end_price' in row else row.get('endPrice')
        if start_raw < 0 or end_raw < 0 or start_price_raw is None or end_price_raw is None:
            continue
        start_price = _to_float(start_price_raw)
        end_price = _to_float(end_price_raw)
        direction = _direction_text(row.get('direction') or row.get('dir'), start_price=start_price, end_price=end_price)
        if direction not in {'UP', 'DOWN'}:
            continue
        lines.append(_Line(
            level=level,
            index=_to_int(row.get('index') if 'index' in row else row.get('idx'), seq),
            start_raw_index=start_raw,
            end_raw_index=end_raw,
            start_price=start_price,
            end_price=end_price,
            direction=direction,
            parent_start_index=(
                _to_int(row.get('start_parent_index'), -1)
                if row.get('start_parent_index') is not None else None
            ),
            parent_end_index=(
                _to_int(row.get('end_parent_index'), -1)
                if row.get('end_parent_index') is not None else None
            ),
        ))
    return sorted(lines, key=lambda item: (item.begin_x, item.end_x, item.index))


def _unique_sorted_pivots(pivots: list[_Pivot]) -> list[_Pivot]:
    keyed: dict[tuple[int, str, int], _Pivot] = {}
    for pivot in pivots:
        keyed[(pivot.raw_index, pivot.side, pivot.source_index)] = pivot
    return [keyed[key] for key in sorted(keyed)]


def _normalize_alternating_pivots(pivots: list[_Pivot]) -> list[_Pivot]:
    normalized: list[_Pivot] = []
    for pivot in _unique_sorted_pivots(pivots):
        if not normalized:
            normalized.append(pivot)
            continue
        last = normalized[-1]
        if pivot.side == last.side:
            if pivot.side == 'top':
                if pivot.price > last.price or (abs(pivot.price - last.price) <= 1e-9 and pivot.raw_index >= last.raw_index):
                    normalized[-1] = pivot
            else:
                if pivot.price < last.price or (abs(pivot.price - last.price) <= 1e-9 and pivot.raw_index >= last.raw_index):
                    normalized[-1] = pivot
            continue
        if pivot.raw_index == last.raw_index and abs(pivot.price - last.price) <= 1e-9:
            continue
        normalized.append(pivot)
    return normalized


def _fx_pivots(level_payload: dict[str, Any]) -> list[_Pivot]:
    rows = level_payload.get('fx')
    if not isinstance(rows, list):
        return []
    result: list[_Pivot] = []
    for seq, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        raw_index = _to_int(_first(row, 'raw_index', 'rawIndex'), -1)
        price = row.get('price')
        if raw_index < 0 or price is None:
            continue
        text = str(row.get('type') or '').lower()
        side = 'top' if 'top' in text else 'bottom'
        result.append(_Pivot(
            raw_index=raw_index,
            price=_to_float(price),
            side=side,
            source_index=_to_int(row.get('index'), seq),
        ))
    return _normalize_alternating_pivots(result)


def _fract_child_lines(level_payload: dict[str, Any]) -> list[_Line]:
    pivots = _fx_pivots(level_payload)
    lines: list[_Line] = []
    for seq, (start, end) in enumerate(zip(pivots, pivots[1:])):
        if start.side == end.side:
            continue
        direction = 'UP' if start.side == 'bottom' and end.side == 'top' else 'DOWN'
        if start.raw_index >= end.raw_index:
            continue
        lines.append(_Line(
            level='fract',
            index=seq,
            start_raw_index=start.raw_index,
            end_raw_index=end.raw_index,
            start_price=start.price,
            end_price=end.price,
            direction=direction,
        ))
    return lines


def _seg_layer_rows(level_payload: dict[str, Any], layer: str) -> list[_Line]:
    seg_layers = level_payload.get('seg_layers') or level_payload.get('segLayers')
    if not isinstance(seg_layers, dict):
        return []
    rows = seg_layers.get(layer) or seg_layers.get(int(layer)) or []
    return _line_rows(rows, 'segseg' if str(layer) == '2' else f'seg{layer}')


def _child_lines_for_parent_rhythm(parent: _Line, child_lines: list[_Line]) -> list[_Line]:
    begin_x = parent.begin_x
    end_x = parent.end_x
    picked: dict[str, _Line] = {}
    for line in child_lines:
        bx = line.begin_x
        ex = line.end_x
        # Replicates a_replay_trainer.py: allow one child line crossing the
        # parent end boundary so the next rhythm turning point can be completed.
        if bx >= begin_x and (ex <= end_x or bx <= end_x):
            picked[_line_key('child', line)] = line
    return sorted(picked.values(), key=lambda item: (item.begin_x, item.end_x, item.index))


def _build_alternating_child_sequence(child_lines: list[_Line], parent_dir: str) -> list[_Line]:
    if not child_lines:
        return []
    seq: list[_Line] = []
    expected = parent_dir
    started = False
    for child in child_lines:
        child_dir = child.direction
        if child_dir not in {'UP', 'DOWN'}:
            continue
        if not started:
            if child_dir != parent_dir:
                continue
            started = True
        if child_dir != expected:
            continue
        seq.append(child)
        expected = _reverse_dir(expected)
    return seq


def _rhythm_1382_threshold(direction: str, *, prev_same_val: float, opposite_val: float) -> float:
    dir_text = _direction_text(direction)
    if dir_text == 'UP':
        return float(opposite_val) + (float(prev_same_val) - float(opposite_val)) * RHYTHM_RATIO
    if dir_text == 'DOWN':
        return float(opposite_val) - (float(opposite_val) - float(prev_same_val)) * RHYTHM_RATIO
    return float('nan')


def _rhythm_retrace_allowed(mode: Any, direction: str, *, b_val: float, d_val: float, threshold: float) -> bool:
    calc_mode = _normalize_calc_mode({'rhythm_calc_mode': mode})
    if calc_mode == RHYTHM_CALC_MODE_NORMAL:
        return True
    dir_text = _direction_text(direction)
    eps = 1e-12
    if dir_text == 'UP':
        if d_val + eps < b_val:
            return False
        return calc_mode != RHYTHM_CALC_MODE_STRICT_1382 or d_val + eps >= threshold
    if dir_text == 'DOWN':
        if d_val - eps > b_val:
            return False
        return calc_mode != RHYTHM_CALC_MODE_STRICT_1382 or d_val - eps <= threshold
    return True


def _rhythm_layer_index(round_current: int, round_ref: int) -> int:
    return max(0, int(round_current) - int(round_ref))


def _make_rhythm_display_label(round_current: int, round_ref: int) -> str:
    return f'节奏线{round_ref}-{_rhythm_layer_index(round_current, round_ref)}'


def _format_rhythm_ratio(ratio: float) -> str:
    text = f'{float(ratio):.3f}'
    return text.rstrip('0').rstrip('.') if '.' in text else text


def _find_1382_hits(
    bars: list[Any],
    *,
    start_x: int,
    direction: str,
    threshold: float,
    max_hits: int,
) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    if max_hits <= 0:
        return hits
    for raw_index in range(max(0, int(start_x) + 1), len(bars)):
        row = bars[raw_index]
        if direction == 'UP':
            high = _bar_high(row)
            if high is None or high < threshold:
                continue
            hits.append({
                'x': raw_index,
                'y': high,
                'time': _bar_time(row),
                'price_field': 'H',
                'price_value': high,
            })
        else:
            low = _bar_low(row)
            if low is None or low > threshold:
                continue
            hits.append({
                'x': raw_index,
                'y': low,
                'time': _bar_time(row),
                'price_field': 'L',
                'price_value': low,
            })
        if len(hits) >= max_hits:
            break
    return hits


def _build_parent_rhythm_entries(
    *,
    chart_level: str,
    level: str,
    parent_level: str,
    parent_line: _Line,
    child_lines: list[_Line],
    bars: list[Any],
    rhythm_calc_mode: str,
    max_hits_per_parent: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    parent_dir = parent_line.direction
    if parent_dir not in {'UP', 'DOWN'}:
        return [], []
    seq = _build_alternating_child_sequence(child_lines, parent_dir)
    if len(seq) < 4:
        return [], []

    calc_mode = _normalize_calc_mode({'rhythm_calc_mode': rhythm_calc_mode})
    parent_key = _line_key(parent_level, parent_line)
    parent_label = _structure_level_label(parent_level)
    level_label_cn = _structure_level_label(level)
    a0 = float(parent_line.begin_val)
    lines: list[dict[str, Any]] = []
    hits: list[dict[str, Any]] = []
    max_round = max(0, (len(seq) - 2) // 2)

    for round_current in range(1, max_round + 1):
        d_line = seq[2 * round_current]
        line_start = seq[2 * round_current - 1]
        line_end = seq[2 * round_current + 1]
        d_val = float(d_line.end_val)
        gate_b_line = seq[2 * (round_current - 1)]
        gate_c_line = seq[2 * (round_current - 1) + 1]
        gate_b_val = float(gate_b_line.end_val)
        gate_c_val = float(gate_c_line.end_val)
        gate_threshold = _rhythm_1382_threshold(parent_dir, prev_same_val=gate_b_val, opposite_val=gate_c_val)
        if not abs(gate_threshold) < float('inf'):
            continue
        if not _rhythm_retrace_allowed(calc_mode, parent_dir, b_val=gate_b_val, d_val=d_val, threshold=float(gate_threshold)):
            continue

        has_self_line_for_hit = False
        self_gate_c_line = gate_c_line
        self_gate_threshold = float(gate_threshold)
        for round_ref in range(1, round_current + 1):
            b_line = seq[2 * (round_ref - 1)]
            c_line = seq[2 * (round_ref - 1) + 1]
            b_val = float(b_line.end_val)
            c_val = float(c_line.end_val)
            if parent_dir == 'UP':
                denom = b_val - a0
                ratio = (b_val - c_val) / denom if abs(denom) > 1e-12 else None
                rhythm_price = d_val - (d_val - a0) * ratio if ratio is not None else None
                threshold = _rhythm_1382_threshold(parent_dir, prev_same_val=b_val, opposite_val=c_val) if ratio is not None else None
            else:
                denom = a0 - b_val
                ratio = (c_val - b_val) / denom if abs(denom) > 1e-12 else None
                rhythm_price = d_val + (a0 - d_val) * ratio if ratio is not None else None
                threshold = _rhythm_1382_threshold(parent_dir, prev_same_val=b_val, opposite_val=c_val) if ratio is not None else None
            if ratio is None or rhythm_price is None or threshold is None:
                continue
            if not (ratio >= 0 and abs(rhythm_price) < float('inf') and abs(threshold) < float('inf')):
                continue

            layer_idx = _rhythm_layer_index(round_current, round_ref)
            label_left = f'{round_ref}-{layer_idx}'
            label_right = _format_rhythm_ratio(ratio)
            color_group = f'rhythm{round_ref}'
            key = f'{chart_level}|{parent_key}|line|{level}|{round_ref}|{layer_idx}'
            line_id = _json_id(key)
            line = {
                'id': line_id,
                'key': key,
                'chart_level': chart_level,
                'level': level,
                'source_kind': level,
                'source_label': level_label_cn,
                'parent_level': parent_level,
                'parent_key': parent_key,
                'parent_label': parent_label,
                'display_label': _make_rhythm_display_label(round_current, round_ref),
                'round_current': round_current,
                'round_ref': round_ref,
                'layer': layer_idx,
                'calc_mode': calc_mode,
                'color_group': color_group,
                'dir': parent_dir,
                'ratio': float(ratio),
                'threshold_ratio': RHYTHM_RATIO,
                'label_left': label_left,
                'label_right': label_right,
                'x1': line_start.end_x,
                'y1': float(rhythm_price),
                'x2': line_end.end_x,
                'y2': float(rhythm_price),
                'price': float(rhythm_price),
                'threshold': float(threshold),
                'parent_start_raw_index': parent_line.begin_x,
                'parent_end_raw_index': parent_line.end_x,
                'gate_threshold': float(gate_threshold),
                'backend_authority': 'python_backend_parent_child_rhythm_replay_trainer_semantics',
            }
            lines.append(line)
            if round_ref == round_current:
                self_gate_c_line = c_line
                self_gate_threshold = float(threshold)
                has_self_line_for_hit = True

        if not has_self_line_for_hit:
            continue

        for hit in _find_1382_hits(
            bars,
            start_x=self_gate_c_line.end_x,
            direction=parent_dir,
            threshold=float(self_gate_threshold),
            max_hits=max_hits_per_parent,
        ):
            hit_key = f'{chart_level}|{parent_key}|1382|{level}|{round_current}|{int(hit["x"])}'
            hit_id = _json_id(hit_key)
            hits.append({
                'id': hit_id,
                'key': hit_key,
                'line_id': _json_id(f'{chart_level}|{parent_key}|line|{level}|{round_current}|0'),
                'chart_level': chart_level,
                'raw_index': int(hit['x']),
                'x': int(hit['x']),
                'price': float(hit['price_value']),
                'y': float(hit['y']),
                'level': level,
                'source_kind': level,
                'parent_level': parent_level,
                'parent_key': parent_key,
                'display_label': f'{level_label_cn}1382',
                'round_ref': round_current,
                'color_group': f'rhythm{round_current}',
                'dir': parent_dir,
                'threshold': float(self_gate_threshold),
                'time': hit['time'],
                'detail': (
                    f'{level_label_cn}1382\n'
                    f'时间：{hit["time"]}\n'
                    f'父结构：{parent_label}\n'
                    f'方向：{"上升" if parent_dir == "UP" else "下降"}\n'
                    f'轮次：第{round_current}次回调\n'
                    f'阈值价：{float(self_gate_threshold):.3f}\n'
                    f'触发价：{hit["price_field"]}={float(hit["price_value"]):.3f}'
                ),
            })
    return lines, hits


def _build_level_rhythm_structures(
    *,
    chart_level: str,
    level_payload: dict[str, Any],
    rhythm_calc_mode: str,
    max_lines: int,
    max_hits_per_parent: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], dict[str, int]]:
    bars = level_payload.get('bars') if isinstance(level_payload.get('bars'), list) else []
    fract_children = _fract_child_lines(level_payload)
    bi_children = _line_rows(level_payload.get('bi'), 'bi')
    seg_children = _line_rows(level_payload.get('seg'), 'seg')
    bi_parents = bi_children
    seg_parents = seg_children
    segseg_parents = _seg_layer_rows(level_payload, '2')

    mappings = [
        ('fract', 'bi', fract_children, bi_parents),
        ('bi', 'seg', bi_children, seg_parents),
        ('seg', 'segseg', seg_children, segseg_parents),
    ]

    all_lines: list[dict[str, Any]] = []
    all_hits: list[dict[str, Any]] = []
    parent_counts: dict[str, int] = {}
    for level, parent_level, source_children, parents in mappings:
        parent_counts[f'{level}_children'] = len(source_children)
        parent_counts[f'{parent_level}_parents'] = len(parents)
        for parent_line in parents:
            parent_children = _child_lines_for_parent_rhythm(parent_line, source_children)
            lines, hits = _build_parent_rhythm_entries(
                chart_level=chart_level,
                level=level,
                parent_level=parent_level,
                parent_line=parent_line,
                child_lines=parent_children,
                bars=bars,
                rhythm_calc_mode=rhythm_calc_mode,
                max_hits_per_parent=max_hits_per_parent,
            )
            all_lines.extend(lines)
            all_hits.extend(hits)
            if len(all_lines) >= max_lines:
                break
        if len(all_lines) >= max_lines:
            break

    all_lines.sort(key=lambda item: (
        int(item.get('x1', 0)),
        int(item.get('round_ref', 0)),
        int(item.get('round_current', 0)),
        str(item.get('display_label', '')),
    ))
    dedup_hits: dict[str, dict[str, Any]] = {}
    for item in sorted(all_hits, key=lambda entry: (
        int(entry.get('x', entry.get('raw_index', 0))),
        int(entry.get('round_ref', 0)),
        str(entry.get('level', '')),
    )):
        dedup_hits[str(item.get('key') or item.get('id'))] = item
    return all_lines[:max_lines], list(dedup_hits.values()), parent_counts


def with_level_rhythm_overlay(level: str, level_payload: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    if not _enabled(config):
        return level_payload
    calc_mode = _normalize_calc_mode(config)
    max_lines = max(0, _to_int((config or {}).get('rhythm_max_lines'), 120))
    max_hits_per_parent = max(0, _to_int((config or {}).get('rhythm_max_hits_per_line'), 3))
    lines, hits, parent_counts = _build_level_rhythm_structures(
        chart_level=str(level).upper(),
        level_payload=level_payload,
        rhythm_calc_mode=calc_mode,
        max_lines=max_lines,
        max_hits_per_parent=max_hits_per_parent,
    )
    patched = dict(level_payload)
    patched['rhythm_lines'] = lines
    patched['rhythm_hits'] = hits
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update({
        'rhythm_1382_enabled': True,
        'rhythm_calc_mode': calc_mode,
        'rhythm_line_count': len(lines),
        'rhythm_hit_count': len(hits),
        'rhythm_policy': 'backend parent-child rhythm replica from a_replay_trainer.py; Dart only parses/renders',
        'rhythm_replica_mode': 'parent_child_fract_bi_seg_segseg',
        'rhythm_parent_child_levels': ['fract->bi', 'bi->seg', 'seg->segseg'],
        'rhythm_formula_policy': 'trainer: gate threshold uses 1.382; rendered line price uses historical retrace ratio projected from parent start and current D',
        **{f'rhythm_{key}': value for key, value in parent_counts.items()},
    })
    patched['meta'] = meta
    return patched


def with_multilevel_rhythm_overlay(result: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    if not _enabled(config) or not isinstance(result, dict):
        return result

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
        patched_snapshot = dict(snapshot)
        patched_snapshot['levels'] = next_levels
        meta = dict(patched_snapshot.get('meta')) if isinstance(patched_snapshot.get('meta'), dict) else {}
        meta.update({
            'rhythm_1382_enabled': True,
            'rhythm_1382_total_lines': total_lines,
            'rhythm_1382_total_hits': total_hits,
            'rhythm_1382_scope': 'multi_level_snapshot_levels_and_step_frames',
            'rhythm_1382_replica_source': 'chan_month5/full-optimization/a_replay_trainer.py parent-child rhythm semantics',
        })
        patched_snapshot['meta'] = meta
        return patched_snapshot

    patched = patch_snapshot(result)
    frames = patched.get('frames')
    if isinstance(frames, list):
        patched['frames'] = [patch_snapshot(frame) for frame in frames]
    return patched
