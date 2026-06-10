from __future__ import annotations

from typing import Any


def _to_float(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace(',', '')
    if not text or text in {'-', '--'} or text.lower() in {'none', 'null', 'nan'}:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _time(row: dict[str, Any]) -> str | None:
    value = row.get('time') or row.get('dt') or row.get('datetime') or row.get('date')
    return None if value is None else str(value)


def _raw_index(row: dict[str, Any], fallback: int) -> int:
    value = row.get('raw_index', row.get('rawIndex', row.get('id', fallback)))
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def _point(row: dict[str, Any], fallback: int, value: Any) -> dict[str, Any]:
    return {'time': _time(row), 'raw_index': _raw_index(row, fallback), 'value': _to_float(value)}


def _multi_point(row: dict[str, Any], fallback: int, values: dict[str, float | None]) -> dict[str, Any]:
    return {'time': _time(row), 'raw_index': _raw_index(row, fallback), 'values': values}


def _window(values: list[float | None], end: int, n: int) -> list[float] | None:
    if end + 1 < n:
        return None
    rows = values[end + 1 - n:end + 1]
    return None if any(v is None for v in rows) else [float(v) for v in rows]


def _rolling_mean(values: list[float | None], n: int) -> list[float | None]:
    out: list[float | None] = []
    for i in range(len(values)):
        rows = _window(values, i, n)
        out.append(None if rows is None else sum(rows) / n)
    return out


def _rolling_sum(values: list[float | None], n: int) -> list[float | None]:
    out: list[float | None] = []
    for i in range(len(values)):
        rows = _window(values, i, n)
        out.append(None if rows is None else sum(rows))
    return out


def _rolling_high(values: list[float | None], n: int) -> list[float | None]:
    return [None if (rows := _window(values, i, n)) is None else max(rows) for i in range(len(values))]


def _rolling_low(values: list[float | None], n: int) -> list[float | None]:
    return [None if (rows := _window(values, i, n)) is None else min(rows) for i in range(len(values))]


def _rolling_avedev(values: list[float | None], n: int) -> list[float | None]:
    out: list[float | None] = []
    for i in range(len(values)):
        rows = _window(values, i, n)
        if rows is None:
            out.append(None)
            continue
        mean = sum(rows) / n
        out.append(sum(abs(x - mean) for x in rows) / n)
    return out


def _rolling_std(values: list[float | None], n: int) -> list[float | None]:
    out: list[float | None] = []
    for i in range(len(values)):
        rows = _window(values, i, n)
        if rows is None:
            out.append(None)
            continue
        mean = sum(rows) / n
        out.append((sum((x - mean) ** 2 for x in rows) / n) ** 0.5)
    return out


def _ema_series(values: list[float | None], period: int) -> list[float | None]:
    out: list[float | None] = []
    prev: float | None = None
    alpha = 2.0 / (period + 1.0)
    for value in values:
        if value is None:
            out.append(None)
            continue
        prev = value if prev is None else alpha * value + (1.0 - alpha) * prev
        out.append(prev)
    return out


def _sma_series(values: list[float | None], n: int, m: int = 1) -> list[float | None]:
    out: list[float | None] = []
    prev: float | None = None
    alpha = m / n
    for value in values:
        if value is None:
            out.append(None)
            continue
        prev = value if prev is None else alpha * value + (1.0 - alpha) * prev
        out.append(prev)
    return out


def _div(a: float | None, b: float | None, default: float | None = None) -> float | None:
    if a is None or b is None:
        return None
    return default if abs(b) < 1e-12 else a / b


def _rd(value: float | None, digits: int = 3) -> float | None:
    return None if value is None else round(value, digits)


def _macd(close: list[float | None], fast: int, slow: int, signal: int) -> list[tuple[float | None, float | None, float | None]]:
    ema_fast = _ema_series(close, fast)
    ema_slow = _ema_series(close, slow)
    dif = [None if a is None or b is None else a - b for a, b in zip(ema_fast, ema_slow)]
    dea = _ema_series(dif, signal)
    return [(_rd(d), _rd(e), _rd(None if d is None or e is None else d - e)) for d, e in zip(dif, dea)]


def _boll(close: list[float | None], n: int, p: float = 2.0) -> list[tuple[float | None, float | None, float | None]]:
    ma = _rolling_mean(close, n)
    std = _rolling_std(close, n)
    return [(_rd(None if m is None or s is None else m + p * s), _rd(m), _rd(None if m is None or s is None else m - p * s)) for m, s in zip(ma, std)]


def _kdj(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 9, m1: int = 3, m2: int = 3) -> list[dict[str, float | None]]:
    hh = _rolling_high(high, n)
    ll = _rolling_low(low, n)
    rsv = []
    for c, h, l in zip(close, hh, ll):
        if c is None or h is None or l is None:
            rsv.append(None)
        elif abs(h - l) < 1e-12:
            rsv.append(50.0)
        else:
            rsv.append((c - l) / (h - l) * 100.0)
    k = _ema_series(rsv, m1 * 2 - 1)
    d = _ema_series(k, m2 * 2 - 1)
    return [{'KDJ_K': _rd(a), 'KDJ_D': _rd(b), 'KDJ_J': _rd(None if a is None or b is None else 3 * a - 2 * b)} for a, b in zip(k, d)]


def _rsi(close: list[float | None], n: int = 24) -> list[dict[str, float | None]]:
    dif = [None]
    for i in range(1, len(close)):
        dif.append(None if close[i] is None or close[i - 1] is None else close[i] - close[i - 1])
    pos = [None if d is None else max(d, 0.0) for d in dif]
    abs_d = [None if d is None else abs(d) for d in dif]
    pos_sma = _sma_series(pos, n)
    abs_sma = _sma_series(abs_d, n)
    return [{'RSI': _rd(50.0 if a is not None and abs(a) < 1e-12 else (None if p is None or a is None else p / a * 100.0))} for p, a in zip(pos_sma, abs_sma)]


def _tr(close: list[float | None], high: list[float | None], low: list[float | None]) -> list[float | None]:
    out: list[float | None] = []
    for i, (c, h, l) in enumerate(zip(close, high, low)):
        if h is None or l is None:
            out.append(None)
            continue
        prev_close = close[i - 1] if i > 0 else c
        if prev_close is None:
            out.append(None)
            continue
        out.append(max(h - l, abs(h - prev_close), abs(l - prev_close)))
    return out


def _atr(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 20) -> list[dict[str, float | None]]:
    return [{'ATR': _rd(v)} for v in _rolling_mean(_tr(close, high, low), n)]


def _dmi(close: list[float | None], high: list[float | None], low: list[float | None], m1: int = 14, m2: int = 6) -> list[dict[str, float | None]]:
    tr_sum = _rolling_sum(_tr(close, high, low), m1)
    dmp: list[float | None] = [None]
    dmm: list[float | None] = [None]
    for i in range(1, len(close)):
        if high[i] is None or high[i - 1] is None or low[i] is None or low[i - 1] is None:
            dmp.append(None); dmm.append(None); continue
        hd = high[i] - high[i - 1]
        ld = low[i - 1] - low[i]
        dmp.append(hd if hd > 0 and hd > ld else 0.0)
        dmm.append(ld if ld > 0 and ld > hd else 0.0)
    dmp_sum = _rolling_sum(dmp, m1)
    dmm_sum = _rolling_sum(dmm, m1)
    pdi = [None if a is None or t is None or abs(t) < 1e-12 else a * 100.0 / t for a, t in zip(dmp_sum, tr_sum)]
    mdi = [None if a is None or t is None or abs(t) < 1e-12 else a * 100.0 / t for a, t in zip(dmm_sum, tr_sum)]
    dx = [None if p is None or m is None or abs(p + m) < 1e-12 else abs(m - p) / (p + m) * 100.0 for p, m in zip(pdi, mdi)]
    adx = _rolling_mean(dx, m2)
    adxr = [None if i < m2 or adx[i] is None or adx[i - m2] is None else (adx[i] + adx[i - m2]) / 2.0 for i in range(len(adx))]
    return [{'DMI_PDI': _rd(p), 'DMI_MDI': _rd(m), 'DMI_ADX': _rd(a), 'DMI_ADXR': _rd(r)} for p, m, a, r in zip(pdi, mdi, adx, adxr)]


def _wr(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 10, n1: int = 6) -> list[dict[str, float | None]]:
    def calc(period: int) -> list[float | None]:
        hh = _rolling_high(high, period)
        ll = _rolling_low(low, period)
        out: list[float | None] = []
        for c, h, l in zip(close, hh, ll):
            if c is None or h is None or l is None:
                out.append(None)
            elif abs(h - l) < 1e-12:
                out.append(50.0)
            else:
                out.append((h - c) / (h - l) * 100.0)
        return out
    wr1, wr2 = calc(n), calc(n1)
    return [{'WR1': _rd(a), 'WR2': _rd(b)} for a, b in zip(wr1, wr2)]


def _cci(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 14) -> list[dict[str, float | None]]:
    tp = [None if c is None or h is None or l is None else (h + l + c) / 3.0 for c, h, l in zip(close, high, low)]
    ma = _rolling_mean(tp, n)
    avedev = _rolling_avedev(tp, n)
    return [{'CCI': _rd(None if t is None or m is None or a is None or abs(a) < 1e-12 else (t - m) / (0.015 * a))} for t, m, a in zip(tp, ma, avedev)]


def _bias(close: list[float | None], l1: int = 6, l2: int = 12, l3: int = 24) -> list[dict[str, float | None]]:
    mas = [_rolling_mean(close, n) for n in (l1, l2, l3)]
    rows = []
    for i, c in enumerate(close):
        rows.append({f'BIAS{j + 1}': _rd(None if c is None or mas[j][i] is None or abs(mas[j][i] or 0) < 1e-12 else (c - (mas[j][i] or 0)) / (mas[j][i] or 1) * 100.0) for j in range(3)})
    return rows


def _obv(close: list[float | None], vol: list[float | None]) -> list[dict[str, float | None]]:
    total = 0.0
    out: list[dict[str, float | None]] = []
    for i, c in enumerate(close):
        if i > 0 and c is not None and close[i - 1] is not None and vol[i] is not None:
            if c > close[i - 1]:
                total += vol[i] or 0.0
            elif c < close[i - 1]:
                total -= vol[i] or 0.0
        out.append({'OBV': _rd(total / 10000.0)})
    return out


def _multi_rows(bars: list[dict[str, Any]], values: list[dict[str, float | None]]) -> list[dict[str, Any]]:
    return [_multi_point(row, i, values[i]) for i, row in enumerate(bars)]


def build_easy_tdx_indicators(
    bars: list[dict[str, Any]], *, ma_windows: tuple[int, ...] = (5, 10, 20, 60), boll_window: int = 20,
    macd_fast: int = 12, macd_slow: int = 26, macd_signal: int = 9,
) -> dict[str, Any]:
    close = [_to_float(row.get('close') or row.get('c')) for row in bars]
    high = [_to_float(row.get('high') or row.get('h')) for row in bars]
    low = [_to_float(row.get('low') or row.get('l')) for row in bars]
    vol = [_to_float(row.get('volume', row.get('vol', row.get('v')))) for row in bars]
    result: dict[str, Any] = {
        'vol': [_point(row, i, row.get('volume', row.get('vol', row.get('v')))) for i, row in enumerate(bars)],
        'amount': [_point(row, i, row.get('amount', row.get('money'))) for i, row in enumerate(bars)],
        'turnover': [_point(row, i, row.get('turnover', row.get('turnover_rate'))) for i, row in enumerate(bars)],
        'ma': {},
    }
    result['ma'] = {str(w): [{'time': _time(row), 'raw_index': _raw_index(row, i), 'value': v} for i, (row, v) in enumerate(zip(bars, _rolling_mean(close, w)))] for w in ma_windows}
    result['boll'] = [{'time': _time(row), 'raw_index': _raw_index(row, i), 'upper': u, 'mid': m, 'lower': l} for i, (row, (u, m, l)) in enumerate(zip(bars, _boll(close, boll_window)))]
    result['macd'] = [{'time': _time(row), 'raw_index': _raw_index(row, i), 'dif': d, 'dea': e, 'hist': h} for i, (row, (d, e, h)) in enumerate(zip(bars, _macd(close, macd_fast, macd_slow, macd_signal)))]
    result['kdj'] = _multi_rows(bars, _kdj(close, high, low))
    result['rsi'] = _multi_rows(bars, _rsi(close))
    result['dmi'] = _multi_rows(bars, _dmi(close, high, low))
    result['atr'] = _multi_rows(bars, _atr(close, high, low))
    result['wr'] = _multi_rows(bars, _wr(close, high, low))
    result['cci'] = _multi_rows(bars, _cci(close, high, low))
    result['bias'] = _multi_rows(bars, _bias(close))
    result['obv'] = _multi_rows(bars, _obv(close, vol))
    return result


def easy_tdx_indicator_meta() -> dict[str, Any]:
    registry = {
        'kdj': {'name': 'KDJ', 'inputs': ['close', 'high', 'low'], 'outputs': ['KDJ_K', 'KDJ_D', 'KDJ_J'], 'default_params': {'N': 9, 'M1': 3, 'M2': 3}},
        'rsi': {'name': 'RSI', 'inputs': ['close'], 'outputs': ['RSI'], 'default_params': {'N': 24}},
        'dmi': {'name': 'DMI', 'inputs': ['close', 'high', 'low'], 'outputs': ['DMI_PDI', 'DMI_MDI', 'DMI_ADX', 'DMI_ADXR'], 'default_params': {'M1': 14, 'M2': 6}},
        'atr': {'name': 'ATR', 'inputs': ['close', 'high', 'low'], 'outputs': ['ATR'], 'default_params': {'N': 20}},
        'wr': {'name': 'WR', 'inputs': ['close', 'high', 'low'], 'outputs': ['WR1', 'WR2'], 'default_params': {'N': 10, 'N1': 6}},
        'cci': {'name': 'CCI', 'inputs': ['close', 'high', 'low'], 'outputs': ['CCI'], 'default_params': {'N': 14}},
        'bias': {'name': 'BIAS', 'inputs': ['close'], 'outputs': ['BIAS1', 'BIAS2', 'BIAS3'], 'default_params': {'L1': 6, 'L2': 12, 'L3': 24}},
        'obv': {'name': 'OBV', 'inputs': ['close', 'vol'], 'outputs': ['OBV'], 'default_params': {}},
    }
    sources: dict[str, Any] = {
        'vol': {'source': 'easy-tdx kline volume', 'calculation': 'raw_field'},
        'amount': {'source': 'easy-tdx kline amount', 'calculation': 'raw_field_or_null'},
        'turnover': {'source': 'easy-tdx kline turnover', 'calculation': 'raw_field_or_null'},
        'ma': {'source': 'easy-tdx OHLCV close', 'calculation': 'app_display_ma'},
        'boll': {'source': 'easy_tdx.indicator BOLL', 'calculation': 'app_display_formula_from_easy_tdx_ohlcv'},
        'macd': {'source': 'easy_tdx.indicator MACD', 'calculation': 'app_display_formula_from_easy_tdx_ohlcv'},
    }
    for key, spec in registry.items():
        sources[key] = {'source': f"easy_tdx.indicator {spec['name']}", 'calculation': 'app_display_formula_from_easy_tdx_ohlcv', **spec}
    return {'indicator_sources': sources, 'indicator_warning': '指标仅用于展示和 tooltip，不参与 chan.py 缠论结构计算。'}
