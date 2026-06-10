from __future__ import annotations

from typing import Any


def _num(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _get(row: dict[str, Any], *keys: str, default: Any = None) -> Any:
    for key in keys:
        if key in row:
            return row[key]
    return default


def _open(row: dict[str, Any]) -> float | None:
    return _num(_get(row, 'open', 'o'))


def _close(row: dict[str, Any]) -> float | None:
    return _num(_get(row, 'close', 'c'))


def _high(row: dict[str, Any]) -> float | None:
    return _num(_get(row, 'high', 'h'))


def _low(row: dict[str, Any]) -> float | None:
    return _num(_get(row, 'low', 'l'))


def _time(row: dict[str, Any]) -> Any:
    return _get(row, 'time', 'dt', 'datetime', 'date')


def _is_buy(row: dict[str, Any]) -> bool:
    if 'is_buy' in row:
        return bool(row.get('is_buy'))
    return str(row.get('type', '')).upper().startswith('B')


def _entry_price(bars: list[dict[str, Any]], raw_index: int, slippage: float) -> tuple[int, float | None]:
    entry_idx = raw_index + 1
    if entry_idx >= len(bars):
        return entry_idx, None
    price = _open(bars[entry_idx]) or _close(bars[entry_idx])
    return entry_idx, None if price is None else price * (1.0 + slippage)


def _exit_price(bar: dict[str, Any], slippage: float) -> float | None:
    price = _close(bar)
    return None if price is None else price * (1.0 - slippage)


def _find_exit(
    bars: list[dict[str, Any]],
    signals: list[dict[str, Any]],
    entry_idx: int,
    entry_price: float,
    *,
    max_hold_bars: int,
    stop_loss_pct: float | None,
    take_profit_pct: float | None,
) -> tuple[int, str]:
    max_exit = min(len(bars) - 1, entry_idx + max_hold_bars)
    sell_indices = sorted(
        idx for idx in (_int(_get(s, 'raw_index', 'rawIndex')) for s in signals if not _is_buy(s))
        if idx is not None and idx > entry_idx
    )
    for i in range(entry_idx + 1, max_exit + 1):
        low = _low(bars[i])
        high = _high(bars[i])
        if stop_loss_pct is not None and low is not None and low <= entry_price * (1.0 - stop_loss_pct):
            return i, 'stop_loss'
        if take_profit_pct is not None and high is not None and high >= entry_price * (1.0 + take_profit_pct):
            return i, 'take_profit'
        if sell_indices and sell_indices[0] <= i:
            return i, 'sell_bsp'
    return max_exit, 'max_hold'


def run_bsp_backtest(analysis: dict[str, Any], *, options: dict[str, Any] | None = None) -> dict[str, Any]:
    """Run a simple long-only BSP backtest from exported analysis JSON.

    The engine buys on the next bar after an accepted buy BSP and exits on the
    next sell BSP, stop/take-profit, or max_hold_bars.  This avoids same-bar
    lookahead and keeps the backtest outside chan.py.
    """
    opts = options or {}
    bars = [row for row in analysis.get('bars', []) if isinstance(row, dict)]
    raw_signals = analysis.get('scores') or analysis.get('features') or analysis.get('bsp') or []
    signals = [row for row in raw_signals if isinstance(row, dict)]
    fee = float(opts.get('fee_bps', 3.0)) / 10000.0
    slippage = float(opts.get('slippage_bps', 2.0)) / 10000.0
    max_hold_bars = max(1, int(opts.get('max_hold_bars', 20)))
    min_score = opts.get('min_score')
    min_score_value = None if min_score is None else float(min_score)
    stop_loss_pct = opts.get('stop_loss_pct')
    take_profit_pct = opts.get('take_profit_pct')
    stop_loss_value = None if stop_loss_pct in (None, '') else float(stop_loss_pct)
    take_profit_value = None if take_profit_pct in (None, '') else float(take_profit_pct)
    allow_unsure = bool(opts.get('allow_unsure', False))

    buy_signals = sorted(
        [s for s in signals if _is_buy(s)],
        key=lambda s: _int(_get(s, 'raw_index', 'rawIndex')) or -1,
    )
    trades: list[dict[str, Any]] = []
    cursor = -1
    equity = 1.0
    for signal in buy_signals:
        raw_index = _int(_get(signal, 'raw_index', 'rawIndex'))
        if raw_index is None or raw_index <= cursor:
            continue
        if not allow_unsure and not bool(_get(signal, 'is_sure', 'isSure', 'confirmed', default=True)):
            continue
        score = _num(signal.get('ml_score'))
        if min_score_value is not None and (score is None or score < min_score_value):
            continue
        entry_idx, entry = _entry_price(bars, raw_index, slippage)
        if entry is None or entry_idx >= len(bars):
            continue
        exit_idx, reason = _find_exit(
            bars,
            signals,
            entry_idx,
            entry,
            max_hold_bars=max_hold_bars,
            stop_loss_pct=stop_loss_value,
            take_profit_pct=take_profit_value,
        )
        exit_ = _exit_price(bars[exit_idx], slippage)
        if exit_ is None:
            continue
        gross_return = (exit_ - entry) / entry
        net_return = gross_return - fee * 2.0
        equity *= 1.0 + net_return
        cursor = exit_idx
        trades.append({
            'entry_signal_index': raw_index,
            'entry_index': entry_idx,
            'entry_time': _time(bars[entry_idx]),
            'entry_price': entry,
            'exit_index': exit_idx,
            'exit_time': _time(bars[exit_idx]),
            'exit_price': exit_,
            'exit_reason': reason,
            'gross_return': gross_return,
            'net_return': net_return,
            'hold_bars': exit_idx - entry_idx,
            'ml_score': score,
            'type': signal.get('type'),
            'level': signal.get('level'),
        })

    wins = [t for t in trades if t['net_return'] > 0]
    losses = [t for t in trades if t['net_return'] <= 0]
    total_return = equity - 1.0
    avg_win = sum(t['net_return'] for t in wins) / len(wins) if wins else 0.0
    avg_loss = sum(t['net_return'] for t in losses) / len(losses) if losses else 0.0
    return {
        'ok': True,
        'trades': trades,
        'summary': {
            'trade_count': len(trades),
            'win_count': len(wins),
            'loss_count': len(losses),
            'win_rate': len(wins) / len(trades) if trades else None,
            'avg_win': avg_win,
            'avg_loss': avg_loss,
            'payoff_ratio': None if avg_loss == 0 else abs(avg_win / avg_loss),
            'total_return': total_return,
            'final_equity': equity,
        },
        'meta': {
            'source': 'origin_vespa_tdx.backend.a_backtest_engine',
            'execution': 'next_bar_open_or_close_fallback',
            'same_bar_lookahead': False,
            'chan_py_polluted': False,
            'options': {
                'fee_bps': fee * 10000.0,
                'slippage_bps': slippage * 10000.0,
                'max_hold_bars': max_hold_bars,
                'min_score': min_score_value,
                'allow_unsure': allow_unsure,
                'stop_loss_pct': stop_loss_value,
                'take_profit_pct': take_profit_value,
            },
        },
    }
