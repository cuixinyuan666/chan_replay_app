from __future__ import annotations

from time import perf_counter
from typing import Any, Iterable

from .a_bsp_scanner import get_tradable_stocks
from .a_multilevel_engine_timed import analyze_multi
from .easy_tdx_provider import infer_market, normalize_symbol

SOURCE_POLICY = 'original chan.py BSP + native LevelRelation only'
RULES: dict[str, dict[str, set[str]]] = {
    'DAILY_2B_MIN30_1B': {'high_types': {'B2', 'B2S', '2', '2S'}, 'low_types': {'B1', '1'}},
    'DAILY_3B_MIN30_1B': {'high_types': {'B3', 'B3A', 'B3B', '3', '3A', '3B'}, 'low_types': {'B1', '1'}},
    'DAILY_3B_MIN30_2B': {'high_types': {'B3', 'B3A', 'B3B', '3', '3A', '3B'}, 'low_types': {'B2', 'B2S', '2', '2S'}},
}


def _elapsed_ms(start: float) -> int:
    return int((perf_counter() - start) * 1000)


def _normalize_code(value: Any) -> str:
    code = normalize_symbol(str(value or ''))
    digits = ''.join(ch for ch in code if ch.isdigit())[-6:]
    return digits or code


def _payload_symbols(value: Any) -> list[Any] | None:
    if isinstance(value, str):
        rows = [part.strip() for part in value.replace('，', ',').split(',') if part.strip()]
        return rows or None
    return value if isinstance(value, list) else None


def _levels(value: Any) -> list[str]:
    if isinstance(value, str):
        rows = [part.strip().upper() for part in value.replace('，', ',').split(',') if part.strip()]
    elif isinstance(value, list):
        rows = [str(item).strip().upper() for item in value if str(item).strip()]
    else:
        rows = []
    if len(rows) < 2:
        rows = ['DAILY', 'MIN30', 'MIN5']
    return rows


def _level_payload(result: dict[str, Any], level: str) -> dict[str, Any]:
    levels = result.get('levels')
    if isinstance(levels, dict):
        value = levels.get(level.upper())
        if isinstance(value, dict):
            return value
    return {}


def _bsps(level_payload: dict[str, Any]) -> list[dict[str, Any]]:
    raw = level_payload.get('bsp') or level_payload.get('bsps') or []
    return [item for item in raw if isinstance(item, dict)] if isinstance(raw, list) else []


def _raw_index(row: dict[str, Any]) -> int | None:
    for key in ('raw_index', 'rawIndex', 'raw_idx', 'idx', 'index'):
        try:
            return int(row.get(key))
        except Exception:
            pass
    return None


def _bsp_type(row: dict[str, Any]) -> str:
    return str(row.get('type') or row.get('bsp_type') or row.get('bs_type') or '').strip()


def _type_key(value: Any) -> str:
    return ''.join(ch for ch in str(value or '').upper().replace('BUY', 'B').replace('SELL', 'S') if ch.isalnum())


def _relation_pair(row: dict[str, Any]) -> str:
    parent = row.get('parent_level') or row.get('parentLevel') or ''
    child = row.get('child_level') or row.get('childLevel') or ''
    return f'{parent}->{child}'


def _relation_child_range(row: dict[str, Any]) -> tuple[int | None, int | None]:
    try:
        start = int(row.get('child_start_raw_index', row.get('childStartRawIndex')))
        end = int(row.get('child_end_raw_index', row.get('childEndRawIndex')))
        return start, end
    except Exception:
        return None, None


def _parent_raw(row: dict[str, Any]) -> int | None:
    try:
        return int(row.get('parent_raw_index', row.get('parentRawIndex')))
    except Exception:
        return None


def _bsp_id(level: str, bsp: dict[str, Any]) -> str:
    return f"{level}#{bsp.get('index', bsp.get('idx', ''))}:raw={_raw_index(bsp)}:type={_bsp_type(bsp)}"


def _scan_rule(rule_name: str, parent_level: str, child_level: str, high_bsps: list[dict[str, Any]], low_bsps: list[dict[str, Any]], relations: list[dict[str, Any]], *, scope: str, frame_index: int | None) -> list[dict[str, Any]]:
    rule = RULES[rule_name]
    pair = f'{parent_level}->{child_level}'
    matches: list[dict[str, Any]] = []
    for high in high_bsps:
        if _type_key(_bsp_type(high)) not in rule['high_types']:
            continue
        high_raw = _raw_index(high)
        for relation in relations:
            if _relation_pair(relation) != pair:
                continue
            parent_raw = _parent_raw(relation)
            if high_raw is not None and parent_raw is not None and high_raw != parent_raw:
                continue
            child_start, child_end = _relation_child_range(relation)
            if child_start is None or child_end is None:
                continue
            for low in low_bsps:
                low_raw = _raw_index(low)
                if low_raw is None or not (child_start <= low_raw <= child_end):
                    continue
                if _type_key(_bsp_type(low)) not in rule['low_types']:
                    continue
                matches.append({
                    'scope': scope,
                    'frame_index': frame_index,
                    'rule_mode_name': rule_name,
                    'source_bsp_identifiers': f'{_bsp_id(parent_level, high)};{_bsp_id(child_level, low)}',
                    'source_target_levels': pair,
                    'native_relation_range': f'parent={parent_raw}:child={child_start}-{child_end}',
                    'strict_step_visibility': 'root snapshot' if frame_index is None else 'current strict step frame only; no final snapshot signal confirmation',
                    'state': 'candidate',
                    'jump_target': {'target_level': child_level, 'raw_index': low_raw, 'source': 'low-level trigger BSP raw index'},
                    'high': {'level': parent_level, 'raw_index': high_raw, 'type': _bsp_type(high), 'time': high.get('time'), 'price': high.get('price')},
                    'low': {'level': child_level, 'raw_index': low_raw, 'type': _bsp_type(low), 'time': low.get('time'), 'price': low.get('price')},
                })
    return matches


def _scan_result(result: dict[str, Any], parent_level: str, child_level: str, rule_names: Iterable[str]) -> list[dict[str, Any]]:
    relations = [r for r in result.get('relations', []) if isinstance(r, dict)] if isinstance(result.get('relations'), list) else []
    high_bsps = _bsps(_level_payload(result, parent_level))
    low_bsps = _bsps(_level_payload(result, child_level))
    evidence: list[dict[str, Any]] = []
    for rule_name in rule_names:
        if rule_name in RULES:
            evidence.extend(_scan_rule(rule_name, parent_level, child_level, high_bsps, low_bsps, relations, scope='root_snapshot', frame_index=None))
    frames = result.get('frames')
    if isinstance(frames, list):
        for idx, frame in enumerate(frames):
            if not isinstance(frame, dict):
                continue
            frame_levels = frame.get('levels') if isinstance(frame.get('levels'), dict) else {}
            frame_relations = [r for r in frame.get('relations', []) if isinstance(r, dict)] if isinstance(frame.get('relations'), list) else relations
            frame_high = _bsps(frame_levels.get(parent_level, {}) if isinstance(frame_levels.get(parent_level), dict) else {})
            frame_low = _bsps(frame_levels.get(child_level, {}) if isinstance(frame_levels.get(child_level), dict) else {})
            for rule_name in rule_names:
                if rule_name in RULES:
                    evidence.extend(_scan_rule(rule_name, parent_level, child_level, frame_high, frame_low, frame_relations, scope='strict_step_frame', frame_index=idx))
    return evidence


def _analyze(payload: dict[str, Any], code: str, market: str, levels: list[str], mode: str) -> dict[str, Any]:
    config = payload.get('config') if isinstance(payload.get('config'), dict) else {}
    effective_config = {
        'bi_algo': config.get('bi_algo', 'normal'),
        'seg_algo': config.get('seg_algo', 'chan'),
        'zs_algo': config.get('zs_algo', 'normal'),
        'max_step_frames': int(payload.get('max_step_frames') or config.get('max_step_frames') or 1000),
        'include_bars_in_frames': bool(config.get('include_bars_in_frames', False)),
        'include_indicators_in_frames': bool(config.get('include_indicators_in_frames', False)),
        'frame_policy': str(config.get('frame_policy') or 'full'),
        'frame_stride': int(config.get('frame_stride') or 1),
        'max_return_frames': int(payload.get('max_return_frames') or config.get('max_return_frames') or 1000),
    }
    return analyze_multi(
        symbol=code,
        market=market,
        levels=levels,
        adjust=str(payload.get('adjust') or 'QFQ'),
        mode=mode,
        main_level=payload.get('main_level') or levels[0],
        clock_level=payload.get('clock_level') or levels[0],
        start=payload.get('start'),
        end=payload.get('end'),
        count=int(payload.get('count') or 900),
        config=effective_config,
    )


def scan_s8_market(payload: dict[str, Any]) -> dict[str, Any]:
    started = perf_counter()
    levels = _levels(payload.get('levels') or payload.get('lv_list'))
    parent_level = str(payload.get('parent_level') or levels[0]).upper()
    child_level = str(payload.get('child_level') or (levels[1] if len(levels) > 1 else 'MIN30')).upper()
    rule_names = payload.get('rules') if isinstance(payload.get('rules'), list) else list(RULES)
    rule_names = [str(item) for item in rule_names if str(item) in RULES] or list(RULES)
    limit = max(1, min(int(payload.get('limit') or 300), 5000))
    max_candidates = max(1, min(int(payload.get('max_candidates') or 50), 5000))
    step_confirm = bool(payload.get('step_confirm') or False)
    rows = get_tradable_stocks(symbols=_payload_symbols(payload.get('symbols')), limit=limit)
    candidates: list[dict[str, Any]] = []
    attempts: list[dict[str, Any]] = []
    for idx, row in enumerate(rows):
        code = _normalize_code(row.get('code'))
        market = str(row.get('market') or infer_market(code)).upper()
        phase_start = perf_counter()
        try:
            once = _analyze(payload, code, market, levels, 'once')
            once_matches = _scan_result(once, parent_level, child_level, rule_names)
            attempts.append({'code': f'{code}.{market}', 'phase': 'once_prefilter', 'ok': bool(once.get('ok', True)), 'matched_count': len(once_matches), 'elapsed_ms': _elapsed_ms(phase_start)})
            matches = once_matches
            phase = 'once_prefilter'
            if step_confirm and once_matches:
                step_start = perf_counter()
                step = _analyze(payload, code, market, levels, 'step')
                step_matches = _scan_result(step, parent_level, child_level, rule_names)
                attempts.append({'code': f'{code}.{market}', 'phase': 'step_confirm', 'ok': bool(step.get('ok', True)), 'matched_count': len(step_matches), 'elapsed_ms': _elapsed_ms(step_start)})
                matches = step_matches
                phase = 'step_confirm'
            for match in matches:
                jump = match.get('jump_target') if isinstance(match.get('jump_target'), dict) else {}
                candidates.append({
                    'symbol': code,
                    'market': market,
                    'code': f'{code}.{market}',
                    'name': str(row.get('name') or code),
                    'phase': phase,
                    'rule_mode_name': match.get('rule_mode_name'),
                    'source_bsp_identifiers': match.get('source_bsp_identifiers'),
                    'source_target_levels': match.get('source_target_levels'),
                    'native_relation_range': match.get('native_relation_range'),
                    'strict_step_visibility': match.get('strict_step_visibility'),
                    'state': match.get('state'),
                    'jump_target': jump,
                    'jump': {'symbol': code, 'market': market, 'level': jump.get('target_level'), 'raw_index': jump.get('raw_index')},
                    'candidate_policy': 'candidate signal only; not a trading recommendation',
                    'source_policy': SOURCE_POLICY,
                })
                if len(candidates) >= max_candidates:
                    break
        except Exception as exc:
            attempts.append({'code': f'{code}.{market}', 'phase': 'error', 'ok': False, 'error': str(exc)[:180], 'elapsed_ms': _elapsed_ms(phase_start)})
        if len(candidates) >= max_candidates:
            break
    return {
        'ok': True,
        'sample_kind': 's8_strategy_realtime_candidates_v1',
        'source_policy': SOURCE_POLICY,
        'dart_chan_calculation': False,
        'chan_recalculated': False,
        'request': {'levels': levels, 'parent_level': parent_level, 'child_level': child_level, 'rules': rule_names, 'limit': limit, 'max_candidates': max_candidates, 'step_confirm': step_confirm},
        'summary': {'stock_count': len(rows), 'candidate_count': len(candidates), 'attempt_count': len(attempts), 'elapsed_ms': _elapsed_ms(started)},
        'candidates': candidates,
        'attempts': attempts,
    }
