from __future__ import annotations

import math
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
RHYTHM_SOURCE_LABELS = {
    'fx': '分型',
    'fract': '分型',
    'bi': '笔',
    'seg': '线段',
    'segseg': '二段',
}
RHYTHM_PARENT_LABELS = {
    'bi': '笔',
    'seg': '线段',
    'segseg': '二段',
}


@dataclass(frozen=True)
class _Line:
    """Exported-JSON equivalent of chan.py line objects used by a_replay_trainer.

    The original trainer works on CBi/CSeg objects and calls get_begin_klu(),
    get_end_klu(), get_begin_val(), and get_end_val(). The Flutter backend
    receives already-exported JSON, so this adapter preserves those semantics
    using raw indices and begin/end prices from exported fx/bi/seg/seg_layers.
    """

    level: str
    index: int
    start_raw_index: int
    end_raw_index: int
    start_price: float
    end_price: float
    direction: str
    source_key: str = ''

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


def _finite(value: Any) -> bool:
    try:
        return math.isfinite(float(value))
    except (TypeError, ValueError):
        return False


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


def _raw_index(row: dict[str, Any], *keys: str, default: int = -1) -> int:
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


def _dir_text(direction: Any) -> str:
    text = str(direction or '').strip().upper()
    if text.endswith('.UP') or text == 'UP' or text == 'BI_DIR.UP':
        return 'UP'
    if text.endswith('.DOWN') or text == 'DOWN' or text == 'BI_DIR.DOWN':
        return 'DOWN'
    low = text.lower()
    if 'up' in low or '上' in low:
        return 'UP'
    if 'down' in low or '下' in low:
        return 'DOWN'
    return ''


def _infer_dir(start_price: float, end_price: float, raw_direction: Any = None) -> str:
    text = _dir_text(raw_direction)
    if text:
        return text
    return 'UP' if end_price >= start_price else 'DOWN'


def _reverse_dir(direction: str) -> str:
    return 'DOWN' if direction == 'UP' else 'UP'


def _level_label(level: str) -> str:
    return RHYTHM_SOURCE_LABELS.get(level, RHYTHM_PARENT_LABELS.get(level, level))


def _make_line_key(level: str, line: _Line) -> str:
    return f'{level}|{line.index}|{line.begin_x}|{line.end_x}|{line.direction}'


def _format_ratio(ratio: float) -> str:
    text = f'{float(ratio):.3f}'
    return text.rstrip('0').rstrip('.') if '.' in text else text


def _line_from_row(row: Any, level: str, seq: int) -> _Line | None:
    if not isinstance(row, dict):
        return None
    start_raw = _raw_index(row, 'start_raw_index', 'startRawIndex', 'x1', default=-1)
    end_raw = _raw_index(row, 'end_raw_index', 'endRawIndex', 'x2', default=-1)
    start_price = _price(row, 'start_price', 'startPrice', 'y1')
    end_price = _price(row, 'end_price', 'endPrice', 'y2')
    if start_raw < 0 or end_raw < 0 or start_price is None or end_price is None:
        return None
    if start_raw == end_raw:
        return None
    index = _to_int(row.get('index'), seq)
    direction = _infer_dir(start_price, end_price, row.get('direction') or row.get('dir'))
    return _Line(
        level=level,
        index=index,
        start_raw_index=start_raw,
        end_raw_index=end_raw,
        start_price=float(start_price),
        end_price=float(end_price),
        direction=direction,
        source_key=str(row.get('id') or row.get('key') or ''),
    )


def _line_rows(rows: Any, level: str) -> list[_Line]:
    if not isinstance(rows, list):
        return []
    result: list[_Line] = []
    for seq, row in enumerate(rows):
        line = _line_from_row(row, level, seq)
        if line is not None:
            result.append(line)
    return sorted(result, key=lambda line: (line.begin_x, line.end_x, line.index))


def _fx_side(row: dict[str, Any]) -> str:
    text = str(row.get('type') or row.get('fx') or row.get('side') or '').strip().lower()
    if 'top' in text or 'ding' in text or '顶' in text:
        return 'top'
    if 'bottom' in text or 'di' in text or '底' in text:
        return 'bottom'
    return ''


def _fx_children(level_payload: dict[str, Any]) -> list[_Line]:
    rows = level_payload.get('fx')
    if not isinstance(rows, list):
        return []
    points: list[tuple[int, int, str, float]] = []
    for seq, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        raw_index = _raw_index(row, 'raw_index', 'rawIndex', 'x', default=-1)
        price = row.get('price')
        side = _fx_side(row)
        if raw_index < 0 or price is None or side not in {'top', 'bottom'}:
            continue
        points.append((raw_index, _to_int(row.get('index'), seq), side, _to_float(price)))
    points.sort(key=lambda item: (item[0], item[1]))
    result: list[_Line] = []
    for seq, (a, b) in enumerate(zip(points, points[1:])):
        a_raw, a_idx, a_side, a_price = a
        b_raw, _b_idx, b_side, b_price = b
        if a_side == b_side or a_raw == b_raw:
            continue
        direction = 'UP' if a_side == 'bottom' else 'DOWN'
        result.append(
            _Line(
                level='fx',
                index=seq,
                start_raw_index=a_raw,
                end_raw_index=b_raw,
                start_price=float(a_price),
                end_price=float(b_price),
                direction=direction,
                source_key=f'fx|{a_idx}|{a_raw}|{b_raw}',
            )
        )
    return result


def _seg_layer(level_payload: dict[str, Any], layer: str) -> list[_Line]:
    seg_layers = level_payload.get('seg_layers')
    if not isinstance(seg_layers, dict):
        return []
    rows = seg_layers.get(layer) or seg_layers.get(int(layer))  # type: ignore[arg-type]
    return _line_rows(rows, 'segseg' if str(layer) == '2' else f'seg{layer}')


def _child_lines_for_parent_rhythm(parent: _Line, child_lines: list[_Line]) -> list[_Line]:
    begin_x = parent.begin_x
    end_x = parent.end_x
    picked: dict[str, _Line] = {}
    for line in child_lines:
        bx = line.begin_x
        ex = line.end_x
        # Same as a_replay_trainer.py: allow one child line crossing the parent
        # right edge to complete "previous turning point -> next turning point".
        if bx >= begin_x and (ex <= end_x or bx <= end_x):
            picked[_make_line_key('child', line)] = line
    return sorted(picked.values(), key=lambda item: (item.begin_x, item.end_x, item.index))


def _build_alternating_child_sequence(child_lines: list[_Line], parent_dir: str) -> list[_Line]:
    if not child_lines or parent_dir not in {'UP', 'DOWN'}:
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


def _rhythm_layer_index(round_current: int, round_ref: int) -> int:
    return max(0, int(round_current) - int(round_ref))


def _make_rhythm_display_label(round_current: int, round_ref: int) -> str:
    return f'节奏线{round_ref}-{_rhythm_layer_index(round_current, round_ref)}'


def _rhythm_1382_threshold(direction: str, *, prev_same_val: float, opposite_val: float) -> float:
    if direction == 'UP':
        return float(opposite_val) + (float(prev_same_val) - float(opposite_val)) * RHYTHM_RATIO
    if direction == 'DOWN':
        return float(opposite_val) - (float(opposite_val) - float(prev_same_val)) * RHYTHM_RATIO
    return float('nan')


def _rhythm_retrace_allowed(
    calc_mode: str,
    direction: str,
    *,
    b_val: float,
    d_val: float,
    threshold: float,
) -> bool:
    # Mirrors a_replay_trainer.py:
    # - normal: always allow.
    # - transition: current same-side endpoint must not be weaker than b.
    # - strict1382: current same-side endpoint must also cross the 1.382 gate.
    if calc_mode == RHYTHM_CALC_MODE_NORMAL:
        return True
    eps = 1e-12
    if direction == 'UP':
        if d_val + eps < b_val:
            return False
        return calc_mode != RHYTHM_CALC_MODE_STRICT_1382 or d_val + eps >= threshold
    if direction == 'DOWN':
        if d_val - eps > b_val:
            return False
        return calc_mode != RHYTHM_CALC_MODE_STRICT_1382 or d_val - eps <= threshold
    return True


def _find_1382_hits(
    bars: list[Any],
    *,
    start_raw_index: int,
    direction: str,
    threshold: float,
    level: str,
    source_kind: str,
    line_id: str,
    max_hits: int,
) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    if not bars or not _finite(threshold):
        return hits
    limit_enabled = max_hits > 0
    for raw_index in range(max(0, int(start_raw_index) + 1), len(bars)):
        row = bars[raw_index]
        high = _bar_high(row)
        low = _bar_low(row)
        if direction == 'UP':
            touched = high is not None and high >= threshold
            trigger_price = high
            price_field = 'H'
        else:
            touched = low is not None and low <= threshold
            trigger_price = low
            price_field = 'L'
        if not touched:
            continue
        hit_id = f'{line_id}|1382|{raw_index}|{len(hits) + 1}'
        hits.append({
            'id': hit_id,
            'line_id': line_id,
            'level': level,
            'source_kind': source_kind,
            'raw_index': raw_index,
            'time': _bar_time(row),
            'price': float(trigger_price if trigger_price is not None else threshold),
            'threshold': float(threshold),
            'dir': direction,
            'display_label': f'{_level_label(source_kind)}1382',
            'detail': (
                f'{_level_label(source_kind)}1382\n'
                f'时间：{_bar_time(row)}\n'
                f'父结构：{_level_label(level)}\n'
                f'方向：{"上升" if direction == "UP" else "下降"}\n'
                f'阈值价：{float(threshold):.3f}\n'
                f'触发价：{price_field}={float(trigger_price if trigger_price is not None else threshold):.3f}'
            ),
        })
        if limit_enabled and len(hits) >= max_hits:
            break
    return hits


def _build_parent_rhythm_entries(
    *,
    level: str,
    parent_level: str,
    parent_line: _Line,
    child_lines: list[_Line],
    bars: list[Any],
    calc_mode: str,
    max_hits_per_line: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    parent_dir = parent_line.direction
    if parent_dir not in {'UP', 'DOWN'}:
        return [], []
    seq = _build_alternating_child_sequence(child_lines, parent_dir)
    if len(seq) < 4:
        return [], []

    parent_key = _make_line_key(parent_level, parent_line)
    parent_label = _level_label(parent_level)
    source_label = _level_label(level)
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
        if not _finite(gate_threshold):
            continue
        if not _rhythm_retrace_allowed(
            calc_mode,
            parent_dir,
            b_val=gate_b_val,
            d_val=d_val,
            threshold=float(gate_threshold),
        ):
            continue

        has_self_line_for_hit = False
        self_line_id = ''
        self_threshold = float(gate_threshold)
        self_c_line = gate_c_line

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
            if not (ratio >= 0 and _finite(rhythm_price) and _finite(threshold)):
                continue

            layer_idx = _rhythm_layer_index(round_current, round_ref)
            display_label = _make_rhythm_display_label(round_current, round_ref)
            line_id = f'rhythm|{parent_key}|{level}|{round_current}|{round_ref}|{layer_idx}'
            line = {
                'id': line_id,
                'key': line_id,
                'level': level,
                'parent_level': parent_level,
                'parent_key': parent_key,
                'parent_label': parent_label,
                'source_kind': level,
                'source_label': source_label,
                'calc_mode': calc_mode,
                'dir': parent_dir,
                'ratio': float(ratio),
                'threshold_ratio': RHYTHM_RATIO,
                'threshold': float(threshold),
                'price': float(rhythm_price),
                'display_label': display_label,
                'round_current': round_current,
                'round_ref': round_ref,
                'layer': layer_idx,
                'label_left': f'{round_ref}-{layer_idx}',
                'label_right': _format_ratio(float(ratio)),
                'color_group': f'rhythm{round_ref}',
                'x1': int(line_start.end_x),
                'y1': float(rhythm_price),
                'x2': int(line_end.end_x),
                'y2': float(rhythm_price),
                'backend_authority': 'python_backend_rhythm_overlay_replayed_from_a_replay_trainer_parent_child_logic',
            }
            lines.append(line)
            if round_ref == round_current:
                has_self_line_for_hit = True
                self_line_id = line_id
                self_threshold = float(threshold)
                self_c_line = c_line

        if not has_self_line_for_hit:
            continue
        hits.extend(_find_1382_hits(
            bars,
            start_raw_index=self_c_line.end_x,
            direction=parent_dir,
            threshold=self_threshold,
            level=level,
            source_kind=level,
            line_id=self_line_id,
            max_hits=max_hits_per_line,
        ))
    return lines, hits


def _rhythm_mappings(level_payload: dict[str, Any]) -> list[tuple[str, str, list[_Line], list[_Line]]]:
    fx_children = _fx_children(level_payload)
    bi_lines = _line_rows(level_payload.get('bi'), 'bi')
    seg_lines = _line_rows(level_payload.get('seg'), 'seg')
    segseg_lines = _seg_layer(level_payload, '2')

    mappings: list[tuple[str, str, list[_Line], list[_Line]]] = [
        ('fx', 'bi', fx_children, bi_lines),
        ('bi', 'seg', bi_lines, seg_lines),
    ]
    if segseg_lines:
        mappings.append(('seg', 'segseg', seg_lines, segseg_lines))
    return mappings


def _build_rhythm_structures(
    *,
    level_payload: dict[str, Any],
    calc_mode: str,
    max_lines: int,
    max_hits_per_line: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    all_lines: list[dict[str, Any]] = []
    all_hits: list[dict[str, Any]] = []
    bars = level_payload.get('bars') if isinstance(level_payload.get('bars'), list) else []
    line_limit_enabled = max_lines > 0

    for child_level, parent_level, source_children, parents in _rhythm_mappings(level_payload):
        if not source_children or not parents:
            continue
        for parent_line in parents:
            parent_children = _child_lines_for_parent_rhythm(parent_line, source_children)
            lines, hits = _build_parent_rhythm_entries(
                level=child_level,
                parent_level=parent_level,
                parent_line=parent_line,
                child_lines=parent_children,
                bars=bars,
                calc_mode=calc_mode,
                max_hits_per_line=max_hits_per_line,
            )
            for line in lines:
                all_lines.append(line)
                if line_limit_enabled and len(all_lines) >= max_lines:
                    break
            all_hits.extend(hits)
            if line_limit_enabled and len(all_lines) >= max_lines:
                break
        if line_limit_enabled and len(all_lines) >= max_lines:
            break

    all_lines.sort(key=lambda item: (
        int(item.get('x1') or 0),
        int(item.get('round_ref') or 0),
        int(item.get('round_current') or 0),
        str(item.get('display_label') or ''),
    ))
    dedup_hits: dict[str, dict[str, Any]] = {}
    for item in sorted(all_hits, key=lambda entry: (
        int(entry.get('raw_index') or 0),
        int(entry.get('round_ref') or 0),
        str(entry.get('level') or ''),
        str(entry.get('id') or ''),
    )):
        dedup_hits[str(item.get('id') or '')] = item
    return all_lines, list(dedup_hits.values())


def with_level_rhythm_overlay(level: str, level_payload: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    if not _enabled(config):
        return level_payload
    calc_mode = _normalize_calc_mode(config)
    # a_replay_trainer.py does not cap rhythm lines or 1.382 hits here.
    # Keep exported data authoritative; any UI-side take()/virtualization is display-only.
    max_lines = 0
    max_hits_per_line = 0

    all_lines, all_hits = _build_rhythm_structures(
        level_payload=level_payload,
        calc_mode=calc_mode,
        max_lines=max_lines,
        max_hits_per_line=max_hits_per_line,
    )

    patched = dict(level_payload)
    patched['rhythm_lines'] = all_lines
    patched['rhythm_hits'] = all_hits
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update({
        'rhythm_1382_enabled': True,
        'rhythm_calc_mode': calc_mode,
        'rhythm_line_count': len(all_lines),
        'rhythm_hit_count': len(all_hits),
        'rhythm_policy': 'backend parent-child rhythm overlay ported from chan_month5 full-optimization a_replay_trainer.py; Dart only parses/renders',
        'rhythm_mapping_policy': 'fx->bi, bi->seg, seg->segseg when exported seg_layers[2] is available',
        'rhythm_1382_cap_policy': 'trainer parity: backend rhythm export is uncapped; Flutter may still display a subset for performance',
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
            'rhythm_1382_overlay_source': 'a_replay_trainer_parent_child_port',
        })
        patched_snapshot['meta'] = meta
        return patched_snapshot

    patched = patch_snapshot(result)
    frames = patched.get('frames')
    if isinstance(frames, list):
        patched['frames'] = [patch_snapshot(frame) for frame in frames]
    return patched
