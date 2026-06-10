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


def _rd(value: float | None, digits: int = 3) -> float | None:
    return None if value is None else round(value, digits)


def _ref(values: list[float | None], n: int = 1) -> list[float | None]:
    return [None if i < n else values[i - n] for i in range(len(values))]


def _window(values: list[float | None], end: int, n: int) -> list[float] | None:
    if end + 1 < n:
        return None
    rows = values[end + 1 - n:end + 1]
    return None if any(v is None for v in rows) else [float(v) for v in rows]


def _rolling_apply(values: list[float | None], n: int, fn: Any) -> list[float | None]:
    out: list[float | None] = []
    for i in range(len(values)):
        rows = _window(values, i, n)
        out.append(None if rows is None else fn(rows))
    return out


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


def _rolling_avedev(values: list[float | None], n: int) -> list[float | None]:
    def calc(rows: list[float]) -> float:
        mean = sum(rows) / n
        return sum(abs(x - mean) for x in rows) / n
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
    alpha = m / n
    for value in values:
        if value is None:
            out.append(None)
            continue
        prev = value if prev is None else alpha * value + (1.0 - alpha) * prev
        out.append(prev)
    return out


def _dma_series(values: list[float | None], alpha_values: list[float | None]) -> list[float | None]:
    out: list[float | None] = []
    prev: float | None = None
    for value, alpha in zip(values, alpha_values):
        if value is None:
            out.append(None)
            continue
        a = 1.0 if alpha is None else min(1.0, max(0.0, alpha))
        prev = value if prev is None else a * value + (1.0 - a) * prev
        out.append(prev)
    return out


def _tr(close: list[float | None], high: list[float | None], low: list[float | None]) -> list[float | None]:
    out: list[float | None] = []
    for i, (c, h, l) in enumerate(zip(close, high, low)):
        if h is None or l is None:
            out.append(None)
            continue
        prev_close = close[i - 1] if i > 0 else c
        out.append(None if prev_close is None else max(h - l, abs(h - prev_close), abs(l - prev_close)))
    return out


def _macd(close: list[float | None], fast: int = 12, slow: int = 26, signal: int = 9) -> list[dict[str, float | None]]:
    ema_fast = _ema_series(close, fast)
    ema_slow = _ema_series(close, slow)
    dif = [None if a is None or b is None else a - b for a, b in zip(ema_fast, ema_slow)]
    dea = _ema_series(dif, signal)
    return [{'MACD_DIF': _rd(d), 'MACD_DEA': _rd(e), 'MACD_HIST': _rd(None if d is None or e is None else d - e)} for d, e in zip(dif, dea)]


def _boll(close: list[float | None], n: int = 20, p: float = 2.0) -> list[tuple[float | None, float | None, float | None]]:
    ma = _rolling_mean(close, n)
    std = _rolling_std(close, n)
    return [(_rd(None if m is None or s is None else m + p * s), _rd(m), _rd(None if m is None or s is None else m - p * s)) for m, s in zip(ma, std)]


def _kdj(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 9, m1: int = 3, m2: int = 3) -> list[dict[str, float | None]]:
    hh = _rolling_high(high, n)
    ll = _rolling_low(low, n)
    rsv: list[float | None] = []
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


def _bias(close: list[float | None], l1: int = 6, l2: int = 12, l3: int = 24) -> list[dict[str, float | None]]:
    mas = [_rolling_mean(close, n) for n in (l1, l2, l3)]
    rows = []
    for i, c in enumerate(close):
        rows.append({
            f'BIAS{j + 1}': _rd(None if c is None or mas[j][i] is None or abs(mas[j][i] or 0) < 1e-12 else (c - (mas[j][i] or 0)) / (mas[j][i] or 1) * 100.0)
            for j in range(3)
        })
    return rows


def _psy(close: list[float | None], n: int = 12, m: int = 6) -> list[dict[str, float | None]]:
    up = [None]
    for i in range(1, len(close)):
        up.append(None if close[i] is None or close[i - 1] is None else (1.0 if close[i] > close[i - 1] else 0.0))
    psy = [None if v is None else v * 100.0 / n for v in _rolling_sum(up, n)]
    psy_ma = _rolling_mean(psy, m)
    return [{'PSY': _rd(a), 'PSY_MA': _rd(b)} for a, b in zip(psy, psy_ma)]


def _trix(close: list[float | None], m1: int = 12, m2: int = 20) -> list[dict[str, float | None]]:
    tr = _ema_series(_ema_series(_ema_series(close, m1), m1), m1)
    trix = [None]
    for i in range(1, len(tr)):
        trix.append(None if tr[i] is None or tr[i - 1] is None or abs(tr[i - 1] or 0) < 1e-12 else (tr[i] - tr[i - 1]) / tr[i - 1] * 100.0)
    trma = _rolling_mean(trix, m2)
    return [{'TRIX': _rd(a), 'TRIX_MA': _rd(b)} for a, b in zip(trix, trma)]


def _dpo(close: list[float | None], m1: int = 20, m2: int = 10, m3: int = 6) -> list[dict[str, float | None]]:
    ref_ma = _ref(_rolling_mean(close, m1), m2)
    dpo = [None if c is None or r is None else c - r for c, r in zip(close, ref_ma)]
    return [{'DPO': _rd(a), 'DPO_MA': _rd(b)} for a, b in zip(dpo, _rolling_mean(dpo, m3))]


def _mtm(close: list[float | None], n: int = 12, m: int = 6) -> list[dict[str, float | None]]:
    mtm = [None if c is None or r is None else c - r for c, r in zip(close, _ref(close, n))]
    return [{'MTM': _rd(a), 'MTM_MA': _rd(b)} for a, b in zip(mtm, _rolling_mean(mtm, m))]


def _roc(close: list[float | None], n: int = 12, m: int = 6) -> list[dict[str, float | None]]:
    roc = [None if c is None or r is None or abs(r) < 1e-12 else 100.0 * (c - r) / r for c, r in zip(close, _ref(close, n))]
    return [{'ROC': _rd(a), 'ROC_MA': _rd(b)} for a, b in zip(roc, _rolling_mean(roc, m))]


def _expma(close: list[float | None], n1: int = 12, n2: int = 50) -> list[dict[str, float | None]]:
    return [{'EXPMA_12': _rd(a), 'EXPMA_50': _rd(b)} for a, b in zip(_ema_series(close, n1), _ema_series(close, n2))]


def _bbi(close: list[float | None], m1: int = 3, m2: int = 6, m3: int = 12, m4: int = 20) -> list[dict[str, float | None]]:
    mas = [_rolling_mean(close, n) for n in (m1, m2, m3, m4)]
    return [{'BBI': _rd(None if any(v is None for v in vals) else sum(v for v in vals if v is not None) / 4.0)} for vals in zip(*mas)]


def _dfma(close: list[float | None], n1: int = 10, n2: int = 50, m: int = 10) -> list[dict[str, float | None]]:
    dif = [None if a is None or b is None else a - b for a, b in zip(_rolling_mean(close, n1), _rolling_mean(close, n2))]
    return [{'DFMA_DIF': _rd(a), 'DFMA_DMA': _rd(b)} for a, b in zip(dif, _rolling_mean(dif, m))]


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


def _atr(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 20) -> list[dict[str, float | None]]:
    return [{'ATR': _rd(v)} for v in _rolling_mean(_tr(close, high, low), n)]


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
    return [{'WR1': _rd(a), 'WR2': _rd(b)} for a, b in zip(calc(n), calc(n1))]


def _cci(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 14) -> list[dict[str, float | None]]:
    tp = [None if c is None or h is None or l is None else (h + l + c) / 3.0 for c, h, l in zip(close, high, low)]
    ma = _rolling_mean(tp, n)
    avedev = _rolling_avedev(tp, n)
    return [{'CCI': _rd(None if t is None or m is None or a is None or abs(a) < 1e-12 else (t - m) / (0.015 * a))} for t, m, a in zip(tp, ma, avedev)]


def _cr(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 20) -> list[dict[str, float | None]]:
    mid = [None if v is None else v / 3.0 for v in _ref([None if c is None or h is None or l is None else h + l + c for c, h, l in zip(close, high, low)], 1)]
    num = _rolling_sum([None if h is None or m is None else max(0.0, h - m) for h, m in zip(high, mid)], n)
    den = _rolling_sum([None if l is None or m is None else max(0.0, m - l) for l, m in zip(low, mid)], n)
    return [{'CR': _rd(100.0 if d is not None and abs(d) < 1e-12 else (None if a is None or d is None else a / d * 100.0))} for a, d in zip(num, den)]


def _ktn(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 20, m: int = 10) -> list[dict[str, float | None]]:
    typical = [None if c is None or h is None or l is None else (h + l + c) / 3.0 for c, h, l in zip(close, high, low)]
    mid = _ema_series(typical, n)
    atr = [row['ATR'] for row in _atr(close, high, low, m)]
    return [{'KTN_UPPER': _rd(None if a is None or b is None else a + 2 * b), 'KTN_MID': _rd(a), 'KTN_LOWER': _rd(None if a is None or b is None else a - 2 * b)} for a, b in zip(mid, atr)]


def _xsii(close: list[float | None], high: list[float | None], low: list[float | None], n: int = 102, m: int = 7) -> list[dict[str, float | None]]:
    base = [None if c is None or h is None or l is None else (2 * c + h + l) / 4.0 for c, h, l in zip(close, high, low)]
    aa = _rolling_mean(base, 5)
    ma20 = _rolling_mean(close, 20)
    cc = [None if b is None or ma is None or abs(ma) < 1e-12 else abs(b - ma) / ma for b, ma in zip(base, ma20)]
    dd = _dma_series(close, cc)
    return [{'XSII_TD1': _rd(None if a is None else a * n / 100.0), 'XSII_TD2': _rd(None if a is None else a * (200 - n) / 100.0), 'XSII_TD3': _rd(None if d is None else (1 + m / 100.0) * d), 'XSII_TD4': _rd(None if d is None else (1 - m / 100.0) * d)} for a, d in zip(aa, dd)]


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


def _vr(close: list[float | None], vol: list[float | None], m1: int = 26) -> list[dict[str, float | None]]:
    lc = _ref(close, 1)
    up = [None if c is None or p is None or v is None else (v if c > p else 0.0) for c, p, v in zip(close, lc, vol)]
    down = [None if c is None or p is None or v is None else (v if c <= p else 0.0) for c, p, v in zip(close, lc, vol)]
    return [{'VR': _rd(None if a is None or b is None or abs(b) < 1e-12 else a / b * 100.0)} for a, b in zip(_rolling_sum(up, m1), _rolling_sum(down, m1))]


def _emv(high: list[float | None], low: list[float | None], vol: list[float | None], n: int = 14, m: int = 9) -> list[dict[str, float | None]]:
    ma_vol = _rolling_mean(vol, n)
    vol_ratio = [None if mv is None or v is None or abs(v) < 1e-12 else mv / v for mv, v in zip(ma_vol, vol)]
    mid = []
    for i in range(len(high)):
        if i == 0 or high[i] is None or low[i] is None or high[i - 1] is None or low[i - 1] is None or abs((high[i] or 0) + (low[i] or 0)) < 1e-12:
            mid.append(None)
        else:
            mid.append(100.0 * (high[i] + low[i] - high[i - 1] - low[i - 1]) / (high[i] + low[i]))
    hl_range = [None if h is None or l is None else h - l for h, l in zip(high, low)]
    ma_hl = _rolling_mean(hl_range, n)
    raw = [None if a is None or b is None or r is None or mh is None or abs(mh) < 1e-12 else a * b * r / mh for a, b, r, mh in zip(mid, vol_ratio, hl_range, ma_hl)]
    emv = _rolling_mean(raw, n)
    return [{'EMV': _rd(a), 'EMV_MA': _rd(b)} for a, b in zip(emv, _rolling_mean(emv, m))]


def _mass(high: list[float | None], low: list[float | None], n1: int = 9, n2: int = 25, m: int = 6) -> list[dict[str, float | None]]:
    hl = [None if h is None or l is None else h - l for h, l in zip(high, low)]
    ma1 = _rolling_mean(hl, n1)
    ma2 = _rolling_mean(ma1, n1)
    ratio = [None if a is None or b is None or abs(b) < 1e-12 else a / b for a, b in zip(ma1, ma2)]
    mass = _rolling_sum(ratio, n2)
    return [{'MASS': _rd(a), 'MASS_MA': _rd(b)} for a, b in zip(mass, _rolling_mean(mass, m))]


def _mfi(close: list[float | None], high: list[float | None], low: list[float | None], vol: list[float | None], n: int = 14) -> list[dict[str, float | None]]:
    typ = [None if c is None or h is None or l is None else (h + l + c) / 3.0 for c, h, l in zip(close, high, low)]
    pos = [None]
    neg = [None]
    for i in range(1, len(typ)):
        if typ[i] is None or typ[i - 1] is None or vol[i] is None:
            pos.append(None); neg.append(None)
        elif typ[i] > typ[i - 1]:
            pos.append(typ[i] * vol[i]); neg.append(0.0)
        elif typ[i] < typ[i - 1]:
            pos.append(0.0); neg.append(typ[i] * vol[i])
        else:
            pos.append(0.0); neg.append(0.0)
    rows = []
    for p, negv in zip(_rolling_sum(pos, n), _rolling_sum(neg, n)):
        if p is None or negv is None:
            rows.append({'MFI': None})
        elif abs(negv) < 1e-12:
            rows.append({'MFI': 100.0 if p > 0 else 0.0})
        else:
            rows.append({'MFI': _rd(100.0 - 100.0 / (1.0 + p / negv))})
    return rows


def _brar(open_: list[float | None], close: list[float | None], high: list[float | None], low: list[float | None], m1: int = 26) -> list[dict[str, float | None]]:
    ar_num = _rolling_sum([None if h is None or o is None else h - o for h, o in zip(high, open_)], m1)
    ar_den = _rolling_sum([None if o is None or l is None else o - l for o, l in zip(open_, low)], m1)
    lc = _ref(close, 1)
    br_num = _rolling_sum([None if h is None or c is None else max(0.0, h - c) for h, c in zip(high, lc)], m1)
    br_den = _rolling_sum([None if c is None or l is None else max(0.0, c - l) for c, l in zip(lc, low)], m1)
    return [{'AR': _rd(None if a is None or b is None or abs(b) < 1e-12 else a / b * 100.0), 'BR': _rd(None if c is None or d is None or abs(d) < 1e-12 else c / d * 100.0)} for a, b, c, d in zip(ar_num, ar_den, br_num, br_den)]


def _asi(open_: list[float | None], close: list[float | None], high: list[float | None], low: list[float | None], m1: int = 26, m2: int = 10) -> list[dict[str, float | None]]:
    lc = _ref(close, 1)
    lo = _ref(open_, 1)
    ll = _ref(low, 1)
    si: list[float | None] = []
    for o, c, h, l, pc, po, pl in zip(open_, close, high, low, lc, lo, ll):
        if None in (o, c, h, l, pc, po, pl):
            si.append(None); continue
        aa = abs(h - pc); bb = abs(l - pc); cc = abs(h - pl); dd = abs(pc - po)
        r = aa + bb / 2.0 + dd / 4.0 if aa > bb and aa > cc else (bb + aa / 2.0 + dd / 4.0 if bb > cc and bb > aa else cc + dd / 4.0)
        x = c - pc + (c - o) / 2.0 + pc - po
        si.append(None if abs(r) < 1e-12 else 16.0 * x / r * max(aa, bb))
    asi = _rolling_sum(si, m1)
    return [{'ASI': _rd(a), 'ASI_MA': _rd(b)} for a, b in zip(asi, _rolling_mean(asi, m2))]


def _taq(high: list[float | None], low: list[float | None], n: int = 20) -> list[dict[str, float | None]]:
    up = _rolling_high(high, n)
    down = _rolling_low(low, n)
    return [{'TAQ_UP': _rd(u), 'TAQ_MID': _rd(None if u is None or d is None else (u + d) / 2.0), 'TAQ_DOWN': _rd(d)} for u, d in zip(up, down)]


def _zhuoyao(close: list[float | None], n1: int = 120, n2: int = 60, n3: int = 20, m: int = 10) -> list[dict[str, float | None]]:
    def pct(n: int) -> list[float | None]:
        ref = _ref(close, n)
        return [None if c is None or r is None or abs(r) < 1e-12 else (c / r - 1.0) * 100.0 for c, r in zip(close, ref)]
    long = _ema_series(pct(n1), m)
    mid = pct(n2)
    short = pct(n3)
    trend = _ema_series(mid, m)
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
