from __future__ import annotations

import json
from datetime import datetime, timedelta
from typing import Any, Iterable

from easy_tdx_runtime import infer_market, normalize_symbol
from chanpy_runtime import analyze_json

_SCAN_BSP_TYPES = ('1', '1p', '2', '2s', '3a', '3b')


def _to_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(str(value).replace(',', '').strip())
    except (TypeError, ValueError):
        return None


def _parse_dt(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    text = str(value).strip().replace('/', '-').replace('T', ' ')
    if not text or text.lower() in {'none', 'null', 'nan'}:
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


def _date_only(value: Any) -> datetime | None:
    dt = _parse_dt(value)
    if dt is None:
        return None
    return datetime(dt.year, dt.month, dt.day)


def _row_get(row: Any, *keys: str, default: Any = None) -> Any:
    for key in keys:
        if isinstance(row, dict) and key in row:
            return row[key]
        if hasattr(row, key):
            return getattr(row, key)
        try:
            return row[key]
        except Exception:
            pass
    return default


def _iter_rows(data: Any) -> list[Any]:
    if data is None:
        return []
    if hasattr(data, 'to_dict'):
        try:
            return list(data.to_dict('records'))
        except Exception:
            pass
    try:
        return list(data)
    except TypeError:
        return []


def _close_client(client: Any) -> None:
    for name in ('close', 'disconnect'):
        method = getattr(client, name, None)
        if callable(method):
            try:
                method()
            except Exception:
                pass
            return


def _market_enum(Market: Any, market: str) -> Any:
    name = 'SH' if market.upper() == 'SH' else 'SZ'
    if hasattr(Market, name):
        return getattr(Market, name)
    return 1 if name == 'SH' else 0


def _call_stock_list(client: Any, method_name: str, market_value: Any, market_name: str) -> list[Any]:
    method = getattr(client, method_name, None)
    if not callable(method):
        return []
    rows: list[Any] = []
    if method_name in {'get_security_list', 'get_stock_list'}:
        for offset in range(0, 100000, 1000):
            page: list[Any] = []
            for args in ((market_value, offset), (market_name, offset)):
                try:
                    page = _iter_rows(method(*args))
                    break
                except TypeError:
                    continue
                except Exception:
                    page = []
                    break
            if not page:
                break
            rows.extend(page)
            if len(page) < 800:
                break
        if rows:
            return rows
    for args in ((market_value,), (market_name,), tuple()):
        try:
            return _iter_rows(method(*args))
        except TypeError:
            continue
        except Exception:
            return []
    return []


def _normalize_stock_row(row: Any, market_name: str) -> dict[str, Any] | None:
    raw_code = _row_get(row, '代码', 'code', 'symbol', 'sec_code', 'stock_code', '证券代码')
    if raw_code is None and isinstance(row, (list, tuple)) and row:
        raw_code = row[0]
    if raw_code is None:
        return None
    code = ''.join(ch for ch in normalize_symbol(str(raw_code)) if ch.isdigit())[-6:]
    if len(code) != 6:
        return None
    raw_name = _row_get(row, '名称', 'name', 'stock_name', 'sec_name', '证券简称', default=None)
    if raw_name is None and isinstance(row, (list, tuple)) and len(row) > 1:
        raw_name = row[1]
    return {
        'code': code,
        'market': market_name,
        'name': str(raw_name or code),
        'price': _to_float(_row_get(row, '最新价', 'price', 'last', 'close', default=None)),
        'change': _to_float(_row_get(row, '涨跌幅', 'change', 'pct_chg', 'percent', default=None)),
        'volume': _to_float(_row_get(row, '成交量', 'vol', 'volume', default=None)),
        '_source': 'android_easy_tdx_list',
    }


def _passes_ashare_filter(row: dict[str, Any]) -> bool:
    code = str(row.get('code') or '')
    name = str(row.get('name') or '')
    if not code or len(code) != 6:
        return False
    if 'ST' in name.upper():
        return False
    if code.startswith('688'):
        return False
    if code.startswith(('8', '43', '83', '87')):
        return False
    if code.startswith(('200', '900')):
        return False
    if code.startswith('920'):
        return False
    volume = _to_float(row.get('volume'))
    if volume is not None and volume <= 0:
        return False
    price = _to_float(row.get('price'))
    if price is not None and price <= 0:
        return False
    return True


def _fallback_candidate_stock_rows(limit: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    ranges = (
        ('SZ', 1, 999), ('SH', 600000, 600999), ('SZ', 1000, 1999),
        ('SH', 601000, 601999), ('SZ', 2000, 2999), ('SH', 603000, 603999),
        ('SZ', 300000, 300999), ('SH', 605000, 605999), ('SZ', 301000, 301999),
    )
    max_span = max(end - start for _, start, end in ranges)
    for offset in range(max_span + 1):
        for market, start, end in ranges:
            code_num = start + offset
            if code_num > end:
                continue
            code = f'{code_num:06d}'
            key = f'{code}.{market}'
            if key in seen:
                continue
            seen.add(key)
            rows.append({'code': code, 'market': market, 'name': code, 'price': None, 'change': None, 'volume': None, '_source': 'candidate_pool'})
            if len(rows) >= limit:
                return rows
    return rows


def _rows_from_symbols(symbols: Iterable[Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in symbols:
        if isinstance(item, dict):
            code = normalize_symbol(str(item.get('code') or item.get('symbol') or ''))
            name = str(item.get('name') or code)
            market = str(item.get('market') or infer_market(code)).upper()
        else:
            code = normalize_symbol(str(item))
            name = code
            market = infer_market(code)
        code = ''.join(ch for ch in code if ch.isdigit())[-6:]
        if len(code) != 6:
            continue
        key = f'{code}.{market}'
        if key in seen:
            continue
        seen.add(key)
        rows.append({'code': code, 'market': market, 'name': name, 'price': None, 'change': None, 'volume': None})
    return rows


def _load_easy_tdx_stock_rows(limit: int) -> list[dict[str, Any]]:
    try:
        from easy_tdx import MacClient, Market
    except Exception:
        return _fallback_candidate_stock_rows(limit)
    client = MacClient.from_best_host()
    try:
        result: list[dict[str, Any]] = []
        seen: set[str] = set()
        for market_name in ('SH', 'SZ'):
            market_value = _market_enum(Market, market_name)
            rows: list[Any] = []
            for method_name in ('get_security_list', 'get_stock_list', 'get_all_stock', 'get_all_stocks', 'stock_list', 'stocks', 'securities'):
                rows = _call_stock_list(client, method_name, market_value, market_name)
                if rows:
                    break
            for row in rows:
                normalized = _normalize_stock_row(row, market_name)
                if normalized is None:
                    continue
                key = f"{normalized['code']}.{normalized['market']}"
                if key in seen:
                    continue
                seen.add(key)
                result.append(normalized)
                if len(result) >= limit:
                    return result
        return result or _fallback_candidate_stock_rows(limit)
    finally:
        _close_client(client)


def _get_tradable_stocks(*, symbols: Iterable[Any] | None, limit: int) -> list[dict[str, Any]]:
    safe_limit = max(1, min(int(limit), 5000))
    rows = _rows_from_symbols(symbols) if symbols else _load_easy_tdx_stock_rows(safe_limit * 2)
    return [row for row in rows if _passes_ashare_filter(row)][:safe_limit]


def _is_buy_bsp(row: dict[str, Any]) -> bool:
    text = str(row.get('type') or '').strip().lower()
    return text.startswith('b') or 'buy' in text or '买' in text


def _bar_change_pct(bars: list[dict[str, Any]]) -> float | None:
    if len(bars) < 2:
        return None
    last = _to_float(bars[-1].get('close'))
    prev = _to_float(bars[-2].get('close'))
    if last is None or prev in (None, 0):
        return None
    return (last - prev) / prev * 100.0


def _result_from_buy(row: dict[str, Any], bars: list[dict[str, Any]], latest_buy: dict[str, Any], analysis: dict[str, Any]) -> dict[str, Any]:
    latest_price = _to_float(row.get('price')) or _to_float(bars[-1].get('close'))
    change = _to_float(row.get('change'))
    if change is None:
        change = _bar_change_pct(bars)
    raw_index = int(latest_buy.get('raw_index') or latest_buy.get('rawIndex') or 0)
    bsp_price = _to_float(latest_buy.get('price')) or latest_price
    return {
        'code': str(row['code']),
        'market': str(row.get('market') or infer_market(str(row['code']))).upper(),
        'name': str(row.get('name') or row['code']),
        'price': latest_price,
        'change': change,
        'bsp_type': str(latest_buy.get('type') or 'BSP'),
        'bsp_time': str(latest_buy.get('time') or ''),
        'raw_index': raw_index,
        'bsp_price': bsp_price,
        'level': str(latest_buy.get('level') or ''),
        'analysis': analysis,
    }


def _config_payload(bi_strict: bool) -> dict[str, Any]:
    return {
        'bi_strict': bi_strict,
        'trigger_step': False,
        'skip_step': 0,
        'divergence_rate': 'inf',
        'bsp2_follow_1': False,
        'bsp3_follow_1': False,
        'min_zs_cnt': 0,
        'bs1_peak': False,
        'macd_algo': 'peak',
        'bs_type': ','.join(_SCAN_BSP_TYPES),
        'print_warning': False,
        'zs_algo': 'normal',
    }


def scan_bsp_json(payload_json: str) -> str:
    payload = json.loads(payload_json or '{}')
    limit = max(1, min(int(payload.get('limit') or 300), 5000))
    days = max(30, min(int(payload.get('days') or 365), 5000))
    recent_days = max(1, min(int(payload.get('recent_days') or 3), 120))
    bi_strict = bool(payload.get('bi_strict', True))
    config = payload.get('config') if isinstance(payload.get('config'), dict) else {}
    config = {**_config_payload(bi_strict), **config, 'bi_strict': bi_strict}
    symbols = payload.get('symbols') if isinstance(payload.get('symbols'), list) else None

    begin_time = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d')
    end_time = datetime.now().strftime('%Y-%m-%d')
    cutoff_date = datetime.now() - timedelta(days=recent_days)
    logs: list[str] = []
    results: list[dict[str, Any]] = []
    success_count = 0
    fail_count = 0

    try:
        stock_list = _get_tradable_stocks(symbols=symbols, limit=limit)
    except Exception as exc:
        return json.dumps({'ok': False, 'error': f'获取股票列表失败: {exc}', 'results': [], 'logs': [], 'total': 0, 'success_count': 0, 'fail_count': 0, 'found_count': 0}, ensure_ascii=False)

    logs.append(f'获取到 {len(stock_list)} 只可交易股票（Android easy-tdx），开始扫描...')
    for idx, row in enumerate(stock_list):
        code = str(row['code'])
        market = str(row.get('market') or infer_market(code)).upper()
        name = str(row.get('name') or code)
        logs.append(f'🔍 扫描 {idx + 1}/{len(stock_list)} {code} {name}...')
        try:
            analysis = json.loads(analyze_json(json.dumps({
                'mode': 'once',
                'symbol': code,
                'market': market,
                'freq': 'DAILY',
                'adjust': 'QFQ',
                'start': begin_time,
                'end': end_time,
                'count': 5000,
                'config': config,
            }, ensure_ascii=False)))
            if not analysis.get('ok', False):
                fail_count += 1
                logs.append(f"❌ {code} {name}: {str(analysis.get('error') or 'chan.py 计算失败')[:120]}")
                continue
            bars = analysis.get('bars') if isinstance(analysis.get('bars'), list) else []
            if not bars:
                fail_count += 1
                logs.append(f'⏭️ {code} {name}: 无K线数据')
                continue
            last_date = _date_only(bars[-1].get('dt') or bars[-1].get('time') or bars[-1].get('date'))
            if last_date is None or (datetime.now() - last_date).days > 15:
                fail_count += 1
                logs.append(f'⏸️ {code} {name}: 停牌超过15天')
                continue
            last_volume = _to_float(bars[-1].get('vol') or bars[-1].get('volume'))
            if last_volume is not None and last_volume <= 0:
                fail_count += 1
                logs.append(f'⏸️ {code} {name}: 成交量为0')
                continue

            success_count += 1
            bsp_rows = analysis.get('bsp') if isinstance(analysis.get('bsp'), list) else []
            buy_points: list[dict[str, Any]] = []
            for bsp in bsp_rows:
                if not isinstance(bsp, dict) or not _is_buy_bsp(bsp):
                    continue
                bsp_dt = _date_only(bsp.get('time'))
                if bsp_dt is not None and bsp_dt >= cutoff_date:
                    buy_points.append(bsp)
            if not buy_points:
                logs.append(f'➖ {code} {name}: 无近期买点')
                continue
            buy_points.sort(key=lambda item: int(item.get('raw_index') or item.get('rawIndex') or -1), reverse=True)
            result = _result_from_buy(row, bars, buy_points[0], analysis)
            results.append(result)
            logs.append(f"✅ {code} {name}: 发现买点 {result['bsp_type']}")
        except Exception as exc:
            fail_count += 1
            logs.append(f'❌ {code} {name}: {str(exc)[:120]}')
            continue

    return json.dumps({
        'ok': True,
        'source': 'android-chaquopy/easy-tdx',
        'days': days,
        'recent_days': recent_days,
        'total': len(stock_list),
        'success_count': success_count,
        'fail_count': fail_count,
        'found_count': len(results),
        'results': results,
        'logs': logs,
        'config': _config_payload(bi_strict),
    }, ensure_ascii=False, allow_nan=False)
