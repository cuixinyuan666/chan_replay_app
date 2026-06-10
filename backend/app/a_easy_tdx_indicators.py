from __future__ import annotations

from typing import Any, Callable


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


def _rd(value: float | None, digits: int = 3) -> float | None:
    return None if value is None else round(value, digits)


def _ref(values: list[float | None], n: int = 1) -> list[float | None]:
    return [None if i < n else values[i - n] for i in range(len(values))]


def _window(values: list[float | None], end: int, n: int) -> list[float] | None:
    if n <= 0 or end + 1 < n:
        return None
    rows = values[end + 1 - n:end + 1]
    return None if any(v is None for v in rows) else [float(v) for v in rows]


def _rolling_apply(values: list[float | None], n: int, fn: Callable[[list[float]], float]) -> list[float | None]:
    return [None if (rows := _window(values, i, n)) is None else fn(rows) for i in range(len(values))]


def _rolling_mean(values: list[float | None], n: int) -> list[float | None]:
    return _rolling_apply(values, n, lambda rows: sum(rows) / n)


def _rolling_sum(values: list[float | None], n: int) -> list[float | None]:
    if n <= 0:
        total = 0.0
        out: list[float | None] = []
        valid = True
        for value in values:
            if value is None:
                valid = False
                out.append(None)
            else:
                total += value
                out.append(total if valid else None)
        return out
    return _rolling_apply(values, n, sum)


def _rolling_high(values: list[float | None], n: int) -> list[float | None]:
    return _rolling_apply(values, n, max)


def _rolling_low(values: list[float | None], n: int) -> list[float | None]:
    return _rolling_apply(values, n, min)


def _rolling_std(values: list[float | None], n: int) -> list[float | None]:
    def calc(rows: list[float]) -> float:
        mean = sum(rows) / n
        return (sum((x - mean) ** 2 for x in rows) / n) ** 0.5
    return _rolling_apply(values, n, calc)


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
    for value in values:
        if value is None:
            out.append(None)
            continue
        prev = value if prev is None else (m * value + (n - m) * prev) / n
        out.append(prev)
    return out


def _macd(close: list[float | None], fast: int = 12, slow: int = 26, signal: int = 9) -> list[dict[str, float | None]]:
    ema_fast = _ema_series(close, fast)
    ema_slow = _ema_series(close, slow)
    dif = [None if a is None or b is None else a - b for a, b in zip(ema_fast, ema_slow)]
    dea = _ema_series(dif, signal)
    return [{'MACD_DIF': _rd(d), 'MACD_DEA': _rd(e), 'MACD_HIST': _rd(None if d is None or e is None else (d - e) * 2.0)} for d, e in zip(dif, dea)]


def _boll(close: list[float | None], n: int = 20, p: float = 2.0) -> list[tuple[float | None, float | None, float | None]]:
    mid = _rolling_mean(close, n)
    std = _rolling_std(close, n)
    return [(None if m is None or s is None else _rd(m + p * s), _rd(m), None if m is None or s is None else _rd(m - p * s)) for m, s in zip(mid, std)]


def _kdj(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 9) -> list[dict[str, float | None]]:
    rsv: list[float | None] = []
    for i, c in enumerate(close):
        hh = _rolling_high(high, n)[i]
        ll = _rolling_low(low, n)[i]
        rsv.append(None if c is None or hh is None or ll is None or abs(hh - ll) < 1e-12 else (c - ll) / (hh - ll) * 100.0)
    k = _sma_series(rsv, 3, 1)
    d = _sma_series(k, 3, 1)
    return [{'KDJ_K': _rd(a), 'KDJ_D': _rd(b), 'KDJ_J': _rd(None if a is None or b is None else 3 * a - 2 * b)} for a, b in zip(k, d)]


def _rsi(close: list[float | None], n: int = 24) -> list[dict[str, float | None]]:
    prev = _ref(close)
    up = [None if c is None or p is None else max(c - p, 0.0) for c, p in zip(close, prev)]
    abs_chg = [None if c is None or p is None else abs(c - p) for c, p in zip(close, prev)]
    au = _sma_series(up, n, 1)
    ad = _sma_series(abs_chg, n, 1)
    return [{'RSI': _rd(None if a is None or b is None or abs(b) < 1e-12 else a / b * 100.0)} for a, b in zip(au, ad)]


def _true_range(close: list[float | None], high: list[float | None], low: list[float | None]) -> list[float | None]:
    prev = _ref(close)
    out = []
    for h, l, p in zip(high, low, prev):
        if h is None or l is None:
            out.append(None)
        elif p is None:
            out.append(h - l)
        else:
            out.append(max(h - l, abs(h - p), abs(l - p)))
    return out


def _atr(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 20) -> list[dict[str, float | None]]:
    return [{'ATR': _rd(v)} for v in _rolling_mean(_true_range(close, high, low), n)]


def _dmi(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 14, m: int = 6) -> list[dict[str, float | None]]:
    ph, pl = _ref(high), _ref(low)
    hdiff = [None if h is None or p is None else h - p for h, p in zip(high, ph)]
    ldiff = [None if l is None or p is None else p - l for l, p in zip(low, pl)]
    trn = _rolling_sum(_true_range(close, high, low), n)
    dmp = _rolling_sum([None if a is None or b is None else (a if a > 0 and a > b else 0.0) for a, b in zip(hdiff, ldiff)], n)
    dmm = _rolling_sum([None if a is None or b is None else (b if b > 0 and b > a else 0.0) for a, b in zip(hdiff, ldiff)], n)
    pdi = [None if a is None or t is None or abs(t) < 1e-12 else a / t * 100.0 for a, t in zip(dmp, trn)]
    mdi = [None if a is None or t is None or abs(t) < 1e-12 else a / t * 100.0 for a, t in zip(dmm, trn)]
    dx = [None if p is None or q is None or abs(p + q) < 1e-12 else abs(p - q) / (p + q) * 100.0 for p, q in zip(pdi, mdi)]
    adx = _rolling_mean(dx, m)
    adxr = [(None if a is None or r is None else (a + r) / 2.0) for a, r in zip(adx, _ref(adx, m))]
    return [{'DMI_PDI': _rd(a), 'DMI_MDI': _rd(b), 'DMI_ADX': _rd(c), 'DMI_ADXR': _rd(d)} for a, b, c, d in zip(pdi, mdi, adx, adxr)]


def _wr(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 10, n1: int = 6) -> list[dict[str, float | None]]:
    def one(period: int) -> list[float | None]:
        hh = _rolling_high(high, period)
        ll = _rolling_low(low, period)
        return [None if c is None or h is None or l is None or abs(h - l) < 1e-12 else (h - c) / (h - l) * 100.0 for c, h, l in zip(close, hh, ll)]
    return [{'WR1': _rd(a), 'WR2': _rd(b)} for a, b in zip(one(n), one(n1))]


def _cci(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 14) -> list[dict[str, float | None]]:
    typ = [None if c is None or h is None or l is None else (c + h + l) / 3.0 for c, h, l in zip(close, high, low)]
    ma = _rolling_mean(typ, n)
    out = []
    for i, (t, m) in enumerate(zip(typ, ma)):
        rows = _window(typ, i, n)
        dev = None if rows is None or m is None else sum(abs(x - m) for x in rows) / n
        out.append({'CCI': _rd(None if t is None or m is None or dev is None or abs(dev) < 1e-12 else (t - m) / (0.015 * dev))})
    return out


def _bias(close: list[float | None]) -> list[dict[str, float | None]]:
    def one(n: int) -> list[float | None]:
        ma = _rolling_mean(close, n)
        return [None if c is None or m is None or abs(m) < 1e-12 else (c - m) / m * 100.0 for c, m in zip(close, ma)]
    return [{'BIAS1': _rd(a), 'BIAS2': _rd(b), 'BIAS3': _rd(c)} for a, b, c in zip(one(6), one(12), one(24))]


def _obv(close: list[float | None], vol: list[float | None]) -> list[dict[str, float | None]]:
    total = 0.0
    out = []
    for i, (c, v) in enumerate(zip(close, vol)):
        if c is None or v is None:
            out.append({'OBV': None})
            continue
        if i == 0 or close[i - 1] is None:
            total += v
        elif c > close[i - 1]:
            total += v
        elif c < close[i - 1]:
            total -= v
        out.append({'OBV': _rd(total)})
    return out


def _psy(close: list[float | None], n: int = 12, m: int = 6) -> list[dict[str, float | None]]:
    up = [None if i == 0 or close[i] is None or close[i - 1] is None else (1.0 if close[i] > close[i - 1] else 0.0) for i in range(len(close))]
    psy = [None if v is None else v / n * 100.0 for v in _rolling_sum(up, n)]
    return [{'PSY': _rd(a), 'PSY_MA': _rd(b)} for a, b in zip(psy, _rolling_mean(psy, m))]


def _trix(close: list[float | None], m1: int = 12, m2: int = 20) -> list[dict[str, float | None]]:
    e3 = _ema_series(_ema_series(_ema_series(close, m1), m1), m1)
    trix = [None if a is None or b is None or abs(b) < 1e-12 else (a / b - 1.0) * 100.0 for a, b in zip(e3, _ref(e3))]
    return [{'TRIX': _rd(a), 'TRIX_MA': _rd(b)} for a, b in zip(trix, _rolling_mean(trix, m2))]


def _dpo(close: list[float | None], m1: int = 20, m2: int = 10, m3: int = 6) -> list[dict[str, float | None]]:
    ma = _rolling_mean(close, m1)
    ref_ma = _ref(ma, m2)
    dpo = [None if c is None or r is None else c - r for c, r in zip(close, ref_ma)]
    return [{'DPO': _rd(a), 'DPO_MA': _rd(b)} for a, b in zip(dpo, _rolling_mean(dpo, m3))]


def _mtm(close: list[float | None], n: int = 12, m: int = 6) -> list[dict[str, float | None]]:
    mtm = [None if c is None or r is None else c - r for c, r in zip(close, _ref(close, n))]
    return [{'MTM': _rd(a), 'MTM_MA': _rd(b)} for a, b in zip(mtm, _rolling_mean(mtm, m))]


def _roc(close: list[float | None], n: int = 12, m: int = 6) -> list[dict[str, float | None]]:
    roc = [None if c is None or r is None or abs(r) < 1e-12 else (c / r - 1.0) * 100.0 for c, r in zip(close, _ref(close, n))]
    return [{'ROC': _rd(a), 'ROC_MA': _rd(b)} for a, b in zip(roc, _rolling_mean(roc, m))]


def _expma(close: list[float | None]) -> list[dict[str, float | None]]:
    return [{'EXPMA_12': _rd(a), 'EXPMA_50': _rd(b)} for a, b in zip(_ema_series(close, 12), _ema_series(close, 50))]


def _bbi(close: list[float | None]) -> list[dict[str, float | None]]:
    m3, m6, m12, m20 = _rolling_mean(close, 3), _rolling_mean(close, 6), _rolling_mean(close, 12), _rolling_mean(close, 20)
    return [{'BBI': _rd(None if None in (a, b, c, d) else (a + b + c + d) / 4.0)} for a, b, c, d in zip(m3, m6, m12, m20)]


def _dfma(close: list[float | None]) -> list[dict[str, float | None]]:
    dif = [None if a is None or b is None else a - b for a, b in zip(_rolling_mean(close, 10), _rolling_mean(close, 50))]
    return [{'DFMA_DIF': _rd(a), 'DFMA_DMA': _rd(b)} for a, b in zip(dif, _rolling_mean(dif, 10))]


def _cr(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 20) -> list[dict[str, float | None]]:
    mid = [(h + l) / 2.0 if h is not None and l is not None else None for h, l in zip(high, low)]
    pmid = _ref(mid)
    up = [None if h is None or m is None else max(0.0, h - m) for h, m in zip(high, pmid)]
    dn = [None if l is None or m is None else max(0.0, m - l) for l, m in zip(low, pmid)]
    su, sd = _rolling_sum(up, n), _rolling_sum(dn, n)
    return [{'CR': _rd(None if a is None or b is None or abs(b) < 1e-12 else a / b * 100.0)} for a, b in zip(su, sd)]


def _ktn(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 20, m: int = 10) -> list[dict[str, float | None]]:
    mid = _ema_series(close, m)
    atr = [row['ATR'] for row in _atr(close, high, low, n)]
    return [{'KTN_UPPER': _rd(None if a is None or b is None else a + 2 * b), 'KTN_MID': _rd(a), 'KTN_LOWER': _rd(None if a is None or b is None else a - 2 * b)} for a, b in zip(mid, atr)]


def _xsii(close: list[float | None], high: list[float | None], low: list[float | None]) -> list[dict[str, float | None]]:
    ma7 = _rolling_mean(close, 7)
    ma102 = _rolling_mean(close, 102)
    return [{'XSII_TD1': _rd(a), 'XSII_TD2': _rd(b), 'XSII_TD3': _rd(None if a is None or b is None else a - b), 'XSII_TD4': _rd(c)} for a, b, c in zip(ma7, ma102, _rolling_mean(low, 7))]


def _vr(close: list[float | None], vol: list[float | None], n: int = 26) -> list[dict[str, float | None]]:
    prev = _ref(close)
    av = [None if c is None or p is None or v is None else (v if c > p else 0.0) for c, p, v in zip(close, prev, vol)]
    bv = [None if c is None or p is None or v is None else (v if c < p else 0.0) for c, p, v in zip(close, prev, vol)]
    cv = [None if c is None or p is None or v is None else (v if c == p else 0.0) for c, p, v in zip(close, prev, vol)]
    sa, sb, sc = _rolling_sum(av, n), _rolling_sum(bv, n), _rolling_sum(cv, n)
    return [{'VR': _rd(None if a is None or b is None or c is None or abs(b + c / 2.0) < 1e-12 else (a + c / 2.0) / (b + c / 2.0) * 100.0)} for a, b, c in zip(sa, sb, sc)]


def _emv(high: list[float | None], low: list[float | None], vol: list[float | None], n: int = 14, m: int = 9) -> list[dict[str, float | None]]:
    hlm = [None if h is None or l is None else (h + l) / 2.0 for h, l in zip(high, low)]
    em = [None if a is None or b is None or h is None or l is None or v is None or abs(v) < 1e-12 else (a - b) * (h - l) / v for a, b, h, l, v in zip(hlm, _ref(hlm), high, low, vol)]
    emv = _rolling_mean(em, n)
    return [{'EMV': _rd(a), 'EMV_MA': _rd(b)} for a, b in zip(emv, _rolling_mean(emv, m))]


def _mass(high: list[float | None], low: list[float | None]) -> list[dict[str, float | None]]:
    rng = [None if h is None or l is None else h - l for h, l in zip(high, low)]
    ema1 = _ema_series(rng, 9)
    ema2 = _ema_series(ema1, 9)
    ratio = [None if a is None or b is None or abs(b) < 1e-12 else a / b for a, b in zip(ema1, ema2)]
    mass = _rolling_sum(ratio, 25)
    return [{'MASS': _rd(a), 'MASS_MA': _rd(b)} for a, b in zip(mass, _rolling_mean(mass, 6))]


def _mfi(close: list[float | None], high: list[float | None], low: list[float | None], vol: list[float | None], n: int = 14) -> list[dict[str, float | None]]:
    typ = [None if c is None or h is None or l is None else (c + h + l) / 3.0 for c, h, l in zip(close, high, low)]
    money = [None if t is None or v is None else t * v for t, v in zip(typ, vol)]
    pos = [None if t is None or p is None or m is None else (m if t > p else 0.0) for t, p, m in zip(typ, _ref(typ), money)]
    neg = [None if t is None or p is None or m is None else (m if t < p else 0.0) for t, p, m in zip(typ, _ref(typ), money)]
    sp, sn = _rolling_sum(pos, n), _rolling_sum(neg, n)
    return [{'MFI': _rd(None if p is None or q is None or abs(q) < 1e-12 else 100.0 - 100.0 / (1.0 + p / q))} for p, q in zip(sp, sn)]


def _brar(open_: list[float | None], close: list[float | None], high: list[float | None], low: list[float | None], n: int = 26) -> list[dict[str, float | None]]:
    ho = [None if h is None or o is None else h - o for h, o in zip(high, open_)]
    ol = [None if o is None or l is None else o - l for o, l in zip(open_, low)]
    hc = [None if h is None or c is None else max(0.0, h - c) for h, c in zip(high, _ref(close))]
    cl = [None if c is None or l is None else max(0.0, c - l) for c, l in zip(_ref(close), low)]
    ar_u, ar_d = _rolling_sum(ho, n), _rolling_sum(ol, n)
    br_u, br_d = _rolling_sum(hc, n), _rolling_sum(cl, n)
    return [{'AR': _rd(None if a is None or b is None or abs(b) < 1e-12 else a / b * 100.0), 'BR': _rd(None if c is None or d is None or abs(d) < 1e-12 else c / d * 100.0)} for a, b, c, d in zip(ar_u, ar_d, br_u, br_d)]


def _asi(open_: list[float | None], close: list[float | None], high: list[float | None], low: list[float | None], n: int = 26, m: int = 10) -> list[dict[str, float | None]]:
    si: list[float | None] = []
    for i in range(len(close)):
        if i == 0 or None in (open_[i], close[i], high[i], low[i], close[i - 1], open_[i - 1]):
            si.append(None)
            continue
        a = abs(high[i] - close[i - 1])
        b = abs(low[i] - close[i - 1])
        c = abs(high[i] - low[i])
        r = max(a, b, c)
        si.append(None if abs(r) < 1e-12 else 16.0 * (close[i] - close[i - 1] + (close[i] - open_[i]) / 2.0 + (close[i - 1] - open_[i - 1]) / 4.0) / r)
    asi = _rolling_sum(si, 0)
    return [{'ASI': _rd(a), 'ASI_MA': _rd(b)} for a, b in zip(asi, _rolling_mean(asi, m))]


def _taq(high: list[float | None], low: list[float | None], n: int = 20) -> list[dict[str, float | None]]:
    up = _rolling_high(high, n)
    down = _rolling_low(low, n)
    return [{'TAQ_UP': _rd(u), 'TAQ_MID': _rd(None if u is None or d is None else (u + d) / 2.0), 'TAQ_DOWN': _rd(d)} for u, d in zip(up, down)]


def _zhuoyao(close: list[float | None]) -> list[dict[str, float | None]]:
    def pct(n: int) -> list[float | None]:
        return [None if c is None or r is None or abs(r) < 1e-12 else (c / r - 1.0) * 100.0 for c, r in zip(close, _ref(close, n))]
    long = _ema_series(pct(120), 10)
    mid = pct(60)
    short = pct(20)
    trend = _ema_series(mid, 10)
    return [{'ZY_LONG': _rd(a), 'ZY_MID': _rd(b), 'ZY_SHORT': _rd(c), 'ZY_TREND': _rd(d)} for a, b, c, d in zip(long, mid, short, trend)]


def _bias_signal(close: list[float | None], p: int = 10, m: int = 30) -> list[dict[str, float | None]]:
    ma = _rolling_mean(close, m)
    x = [None if c is None or v is None or abs(v) < 1e-12 else (c - v) / v * 100.0 for c, v in zip(close, ma)]
    return [{'BS_X': _rd(a), 'BS_SMA': _rd(b), 'BS_LMA': _rd(c)} for a, b, c in zip(x, _rolling_mean(x, p), _rolling_mean(x, m))]


def _multi_rows(bars: list[dict[str, Any]], values: list[dict[str, float | None]]) -> list[dict[str, Any]]:
    return [_multi_point(row, i, values[i]) for i, row in enumerate(bars)]


_INDICATOR_SPECS: dict[str, dict[str, Any]] = {
    'macd': {'name': 'MACD', 'inputs': ['close'], 'outputs': ['MACD_DIF', 'MACD_DEA', 'MACD_HIST'], 'default_params': {'SHORT': 12, 'LONG': 26, 'M': 9}},
    'rsi': {'name': 'RSI', 'inputs': ['close'], 'outputs': ['RSI'], 'default_params': {'N': 24}},
    'boll': {'name': 'BOLL', 'inputs': ['close'], 'outputs': ['BOLL_UPPER', 'BOLL_MID', 'BOLL_LOWER'], 'default_params': {'N': 20, 'P': 2}},
    'bias': {'name': 'BIAS', 'inputs': ['close'], 'outputs': ['BIAS1', 'BIAS2', 'BIAS3'], 'default_params': {'L1': 6, 'L2': 12, 'L3': 24}},
    'psy': {'name': 'PSY', 'inputs': ['close'], 'outputs': ['PSY', 'PSY_MA'], 'default_params': {'N': 12, 'M': 6}},
    'trix': {'name': 'TRIX', 'inputs': ['close'], 'outputs': ['TRIX', 'TRIX_MA'], 'default_params': {'M1': 12, 'M2': 20}},
    'dpo': {'name': 'DPO', 'inputs': ['close'], 'outputs': ['DPO', 'DPO_MA'], 'default_params': {'M1': 20, 'M2': 10, 'M3': 6}},
    'mtm': {'name': 'MTM', 'inputs': ['close'], 'outputs': ['MTM', 'MTM_MA'], 'default_params': {'N': 12, 'M': 6}},
    'roc': {'name': 'ROC', 'inputs': ['close'], 'outputs': ['ROC', 'ROC_MA'], 'default_params': {'N': 12, 'M': 6}},
    'expma': {'name': 'EXPMA', 'inputs': ['close'], 'outputs': ['EXPMA_12', 'EXPMA_50'], 'default_params': {'N1': 12, 'N2': 50}},
    'bbi': {'name': 'BBI', 'inputs': ['close'], 'outputs': ['BBI'], 'default_params': {'M1': 3, 'M2': 6, 'M3': 12, 'M4': 20}},
    'dfma': {'name': 'DFMA', 'inputs': ['close'], 'outputs': ['DFMA_DIF', 'DFMA_DMA'], 'default_params': {'N1': 10, 'N2': 50, 'M': 10}},
    'kdj': {'name': 'KDJ', 'inputs': ['close', 'high', 'low'], 'outputs': ['KDJ_K', 'KDJ_D', 'KDJ_J'], 'default_params': {'N': 9, 'M1': 3, 'M2': 3}},
    'dmi': {'name': 'DMI', 'inputs': ['close', 'high', 'low'], 'outputs': ['DMI_PDI', 'DMI_MDI', 'DMI_ADX', 'DMI_ADXR'], 'default_params': {'M1': 14, 'M2': 6}},
    'atr': {'name': 'ATR', 'inputs': ['close', 'high', 'low'], 'outputs': ['ATR'], 'default_params': {'N': 20}},
    'wr': {'name': 'WR', 'inputs': ['close', 'high', 'low'], 'outputs': ['WR1', 'WR2'], 'default_params': {'N': 10, 'N1': 6}},
    'cci': {'name': 'CCI', 'inputs': ['close', 'high', 'low'], 'outputs': ['CCI'], 'default_params': {'N': 14}},
    'cr': {'name': 'CR', 'inputs': ['close', 'high', 'low'], 'outputs': ['CR'], 'default_params': {'N': 20}},
    'ktn': {'name': 'KTN', 'inputs': ['close', 'high', 'low'], 'outputs': ['KTN_UPPER', 'KTN_MID', 'KTN_LOWER'], 'default_params': {'N': 20, 'M': 10}},
    'xsii': {'name': 'XSII', 'inputs': ['close', 'high', 'low'], 'outputs': ['XSII_TD1', 'XSII_TD2', 'XSII_TD3', 'XSII_TD4'], 'default_params': {'N': 102, 'M': 7}},
    'obv': {'name': 'OBV', 'inputs': ['close', 'vol'], 'outputs': ['OBV'], 'default_params': {}},
    'vr': {'name': 'VR', 'inputs': ['close', 'vol'], 'outputs': ['VR'], 'default_params': {'M1': 26}},
    'emv': {'name': 'EMV', 'inputs': ['high', 'low', 'vol'], 'outputs': ['EMV', 'EMV_MA'], 'default_params': {'N': 14, 'M': 9}},
    'mass': {'name': 'MASS', 'inputs': ['high', 'low'], 'outputs': ['MASS', 'MASS_MA'], 'default_params': {'N1': 9, 'N2': 25, 'M': 6}},
    'mfi': {'name': 'MFI', 'inputs': ['close', 'high', 'low', 'vol'], 'outputs': ['MFI'], 'default_params': {'N': 14}},
    'brar': {'name': 'BRAR', 'inputs': ['open', 'close', 'high', 'low'], 'outputs': ['AR', 'BR'], 'default_params': {'M1': 26}},
    'asi': {'name': 'ASI', 'inputs': ['open', 'close', 'high', 'low'], 'outputs': ['ASI', 'ASI_MA'], 'default_params': {'M1': 26, 'M2': 10}},
    'zhuoyao': {'name': 'ZHUOYAO', 'inputs': ['close'], 'outputs': ['ZY_LONG', 'ZY_MID', 'ZY_SHORT', 'ZY_TREND'], 'default_params': {'N1': 120, 'N2': 60, 'N3': 20, 'M': 10}},
    'bias_signal': {'name': 'BIAS_SIGNAL', 'inputs': ['close'], 'outputs': ['BS_X', 'BS_SMA', 'BS_LMA'], 'default_params': {'P': 10, 'M': 30}},
    'taq': {'name': 'TAQ', 'inputs': ['high', 'low'], 'outputs': ['TAQ_UP', 'TAQ_MID', 'TAQ_DOWN'], 'default_params': {'N': 20}},
}


def build_easy_tdx_indicators(bars: list[dict[str, Any]], *, ma_windows: tuple[int, ...] = (5, 10, 20, 60), boll_window: int = 20, macd_fast: int = 12, macd_slow: int = 26, macd_signal: int = 9) -> dict[str, Any]:
    open_ = [_to_float(row.get('open') or row.get('o')) for row in bars]
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
    result['ma'] = {str(w): [{'time': _time(row), 'raw_index': _raw_index(row, i), 'value': _rd(v)} for i, (row, v) in enumerate(zip(bars, _rolling_mean(close, w)))] for w in ma_windows}
    result['boll'] = [{'time': _time(row), 'raw_index': _raw_index(row, i), 'upper': u, 'mid': m, 'lower': l} for i, (row, (u, m, l)) in enumerate(zip(bars, _boll(close, boll_window)))]
    macd_rows = _macd(close, fast=macd_fast, slow=macd_slow, signal=macd_signal)
    result['macd'] = [{'time': _time(row), 'raw_index': _raw_index(row, i), 'dif': r['MACD_DIF'], 'dea': r['MACD_DEA'], 'hist': r['MACD_HIST']} for i, (row, r) in enumerate(zip(bars, macd_rows))]
    named: dict[str, list[dict[str, float | None]]] = {
        'kdj': _kdj(close, high, low), 'rsi': _rsi(close), 'dmi': _dmi(close, high, low), 'atr': _atr(close, high, low),
        'wr': _wr(close, high, low), 'cci': _cci(close, high, low), 'bias': _bias(close), 'obv': _obv(close, vol),
        'psy': _psy(close), 'trix': _trix(close), 'dpo': _dpo(close), 'mtm': _mtm(close), 'roc': _roc(close),
        'expma': _expma(close), 'bbi': _bbi(close), 'dfma': _dfma(close), 'cr': _cr(close, high, low),
        'ktn': _ktn(close, high, low), 'xsii': _xsii(close, high, low), 'vr': _vr(close, vol), 'emv': _emv(high, low, vol),
        'mass': _mass(high, low), 'mfi': _mfi(close, high, low, vol), 'brar': _brar(open_, close, high, low),
        'asi': _asi(open_, close, high, low), 'zhuoyao': _zhuoyao(close), 'bias_signal': _bias_signal(close), 'taq': _taq(high, low),
    }
    for key, rows in named.items():
        result[key] = _multi_rows(bars, rows)
    return result


def easy_tdx_indicator_meta() -> dict[str, Any]:
    sources: dict[str, Any] = {
        'vol': {'source': 'easy-tdx kline volume', 'calculation': 'raw_field'},
        'amount': {'source': 'easy-tdx kline amount', 'calculation': 'raw_field_or_null'},
        'turnover': {'source': 'easy-tdx kline turnover', 'calculation': 'raw_field_or_null'},
        'ma': {'source': 'easy-tdx OHLCV close', 'calculation': 'app_display_ma'},
    }
    for key, spec in _INDICATOR_SPECS.items():
        sources[key] = {'source': f"easy_tdx.indicator {spec['name']}", 'calculation': 'app_display_formula_from_easy_tdx_ohlcv', **spec}
    return {'indicator_sources': sources, 'indicator_warning': '指标仅用于展示和 tooltip，不参与 chan.py 缠论结构计算。'}
