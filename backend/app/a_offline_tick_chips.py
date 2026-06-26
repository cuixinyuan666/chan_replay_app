from __future__ import annotations

from collections.abc import Iterable
from datetime import date, datetime, time, timedelta
from functools import lru_cache
from pathlib import Path
import math
import re
from typing import Any

_BOOL_FALSE = {'0', 'false', 'no', 'n', 'off'}
_INTRADAY_MINUTES = {
    'TICK_MIN1': 1,
    'TICK_1MIN': 1,
    'TICK_MIN_1': 1,
    'TXN_MIN1': 1,
    'TRANSACTION_MIN1': 1,
    'TRANSACTIONS_MIN1': 1,
    'MIN1': 1,
    '1M': 1,
    'M1': 1,
    'MIN5': 5,
    '5M': 5,
    'M5': 5,
    'MIN15': 15,
    '15M': 15,
    'M15': 15,
    'MIN30': 30,
    '30M': 30,
    'M30': 30,
    'MIN60': 60,
    '60M': 60,
    'M60': 60,
}
_DAILY_LEVELS = {'D', 'DAY', 'DAILY', 'K_DAY', 'KDAY'}
_RAW_TICK_LEVELS = {'TICK', 'TRANSACTION', 'TRANSACTIONS'}
_TIME_RE = re.compile(r'^\d{1,2}:\d{2}(?::\d{2})?$')


def attach_offline_tick_bins(
    result: dict[str, Any],
    *,
    payload: dict[str, Any],
    config: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Attach a_Data offline transaction chips to exported bars only.

    This is a transport/data enrichment layer.  It must run after chan.py has
    produced bars/structures and before Flutter parses bars into RawBar objects.
    It never mutates or recalculates FX/BI/SEG/ZS/BSP structures.
    """

    cfg = config or {}
    if _disabled(cfg) or not isinstance(result, dict) or not isinstance(result.get('levels'), dict):
        return result

    code = _normalize_symbol(payload.get('symbol') or result.get('symbol') or '')
    if not code:
        return result

    patched = dict(result)
    summary: dict[str, Any] = {
        'enabled': True,
        'source': 'a_Data',
        'code': code,
        'levels': {},
        'attached_bar_count': 0,
        'transaction_count': 0,
        'matched_day_count': 0,
        'missing_day_count': 0,
        'status': 'no_matching_level',
    }

    patched['levels'] = _patch_levels(result['levels'], code, summary)

    frames = result.get('frames')
    if isinstance(frames, list):
        patched_frames: list[Any] = []
        for frame in frames:
            if isinstance(frame, dict) and isinstance(frame.get('levels'), dict):
                next_frame = dict(frame)
                next_frame['levels'] = _patch_levels(frame['levels'], code, summary)
                patched_frames.append(next_frame)
            else:
                patched_frames.append(frame)
        patched['frames'] = patched_frames

    if summary['attached_bar_count'] > 0:
        summary['status'] = 'ok'
    elif summary['missing_day_count'] > 0:
        summary['status'] = 'no_offline_files_for_window'

    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    meta['offline_tick_chip_bins'] = summary
    patched['meta'] = meta
    return patched


def _patch_levels(levels: dict[Any, Any], code: str, summary: dict[str, Any]) -> dict[Any, Any]:
    out: dict[Any, Any] = {}
    for key, payload in levels.items():
        if not isinstance(payload, dict):
            out[key] = payload
            continue
        level = str(key).strip().upper()
        bars = payload.get('bars')
        if not isinstance(bars, list) or not bars:
            out[key] = payload
            continue
        next_bars, meta = attach_offline_tick_bins_to_bars(
            bars,
            symbol=code,
            level=level,
        )
        summary['levels'][level] = meta
        summary['attached_bar_count'] += int(meta.get('attached_bar_count') or 0)
        summary['transaction_count'] += int(meta.get('transaction_count') or 0)
        summary['matched_day_count'] += int(meta.get('matched_day_count') or 0)
        summary['missing_day_count'] += int(meta.get('missing_day_count') or 0)
        if next_bars is bars:
            out[key] = payload
            continue
        next_payload = dict(payload)
        next_payload['bars'] = next_bars
        pmeta = dict(next_payload.get('meta')) if isinstance(next_payload.get('meta'), dict) else {}
        pmeta['offline_tick_chip_bins'] = meta
        next_payload['meta'] = pmeta
        out[key] = next_payload
    return out


def attach_offline_tick_bins_to_bars(
    bars: list[Any],
    *,
    symbol: str,
    level: str,
) -> tuple[list[Any], dict[str, Any]]:
    code = _normalize_symbol(symbol)
    normalized_level = level.strip().upper().replace('-', '_')
    if normalized_level in _RAW_TICK_LEVELS:
        return bars, {
            'status': 'skipped_raw_tick_level',
            'source': 'a_Data',
            'code': code,
            'level': normalized_level,
            'attached_bar_count': 0,
            'transaction_count': 0,
            'matched_day_count': 0,
            'missing_day_count': 0,
            'reason': 'offline files have minute timestamps; raw TICK bars must not duplicate minute volume',
        }

    row_dates = _bar_dates(bars)
    if not row_dates:
        return bars, _empty_meta(code, normalized_level, 'no_bar_dates')

    rows_by_day, missing_days = _load_ticks_by_dates(code, row_dates)
    if not rows_by_day:
        return bars, {
            **_empty_meta(code, normalized_level, 'no_offline_files'),
            'missing_days': missing_days[:20],
            'missing_day_count': len(missing_days),
        }

    next_bars: list[Any] = []
    changed = False
    attached = 0
    transaction_count = 0
    matched_days: set[str] = set()

    for index, row in enumerate(bars):
        if not isinstance(row, dict):
            next_bars.append(row)
            continue
        bar_dt = _parse_dt(_time_text(row))
        if bar_dt is None:
            next_bars.append(row)
            continue
        day_key = _date_key(bar_dt.date())
        ticks = rows_by_day.get(day_key) or []
        if not ticks:
            next_bars.append(row)
            continue
        selected_ticks, anchor = _ticks_for_bar(
            bars=bars,
            index=index,
            level=normalized_level,
            bar_dt=bar_dt,
            ticks=ticks,
        )
        bins = _ticks_to_bins(selected_ticks, level=normalized_level, trade_date=day_key, anchor=anchor)
        if not bins:
            next_bars.append(row)
            continue
        next_row = dict(row)
        next_row['chip_tick_bins'] = bins
        next_row['offline_tick_chip_bins'] = True
        next_row['offline_tick_source'] = 'a_Data'
        next_bars.append(next_row)
        changed = True
        attached += 1
        transaction_count += len(selected_ticks)
        matched_days.add(day_key)

    meta = {
        'status': 'ok' if changed else 'no_bar_matched',
        'source': 'a_Data',
        'code': code,
        'level': normalized_level,
        'attached_bar_count': attached,
        'transaction_count': transaction_count,
        'matched_days': sorted(matched_days)[:20],
        'matched_day_count': len(matched_days),
        'missing_days': missing_days[:20],
        'missing_day_count': len(missing_days),
    }
    return (next_bars if changed else bars), meta


def load_offline_tick_transaction_bars(
    *,
    symbol: str,
    market: str | None = None,
    period: str = 'TICK',
    adjust: str = 'QFQ',
    start: str | None = None,
    end: str | None = None,
    count: int | None = None,
) -> list[dict[str, Any]]:
    """Load a_Data rows as transaction-like bars.

    The text files only expose minute-level timestamps in the currently observed
    samples, so raw transaction ordering inside one minute follows file order.
    """

    code = _normalize_symbol(symbol)
    start_dt, end_dt = _window_bounds(start, end)
    date_keys = _date_keys_for_window(start_dt, end_dt, code)
    rows_by_day, _ = _load_ticks_by_dates(code, date_keys)
    rows: list[dict[str, Any]] = []
    market_name = str(market or '').strip().upper()
    period_name = str(period or 'TICK').strip().upper()
    adjust_name = str(adjust or 'QFQ').strip().upper()

    for day_key in sorted(rows_by_day):
        for tick in rows_by_day[day_key]:
            dt = tick['dt']
            if start_dt is not None and dt < start_dt:
                continue
            if end_dt is not None and dt > end_dt:
                continue
            raw_index = len(rows)
            price = tick['price']
            volume = tick['volume']
            side = tick['side']
            rows.append({
                'id': raw_index,
                'raw_index': raw_index,
                'dt': dt.isoformat(sep=' '),
                'time': dt.isoformat(sep=' '),
                'open': price,
                'high': price,
                'low': price,
                'close': price,
                'vol': volume,
                'volume': volume,
                'amount': None,
                'turnover': None,
                'transaction_side': side,
                'symbol': f'{code}.{market_name}' if market_name else code,
                'market': market_name,
                'code': code,
                'period': period_name,
                'adjust': adjust_name,
                'offline_tick_source': 'a_Data',
                'chip_tick_bins': _ticks_to_bins([tick], level=period_name, trade_date=day_key, anchor='raw_tick'),
            })

    rows.sort(key=lambda row: (str(row.get('dt') or ''), int(row.get('raw_index') or 0)))
    if count is not None and count > 0 and len(rows) > count:
        rows = rows[-count:]
    for raw_index, row in enumerate(rows):
        row['id'] = raw_index
        row['raw_index'] = raw_index
    return rows


def _ticks_for_bar(
    *,
    bars: list[Any],
    index: int,
    level: str,
    bar_dt: datetime,
    ticks: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], str]:
    if _is_daily_level(level):
        selected = [tick for tick in ticks if tick['dt'].date() == bar_dt.date()]
        return selected, 'date'

    minutes = _period_minutes(level)
    if minutes is None:
        selected = [tick for tick in ticks if tick['dt'].replace(second=0, microsecond=0) == bar_dt.replace(second=0, microsecond=0)]
        return selected, 'same_minute'

    start_end = _start_anchor_range(bars, index, bar_dt, minutes)
    end_end = _end_anchor_range(bars, index, bar_dt, minutes)
    start_ticks = _ticks_between(ticks, *start_end, include_right=False)
    end_ticks = _ticks_between(ticks, *end_end, include_right=True)

    current_row = bars[index] if isinstance(bars[index], dict) else {}
    bar_volume = _float(current_row.get('volume', current_row.get('vol')))
    if bar_volume > 0 and start_ticks and end_ticks:
        start_diff = abs(sum(t['volume'] for t in start_ticks) - bar_volume)
        end_diff = abs(sum(t['volume'] for t in end_ticks) - bar_volume)
        return (end_ticks, 'end_time_volume_match') if end_diff < start_diff else (start_ticks, 'start_time_volume_match')
    if start_ticks:
        return start_ticks, 'start_time'
    return end_ticks, 'end_time'


def _start_anchor_range(bars: list[Any], index: int, bar_dt: datetime, minutes: int) -> tuple[datetime, datetime]:
    next_dt = _neighbor_dt(bars, index, step=1, same_date=bar_dt.date())
    end = next_dt if next_dt is not None and next_dt > bar_dt else bar_dt + timedelta(minutes=minutes)
    return bar_dt, end


def _end_anchor_range(bars: list[Any], index: int, bar_dt: datetime, minutes: int) -> tuple[datetime, datetime]:
    prev_dt = _neighbor_dt(bars, index, step=-1, same_date=bar_dt.date())
    start = prev_dt if prev_dt is not None and prev_dt < bar_dt else bar_dt - timedelta(minutes=minutes)
    return start, bar_dt


def _neighbor_dt(bars: list[Any], index: int, *, step: int, same_date: date) -> datetime | None:
    cursor = index + step
    while 0 <= cursor < len(bars):
        row = bars[cursor]
        if isinstance(row, dict):
            dt = _parse_dt(_time_text(row))
            if dt is not None:
                return dt if dt.date() == same_date else None
        cursor += step
    return None


def _ticks_between(
    ticks: list[dict[str, Any]],
    start: datetime,
    end: datetime,
    *,
    include_right: bool,
) -> list[dict[str, Any]]:
    if include_right:
        return [tick for tick in ticks if start < tick['dt'] <= end]
    return [tick for tick in ticks if start <= tick['dt'] < end]


def _ticks_to_bins(
    ticks: list[dict[str, Any]],
    *,
    level: str,
    trade_date: str,
    anchor: str,
) -> dict[str, Any]:
    sell: dict[float, float] = {}
    buy: dict[float, float] = {}
    total: dict[float, float] = {}
    for tick in ticks:
        price = _norm_price(tick.get('price'))
        volume = _float(tick.get('volume'))
        if price <= 0 or volume <= 0:
            continue
        side = str(tick.get('side') or '').lower()
        if side == 'sell':
            sell[price] = sell.get(price, 0.0) + volume
        else:
            buy[price] = buy.get(price, 0.0) + volume
        total[price] = total.get(price, 0.0) + volume

    prices = sorted(total)
    if not prices:
        return {}
    return {
        'p': prices,
        's': [sell.get(price, 0.0) for price in prices],
        'b': [buy.get(price, 0.0) for price in prices],
        'w': [total.get(price, 0.0) for price in prices],
        'source': 'offline_a_Data',
        'source_period': 'TICK',
        'agg_period': level,
        'trade_date': trade_date,
        'bar_time_anchor': anchor,
        'transaction_count': len(ticks),
    }


def _load_ticks_by_dates(code: str, date_keys: Iterable[str]) -> tuple[dict[str, list[dict[str, Any]]], list[str]]:
    out: dict[str, list[dict[str, Any]]] = {}
    missing: list[str] = []
    data_dir = _offline_dir(code)
    if data_dir is None:
        return out, sorted(set(str(key) for key in date_keys))
    for day_key in sorted(set(str(key) for key in date_keys if key)):
        path = data_dir / f'{day_key}_{code}.txt'
        if not path.exists():
            missing.append(day_key)
            continue
        rows = _read_tick_file(str(path), day_key)
        if rows:
            out[day_key] = rows
    return out, missing


@lru_cache(maxsize=512)
def _read_tick_file(path_text: str, day_key: str) -> list[dict[str, Any]]:
    path = Path(path_text)
    try:
        raw = path.read_bytes()
    except OSError:
        return []
    text: str | None = None
    for encoding in ('utf-8-sig', 'gb18030', 'gbk'):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    if text is None:
        text = raw.decode('utf-8', errors='ignore')

    try:
        day = datetime.strptime(day_key, '%Y%m%d').date()
    except ValueError:
        return []

    rows: list[dict[str, Any]] = []
    for sequence, line in enumerate(text.splitlines()):
        parsed = _parse_tick_line(line, day, sequence)
        if parsed is not None:
            rows.append(parsed)
    rows.sort(key=lambda row: (row['dt'], int(row.get('sequence') or 0)))
    return rows


def _parse_tick_line(line: str, day: date, sequence: int) -> dict[str, Any] | None:
    parts = line.strip().split()
    if len(parts) < 3 or not _TIME_RE.match(parts[0]):
        return None
    try:
        clock = [int(part) for part in parts[0].split(':')]
        price = float(parts[1])
        volume = float(parts[2])
    except (TypeError, ValueError):
        return None
    if price <= 0 or volume <= 0 or not math.isfinite(price) or not math.isfinite(volume):
        return None
    side_token = parts[-1].strip().upper() if parts else ''
    side = 'sell' if side_token == 'S' else 'buy' if side_token == 'B' else 'unknown'
    return {
        'dt': datetime(day.year, day.month, day.day, clock[0], clock[1], clock[2] if len(clock) > 2 else 0),
        'price': price,
        'volume': volume,
        'side': side,
        'sequence': sequence,
    }


def _date_keys_for_window(start_dt: datetime | None, end_dt: datetime | None, code: str) -> list[str]:
    if start_dt is None and end_dt is None:
        data_dir = _offline_dir(code)
        if data_dir is None:
            return []
        keys: list[str] = []
        for path in sorted(data_dir.glob(f'*_{code}.txt')):
            match = re.match(r'^(\d{8})_', path.name)
            if match:
                keys.append(match.group(1))
        return keys
    start_anchor = start_dt or end_dt
    end_anchor = end_dt or start_dt
    if start_anchor is None or end_anchor is None:
        return []
    start_day = start_anchor.date()
    end_day = end_anchor.date()
    if start_day > end_day:
        start_day, end_day = end_day, start_day
    keys: list[str] = []
    cursor = start_day
    while cursor <= end_day:
        keys.append(_date_key(cursor))
        cursor += timedelta(days=1)
    return keys


def _bar_dates(bars: list[Any]) -> list[str]:
    dates: set[str] = set()
    for row in bars:
        if not isinstance(row, dict):
            continue
        dt = _parse_dt(_time_text(row))
        if dt is not None:
            dates.add(_date_key(dt.date()))
    return sorted(dates)


def _offline_dir(code: str) -> Path | None:
    if not code:
        return None
    for parent in Path(__file__).resolve().parents:
        candidate = parent / 'a_Data' / code
        if candidate.exists() and candidate.is_dir():
            return candidate
    return None


def _window_bounds(start: str | None, end: str | None) -> tuple[datetime | None, datetime | None]:
    start_dt = _parse_dt(start) if start else None
    end_dt = _parse_dt(end) if end else None
    if end_dt is not None and end and len(str(end).strip().replace('/', '-')) <= 10 and ':' not in str(end):
        end_dt = datetime.combine(end_dt.date(), time.max)
    return start_dt, end_dt


def _is_daily_level(level: str) -> bool:
    return level.strip().upper().replace('-', '_') in _DAILY_LEVELS


def _period_minutes(level: str) -> int | None:
    return _INTRADAY_MINUTES.get(level.strip().upper().replace('-', '_'))


def _time_text(row: dict[str, Any]) -> str:
    return str(row.get('time') or row.get('dt') or row.get('datetime') or row.get('date') or '')


def _parse_dt(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, date):
        return datetime.combine(value, time.min)
    text = str(value).strip().replace('/', '-').replace('T', ' ')
    if not text:
        return None
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%d %H:%M', '%Y-%m-%d'):
        try:
            return datetime.strptime(text[:19], fmt)
        except ValueError:
            pass
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return None


def _date_key(value: date) -> str:
    return f'{value.year:04d}{value.month:02d}{value.day:02d}'


def _normalize_symbol(symbol: Any) -> str:
    text = str(symbol or '').strip().upper()
    for suffix in ('.SZ', '.SH', '.BJ'):
        text = text.replace(suffix, '')
    digits = ''.join(ch for ch in text if ch.isdigit())
    return digits[-6:].zfill(6) if digits else ''


def _disabled(config: dict[str, Any]) -> bool:
    raw = config.get('offline_tick_chip_bins_enabled', config.get('a_data_tick_chip_bins_enabled', True))
    return (not raw) if isinstance(raw, bool) else str(raw).strip().lower() in _BOOL_FALSE


def _empty_meta(code: str, level: str, status: str) -> dict[str, Any]:
    return {
        'status': status,
        'source': 'a_Data',
        'code': code,
        'level': level,
        'attached_bar_count': 0,
        'transaction_count': 0,
        'matched_day_count': 0,
        'missing_day_count': 0,
    }


def _float(value: Any) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0.0
    return number if math.isfinite(number) else 0.0


def _norm_price(value: Any) -> float:
    number = _float(value)
    return round(number, 4) if number > 0 else 0.0
