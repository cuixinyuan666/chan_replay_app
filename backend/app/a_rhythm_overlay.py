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
RHYTHM_SOURCE_LABELS = {
    'fx': '分型',
    'bi': '笔',
    'seg': '线段',
}


@dataclass(frozen=True)
class _Pivot:
    raw_index: int
    price: float
    side: str
    source_index: int


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


def _unique_sorted(pivots: list[_Pivot]) -> list[_Pivot]:
    keyed: dict[tuple[int, str, int], _Pivot] = {}
    for pivot in pivots:
        keyed[(pivot.raw_index, pivot.side, pivot.source_index)] = pivot
    return [keyed[key] for key in sorted(keyed)]


def _fx_pivots(level_payload: dict[str, Any]) -> list[_Pivot]:
    result: list[_Pivot] = []
    rows = level_payload.get('fx')
    if not isinstance(rows, list):
        return result
    for seq, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        raw_index = _to_int(row.get('raw_index') or row.get('rawIndex'), -1)
        price = row.get('price')
        if raw_index < 0 or price is None:
            continue
        text = str(row.get('type') or '').lower()
        side = 'top' if 'top' in text else 'bottom'
        result.append(_Pivot(raw_index=raw_index, price=_to_float(price), side=side, source_index=_to_int(row.get('index'), seq)))
    return _unique_sorted(result)


def _line_pivots(rows: Any, kind: str) -> list[_Pivot]:
    result: list[_Pivot] = []
    if not isinstance(rows, list):
        return result
    for seq, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        start_raw = _to_int(row.get('start_raw_index') or row.get('startRawIndex'), -1)
        end_raw = _to_int(row.get('end_raw_index') or row.get('endRawIndex'), -1)
        start_price = row.get('start_price') if 'start_price' in row else row.get('startPrice')
        end_price = row.get('end_price') if 'end_price' in row else row.get('endPrice')
        direction = str(row.get('direction') or '').lower()
        index = _to_int(row.get('index'), seq)
        if start_raw >= 0 and start_price is not None:
            result.append(_Pivot(raw_index=start_raw, price=_to_float(start_price), side='top' if 'down' in direction else 'bottom', source_index=index * 2))
        if end_raw >= 0 and end_price is not None:
            result.append(_Pivot(raw_index=end_raw, price=_to_float(end_price), side='bottom' if 'down' in direction else 'top', source_index=index * 2 + 1))
    return _unique_sorted(result)


def _rhythm_threshold(prev_same: _Pivot, opposite: _Pivot) -> tuple[str, float]:
    if prev_same.side == 'top':
        return 'UP', opposite.price + (prev_same.price - opposite.price) * RHYTHM_RATIO
    return 'DOWN', opposite.price - (opposite.price - prev_same.price) * RHYTHM_RATIO


def _retrace_allowed(dir_text: str, current_same: _Pivot, threshold: float, calc_mode: str) -> bool:
    if calc_mode == RHYTHM_CALC_MODE_STRICT_1382:
        return current_same.price >= threshold if dir_text == 'UP' else current_same.price <= threshold
    if calc_mode == RHYTHM_CALC_MODE_TRANSITION:
        return current_same.price > threshold if dir_text == 'UP' else current_same.price < threshold
    return True


def _find_hits(
    *,
    bars: list[Any],
    level: str,
    source_kind: str,
    line_id: str,
    display_label: str,
    start_raw_index: int,
    threshold: float,
    dir_text: str,
    max_hits: int,
) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    if not bars:
        return hits
    for raw_index in range(max(0, start_raw_index + 1), len(bars)):
        row = bars[raw_index]
        high = _bar_high(row)
        low = _bar_low(row)
        if dir_text == 'UP':
            touched = high is not None and high >= threshold
            trigger_price = high
        else:
            touched = low is not None and low <= threshold
            trigger_price = low
        if not touched:
            continue
        hit_id = f'{line_id}_hit_{len(hits) + 1}_{raw_index}'
        hits.append({
            'id': hit_id,
            'line_id': line_id,
            'level': level,
            'source_kind': source_kind,
            'raw_index': raw_index,
            'time': _bar_time(row),
            'price': trigger_price,
            'threshold': threshold,
            'dir': dir_text,
            'display_label': display_label,
            'detail': f'{level} {RHYTHM_SOURCE_LABELS.get(source_kind, source_kind)} {display_label} {dir_text} threshold={threshold:.4f} trigger={float(trigger_price or threshold):.4f}',
        })
        if len(hits) >= max_hits:
            break
    return hits


def _build_for_pivots(
    *,
    level: str,
    source_kind: str,
    pivots: list[_Pivot],
    bars: list[Any],
    calc_mode: str,
    max_lines: int,
    max_hits_per_line: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    lines: list[dict[str, Any]] = []
    hits: list[dict[str, Any]] = []
    by_side: dict[str, list[_Pivot]] = {'top': [], 'bottom': []}
    for pivot in pivots:
        by_side.setdefault(pivot.side, []).append(pivot)
    for side, same_side in by_side.items():
        if len(same_side) < 2:
            continue
        for same_pos in range(1, len(same_side)):
            prev_same = same_side[same_pos - 1]
            current_same = same_side[same_pos]
            between = [p for p in pivots if prev_same.raw_index < p.raw_index < current_same.raw_index and p.side != side]
            if not between:
                continue
            opposite = min(between, key=lambda p: p.price) if side == 'top' else max(between, key=lambda p: p.price)
            dir_text, threshold = _rhythm_threshold(prev_same, opposite)
            if not _retrace_allowed(dir_text, current_same, threshold, calc_mode):
                continue
            round_ref = same_pos
            display_label = f'节奏线{round_ref}-1'
            line_id = f'rhythm_{level}_{source_kind}_{side}_{prev_same.raw_index}_{opposite.raw_index}_{current_same.raw_index}'
            ratio_base = abs(prev_same.price - opposite.price)
            ratio = 0.0 if ratio_base == 0 else abs(current_same.price - opposite.price) / ratio_base
            line = {
                'id': line_id,
                'level': level,
                'source_kind': source_kind,
                'source_label': RHYTHM_SOURCE_LABELS.get(source_kind, source_kind),
                'calc_mode': calc_mode,
                'ratio': ratio,
                'threshold_ratio': RHYTHM_RATIO,
                'dir': dir_text,
                'round_current': same_pos + 1,
                'round_ref': round_ref,
                'layer': 1,
                'display_label': display_label,
                'label_left': display_label,
                'label_right': f'{ratio:.3f}',
                'x1': prev_same.raw_index,
                'y1': threshold,
                'x2': current_same.raw_index,
                'y2': threshold,
                'threshold': threshold,
                'price': threshold,
                'prev_same_raw_index': prev_same.raw_index,
                'opposite_raw_index': opposite.raw_index,
                'current_same_raw_index': current_same.raw_index,
                'current_same_price': current_same.price,
                'backend_authority': 'python_backend_rhythm_overlay_from_chanpy_exported_structures',
            }
            lines.append(line)
            hits.extend(_find_hits(
                bars=bars,
                level=level,
                source_kind=source_kind,
                line_id=line_id,
                display_label=display_label,
                start_raw_index=current_same.raw_index,
                threshold=threshold,
                dir_text=dir_text,
                max_hits=max_hits_per_line,
            ))
            if len(lines) >= max_lines:
                return lines, hits
    return lines, hits


def with_level_rhythm_overlay(level: str, level_payload: dict[str, Any], config: dict[str, Any] | None = None) -> dict[str, Any]:
    if not _enabled(config):
        return level_payload
    calc_mode = _normalize_calc_mode(config)
    max_lines = _to_int((config or {}).get('rhythm_max_lines'), 120)
    max_hits_per_line = _to_int((config or {}).get('rhythm_max_hits_per_line'), 3)
    bars = level_payload.get('bars') if isinstance(level_payload.get('bars'), list) else []
    all_lines: list[dict[str, Any]] = []
    all_hits: list[dict[str, Any]] = []
    sources = [
        ('fx', _fx_pivots(level_payload)),
        ('bi', _line_pivots(level_payload.get('bi'), 'bi')),
        ('seg', _line_pivots(level_payload.get('seg'), 'seg')),
    ]
    for source_kind, pivots in sources:
        lines, hits = _build_for_pivots(
            level=level,
            source_kind=source_kind,
            pivots=pivots,
            bars=bars,
            calc_mode=calc_mode,
            max_lines=max(0, max_lines - len(all_lines)),
            max_hits_per_line=max_hits_per_line,
        )
        all_lines.extend(lines)
        all_hits.extend(hits)
        if len(all_lines) >= max_lines:
            break
    patched = dict(level_payload)
    patched['rhythm_lines'] = all_lines
    patched['rhythm_hits'] = all_hits
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta.update({
        'rhythm_1382_enabled': True,
        'rhythm_calc_mode': calc_mode,
        'rhythm_line_count': len(all_lines),
        'rhythm_hit_count': len(all_hits),
        'rhythm_policy': 'backend display overlay from chan.py exported FX/BI/SEG structures; Dart only parses/renders',
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
        })
        patched_snapshot['meta'] = meta
        return patched_snapshot

    patched = patch_snapshot(result)
    frames = patched.get('frames')
    if isinstance(frames, list):
        patched['frames'] = [patch_snapshot(frame) for frame in frames]
    return patched
