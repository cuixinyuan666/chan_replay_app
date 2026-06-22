from __future__ import annotations

from datetime import datetime, timedelta
from math import sqrt
from typing import Any


def _int(value: Any, default: int | None = None) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _num(value: Any) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _time(row: dict[str, Any]) -> Any:
    return row.get('dt') or row.get('time') or row.get('datetime') or row.get('date')


def _datetime(value: Any) -> datetime | None:
    text = str(value or '').strip().replace(' ', 'T').replace('/', '-')
    if not text:
        return None
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _canonical_type(value: Any) -> str:
    text = str(value or '').strip().lower()
    for prefix in ('buy', 'sell'):
        if text.startswith(prefix):
            text = text[len(prefix):]
            break
    if text[:1] in {'b', 's'}:
        text = text[1:]
    return text.strip()


def _is_buy(row: dict[str, Any]) -> bool:
    if 'is_buy' in row:
        return bool(row['is_buy'])
    return str(row.get('type') or '').strip().lower().startswith(('b', 'buy'))


def _bars(analysis: dict[str, Any], level: str) -> list[dict[str, Any]]:
    payload = (analysis.get('levels') or {}).get(level) if isinstance(analysis.get('levels'), dict) else None
    if not isinstance(payload, dict):
        return []
    return [row for row in payload.get('bars', []) if isinstance(row, dict)]


def _bar_raw_index(bar: dict[str, Any], fallback: int) -> int:
    return _int(bar.get('index'), fallback) or fallback


def _rule_conditions(rule: dict[str, Any]) -> list[dict[str, Any]]:
    rows = rule.get('conditions') if isinstance(rule, dict) else None
    return [dict(row) for row in rows or [] if isinstance(row, dict)]


def _match_condition(
    layer_rows: list[dict[str, Any]],
    condition: dict[str, Any],
    current_raw: int,
) -> dict[str, Any] | None:
    side = str(condition.get('side') or 'any').lower()
    allowed = {_canonical_type(value) for value in condition.get('types') or []}
    max_age = _int(condition.get('max_age_bars'))
    if max_age is not None:
        max_age = max(0, max_age)
    allow_unsure = bool(condition.get('allow_unsure', False))
    available: list[dict[str, Any]] = []
    for row in layer_rows:
        raw = _int(row.get('raw_index') if 'raw_index' in row else row.get('rawIndex'))
        if raw is None or raw > current_raw:
            continue
        if not allow_unsure and not bool(row.get('confirmed', row.get('is_sure', True))):
            continue
        available.append(row)
    if not available:
        return None
    latest = max(available, key=lambda row: _int(row.get('raw_index'), -1) or -1)
    raw = _int(latest.get('raw_index') if 'raw_index' in latest else latest.get('rawIndex'))
    if raw is None or (max_age is not None and current_raw - raw > max_age):
        return None
    is_buy = _is_buy(latest)
    if side == 'buy' and not is_buy:
        return None
    if side == 'sell' and is_buy:
        return None
    if allowed and _canonical_type(latest.get('type')) not in allowed:
        return None
    return latest


def _event_from_frame(
    frame: dict[str, Any],
    *,
    frame_index: int,
    bars: list[dict[str, Any]],
    level: str,
    conditions: list[dict[str, Any]],
) -> dict[str, Any] | None:
    frame_level = (
        (frame.get('levels') or {}).get(level)
        if isinstance(frame.get('levels'), dict)
        else None
    )
    if not isinstance(frame_level, dict):
        return None
    visible_count = _int(frame_level.get('visible_count'), 0) or 0
    if visible_count <= 0 or visible_count > len(bars):
        return None
    bar_index = visible_count - 1
    current_raw = _bar_raw_index(bars[bar_index], bar_index)
    grouped = frame_level.get('seg_bsp_history_layers') or frame_level.get('seg_bsp_layers')
    if not isinstance(grouped, dict):
        return None

    matched: list[dict[str, Any]] = []
    for condition in conditions:
        layer = max(2, _int(condition.get('layer'), 2) or 2)
        source = grouped.get(str(layer), grouped.get(layer, []))
        rows = [row for row in source or [] if isinstance(row, dict)]
        point = _match_condition(rows, condition, current_raw)
        if point is None:
            return None
        matched.append({'layer': layer, **point})

    return {
        'frame_index': frame_index,
        'level': level,
        'raw_index': current_raw,
        'bar_index': bar_index,
        'time': _time(bars[bar_index]),
        'matched': matched,
        'signature': [
            f"{row['layer']}段{_canonical_type(row.get('type'))}"
            for row in matched
        ],
    }


def _event_key(event: dict[str, Any]) -> tuple[tuple[int, int, str], ...]:
    return tuple(
        (
            int(row['layer']),
            _int(row.get('raw_index'), -1) or -1,
            str(row.get('type') or ''),
        )
        for row in event.get('matched', [])
        if isinstance(row, dict)
    )


def scan_seg_composite_events(
    analysis: dict[str, Any],
    *,
    level: str,
    rule: dict[str, Any],
) -> list[dict[str, Any]]:
    """Evaluate a segN AND-rule against each historical step frame.

    Only authoritative ``seg_bsp_layers`` rows are considered. Endpoint
    candidates are intentionally excluded, preserving as-of/no-future semantics.
    """
    frames = [frame for frame in analysis.get('frames', []) if isinstance(frame, dict)]
    bars = _bars(analysis, level)
    conditions = _rule_conditions(rule)
    if not frames or not bars or not conditions:
        return []

    events: list[dict[str, Any]] = []
    last_signature: tuple[tuple[int, int, str], ...] | None = None
    for frame_index, frame in enumerate(frames):
        event = _event_from_frame(
            frame,
            frame_index=frame_index,
            bars=bars,
            level=level,
            conditions=conditions,
        )
        if event is None:
            last_signature = None
            continue
        signature = _event_key(event)
        if bool(rule.get('dedupe', True)) and signature == last_signature:
            continue
        last_signature = signature
        events.append(event)
    return events


def _execution_price(bar: dict[str, Any], *, buy: bool, slippage: float) -> float | None:
    price = _num(bar.get('open')) or _num(bar.get('close'))
    if price is None:
        return None
    return price * (1 + slippage if buy else 1 - slippage)


def _summary(trades: list[dict[str, Any]], equity_curve: list[dict[str, Any]]) -> dict[str, Any]:
    returns = [float(row['net_return']) for row in trades]
    wins = [value for value in returns if value > 0]
    losses = [value for value in returns if value <= 0]
    gross_profit = sum(wins)
    gross_loss = abs(sum(losses))
    peak = 1.0
    max_drawdown = 0.0
    for point in equity_curve:
        equity = float(point['equity'])
        peak = max(peak, equity)
        max_drawdown = min(max_drawdown, equity / peak - 1.0)
    avg = sum(returns) / len(returns) if returns else 0.0
    variance = sum((value - avg) ** 2 for value in returns) / max(1, len(returns) - 1)
    return {
        'trade_count': len(trades),
        'win_count': len(wins),
        'loss_count': len(losses),
        'win_rate': len(wins) / len(trades) if trades else None,
        'avg_return': avg,
        'avg_win': sum(wins) / len(wins) if wins else 0.0,
        'avg_loss': sum(losses) / len(losses) if losses else 0.0,
        'payoff_ratio': None if not losses or sum(losses) == 0 else abs((sum(wins) / max(1, len(wins))) / (sum(losses) / len(losses))),
        'profit_factor': None if gross_loss == 0 else gross_profit / gross_loss,
        'expectancy': avg,
        'return_std': sqrt(max(0.0, variance)),
        'max_drawdown': max_drawdown,
        'total_return': equity_curve[-1]['equity'] - 1.0 if equity_curve else 0.0,
        'final_equity': equity_curve[-1]['equity'] if equity_curve else 1.0,
    }


def _backtest_from_events(
    *,
    bars: list[dict[str, Any]],
    level: str,
    entry_events: list[dict[str, Any]],
    exit_events: list[dict[str, Any]],
    options: dict[str, Any] | None = None,
) -> dict[str, Any]:
    opts = options or {}
    fee = float(opts.get('fee_bps', 3.0)) / 10000.0
    slippage = float(opts.get('slippage_bps', 2.0)) / 10000.0
    hold_days = _int(opts.get('max_hold_days'))
    hold_bars = _int(opts.get('max_hold_bars'))

    trades: list[dict[str, Any]] = []
    equity_curve: list[dict[str, Any]] = [
        {'raw_index': 0, 'time': _time(bars[0]) if bars else None, 'equity': 1.0}
    ]
    cursor = -1
    equity = 1.0
    for event in entry_events:
        signal_bar = int(event['bar_index'])
        entry_index = signal_bar + 1
        if entry_index >= len(bars) or entry_index <= cursor:
            continue
        entry_price = _execution_price(bars[entry_index], buy=True, slippage=slippage)
        if entry_price is None:
            continue

        candidates: list[tuple[int, str, dict[str, Any] | None]] = []
        for exit_event in exit_events:
            exit_signal = int(exit_event['bar_index'])
            if exit_signal >= entry_index and exit_signal + 1 < len(bars):
                candidates.append((exit_signal + 1, 'seg_composite_exit', exit_event))
                break
        if hold_bars is not None:
            candidates.append(
                (min(len(bars) - 1, entry_index + max(1, hold_bars)), 'max_hold_bars', None)
            )
        if hold_days is not None:
            entry_dt = _datetime(_time(bars[entry_index]))
            if entry_dt is not None:
                target = entry_dt + timedelta(days=max(1, hold_days))
                for index in range(entry_index + 1, len(bars)):
                    current = _datetime(_time(bars[index]))
                    if current is not None and current >= target:
                        candidates.append((index, 'max_hold_days', None))
                        break
        if not candidates:
            candidates.append((len(bars) - 1, 'end_of_data', None))
        exit_index, exit_reason, exit_event = min(candidates, key=lambda item: item[0])
        exit_price = _execution_price(bars[exit_index], buy=False, slippage=slippage)
        if exit_price is None:
            continue
        gross_return = (exit_price - entry_price) / entry_price
        net_return = gross_return - fee * 2
        equity *= 1 + net_return
        cursor = exit_index
        trade = {
            'level': level,
            'entry_signal_raw_index': event['raw_index'],
            'entry_signal_time': event['time'],
            'entry_index': entry_index,
            'entry_raw_index': _bar_raw_index(bars[entry_index], entry_index),
            'entry_time': _time(bars[entry_index]),
            'entry_price': entry_price,
            'entry_signature': event['signature'],
            'exit_index': exit_index,
            'exit_raw_index': _bar_raw_index(bars[exit_index], exit_index),
            'exit_time': _time(bars[exit_index]),
            'exit_price': exit_price,
            'exit_reason': exit_reason,
            'exit_signature': exit_event['signature'] if exit_event else [],
            'hold_bars': exit_index - entry_index,
            'gross_return': gross_return,
            'net_return': net_return,
            'equity': equity,
        }
        trades.append(trade)
        equity_curve.append({
            'raw_index': trade['exit_raw_index'],
            'time': trade['exit_time'],
            'equity': equity,
            'drawdown': None,
        })

    peak = 1.0
    for point in equity_curve:
        peak = max(peak, float(point['equity']))
        point['drawdown'] = float(point['equity']) / peak - 1.0
    return {
        'ok': True,
        'level': level,
        'entry_events': entry_events,
        'exit_events': exit_events,
        'trades': trades,
        'equity_curve': equity_curve,
        'summary': _summary(trades, equity_curve),
        'meta': {
            'source': 'origin_vespa_tdx.backend.a_seg_composite_strategy',
            'signal_source': 'step frames authoritative seg_bsp_layers only',
            'endpoint_candidates_used': False,
            'same_bar_lookahead': False,
            'execution': 'next_bar_open_or_close_fallback',
        },
    }


def run_seg_composite_backtest(
    analysis: dict[str, Any],
    *,
    level: str,
    entry_rule: dict[str, Any],
    exit_rule: dict[str, Any] | None = None,
    options: dict[str, Any] | None = None,
) -> dict[str, Any]:
    bars = _bars(analysis, level)
    entry_events = scan_seg_composite_events(analysis, level=level, rule=entry_rule)
    exit_events = scan_seg_composite_events(
        analysis, level=level, rule=exit_rule or {'conditions': []}) if exit_rule else []
    return _backtest_from_events(
        bars=bars,
        level=level,
        entry_events=entry_events,
        exit_events=exit_events,
        options=options,
    )


def run_seg_composite_stream_backtest(
    *,
    symbol: str,
    market: str | None,
    levels: list[str] | str | None,
    level: str | None,
    adjust: str = 'QFQ',
    start: str | None = None,
    end: str | None = None,
    count: int = 50000,
    config: dict[str, Any] | None = None,
    entry_rule: dict[str, Any],
    exit_rule: dict[str, Any] | None = None,
    options: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Scan the complete data window incrementally without returning all frames."""
    from .a_multilevel_native_engine import (
        _load_aligned_bars_by_level,
        _normalize_levels,
        _prepare_native_chan,
    )
    from .a_multilevel_native_timed_recursive_engine import (
        _advance_step_histories_light,
        _latest_level_position,
    )
    from .a_recursive_seg_manager import RecursiveSegRuntimeState
    from .easy_tdx_provider import infer_market, normalize_symbol

    code = normalize_symbol(symbol)
    market_name = (market or infer_market(code)).upper()
    level_order = _normalize_levels(levels)
    signal_level = (level or level_order[0]).upper()
    if signal_level not in level_order:
        raise ValueError(f'signal level {signal_level} is not in levels {level_order}')
    entry_conditions = _rule_conditions(entry_rule)
    if not entry_conditions:
        raise ValueError('entry_rule.conditions must not be empty')
    exit_conditions = _rule_conditions(exit_rule or {})

    bars_by_level, data_meta = _load_aligned_bars_by_level(
        code=code,
        market_name=market_name,
        level_order=level_order,
        adjust=adjust,
        count=count,
        start=start,
        end=end,
    )
    exporter, chan, kl_types, prepared_code = _prepare_native_chan(
        code=code,
        level_order=level_order,
        bars_by_level=bars_by_level,
        adjust=adjust,
        config=config,
        trigger_step=True,
    )
    step_iter = getattr(chan, 'step_load', None)
    if not callable(step_iter):
        raise RuntimeError('native CChan(lv_list) does not expose step_load')

    bars = bars_by_level[signal_level]
    entry_events: list[dict[str, Any]] = []
    exit_events: list[dict[str, Any]] = []
    last_entry_key: tuple[tuple[int, int, str], ...] | None = None
    last_exit_key: tuple[tuple[int, int, str], ...] | None = None
    runtime_states: dict[str, RecursiveSegRuntimeState] = {}
    base_bsp_histories: dict[str, dict[tuple[str, int, bool], dict[str, Any]]] = {}
    timing: dict[str, Any] = {}
    total_frames = 0

    for frame_index, cur_chan in enumerate(step_iter()):
        _advance_step_histories_light(
            exporter=exporter,
            chan=cur_chan,
            kl_types=kl_types,
            level_order=level_order,
            config=config,
            runtime_states=runtime_states,
            base_bsp_histories=base_bsp_histories,
        )
        for level_name, state in runtime_states.items():
            if state.errors:
                raise RuntimeError(
                    f'recursive seg failed at frame {frame_index}, '
                    f'level {level_name}: {state.errors}'
                )
        signal_state = runtime_states[signal_level]
        signal_obj = exporter.get_level(
            cur_chan,
            kl_types[level_order.index(signal_level)],
        )
        current_raw, _ = _latest_level_position(signal_obj)
        if current_raw is None or current_raw < 0 or current_raw >= len(bars):
            total_frames += 1
            continue
        grouped: dict[str, list[dict[str, Any]]] = {}
        for layer, history in signal_state.bsp_history.items():
            if not history:
                grouped[str(layer)] = []
                continue
            latest = max(
                history.values(),
                key=lambda row: _int(
                    row.get('recognized_raw_index', row.get('raw_index')),
                    -1,
                ) or -1,
            )
            grouped[str(layer)] = [latest]
        frame = {
            'levels': {
                signal_level: {
                    'visible_count': current_raw + 1,
                    'seg_bsp_history_layers': grouped,
                },
            },
        }

        entry_event = _event_from_frame(
            frame,
            frame_index=frame_index,
            bars=bars,
            level=signal_level,
            conditions=entry_conditions,
        )
        if entry_event is None:
            last_entry_key = None
        else:
            entry_key = _event_key(entry_event)
            if not bool(entry_rule.get('dedupe', True)) or entry_key != last_entry_key:
                entry_events.append(entry_event)
            last_entry_key = entry_key

        if exit_conditions:
            exit_event = _event_from_frame(
                frame,
                frame_index=frame_index,
                bars=bars,
                level=signal_level,
                conditions=exit_conditions,
            )
            if exit_event is None:
                last_exit_key = None
            else:
                exit_key = _event_key(exit_event)
                if not bool((exit_rule or {}).get('dedupe', True)) or exit_key != last_exit_key:
                    exit_events.append(exit_event)
                last_exit_key = exit_key
        total_frames += 1

    result = _backtest_from_events(
        bars=bars,
        level=signal_level,
        entry_events=entry_events,
        exit_events=exit_events,
        options=options,
    )
    result['meta'].update({
        'scan_mode': 'full_window_incremental_step',
        'returned_step_frames': 0,
        'evaluated_step_frames': total_frames,
        'symbol': code,
        'market': market_name,
        'levels': level_order,
        'adjust': adjust.upper(),
        'prepared_code': prepared_code,
        'data_window': data_meta,
        'timing': timing,
    })
    return result
