from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any, Iterable

from .chanpy_engine import analyze_once
from .easy_tdx_provider import infer_market, normalize_symbol


_SCAN_BSP_TYPES = ('1', '1p', '2', '2s', '3a', '3b')


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
    if isinstance(data, dict):
        return list(data.values())
    try:
        return list(data)
    except TypeError:
        return []


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


def _bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {'1', 'true', 'yes', 'y', 'on'}


def _market_enum(Market: Any, market: str) -> Any:
    name = 'SH' if market.upper() == 'SH' else 'SZ'
    if hasattr(Market, name):
        return getattr(Market, name)
    return 1 if name == 'SH' else 0


def _close_client(client: Any) -> None:
    for name in ('close', 'disconnect'):
        method = getattr(client, name, None)
        if callable(method):
            try:
                method()
            except Exception:
                pass
            return


def _call_stock_list(client: Any, method_name: str, market_value: Any, market_name: str) -> list[Any]:
    method = getattr(client, method_name, None)
    if not callable(method):
        return []

    rows: list[Any] = []
    # pytdx-style APIs usually page by offset. easy-tdx wrappers may also expose
    # a one-shot stock list method. Try both shapes without changing Chan logic.
    if method_name in {'get_security_list', 'get_security_bars'}:
        for offset in range(0, 100000, 1000):
            page = []
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
        return rows

    for args in ((market_value,), (market_name,), tuple()):
        try:
            return _iter_rows(method(*args))
        except TypeError:
            continue
        except Exception:
            return []
    return []


def _load_easy_tdx_stock_rows(limit: int) -> list[dict[str, Any]]:
    try:
        from easy_tdx import MacClient, Market
    except Exception as exc:  # pragma: no cover - environment dependent
        raise RuntimeError('未安装 easy-tdx，或当前 Python 环境无法导入 easy_tdx / easy-tdx') from exc

    client = MacClient.from_best_host()
    try:
        result: list[dict[str, Any]] = []
        seen: set[str] = set()
        for market_name in ('SH', 'SZ'):
            market_value = _market_enum(Market, market_name)
            rows: list[Any] = []
            for method_name in (
                'get_security_list',
                'get_stock_list',
                'get_all_stock',
                'get_all_stocks',
                'stock_list',
                'stocks',
            ):
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
        return result
    finally:
        _close_client(client)


def _normalize_stock_row(row: Any, market_name: str) -> dict[str, Any] | None:
    raw_code = _row_get(row, '代码', 'code', 'symbol', 'sec_code', 'stock_code', '证券代码')
    if raw_code is None:
        return None
    code = normalize_symbol(str(raw_code))
    code = ''.join(ch for ch in code if ch.isdigit())[-6:]
    if len(code) != 6:
        return None
    name = str(_row_get(row, '名称', 'name', 'stock_name', 'sec_name', '证券简称', default=code) or code)
    return {
        'code': code,
        'market': market_name,
        'name': name,
        'price': _to_float(_row_get(row, '最新价', 'price', 'last', 'close', default=None)),
        'change': _to_float(_row_get(row, '涨跌幅', 'change', 'pct_chg', 'percent', default=None)),
        'volume': _to_float(_row_get(row, '成交量', 'vol', 'volume', default=None)),
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


def get_tradable_stocks(*, symbols: Iterable[Any] | None = None, limit: int = 300) -> list[dict[str, Any]]:
    safe_limit = max(1, min(int(limit), 5000))
    rows = _rows_from_symbols(symbols) if symbols else _load_easy_tdx_stock_rows(safe_limit * 2)
    filtered = [row for row in rows if _passes_ashare_filter(row)]
    return filtered[:safe_limit]


def scanner_chan_config(*, bi_strict: bool = True, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    # Mirrors App/ashare_bsp_scanner_gui.py::get_chan_config, with easy-tdx bars
    # feeding the existing chan.py export path. No Chan calculation is implemented here.
    result: dict[str, Any] = {
        'bi_strict': bi_strict,
        'trigger_step': False,
        'skip_step': 0,
        'divergence_rate': float('inf'),
        'bsp2_follow_1': False,
        'bsp3_follow_1': False,
        'min_zs_cnt': 0,
        'bs1_peak': False,
        'macd_algo': 'peak',
        'bs_type': ','.join(_SCAN_BSP_TYPES),
        'print_warning': False,
        'zs_algo': 'normal',
    }
    if extra:
        for key, value in extra.items():
            if value is not None:
                result[str(key)] = value
    return result


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


def _date_only(value: Any) -> datetime | None:
    dt = _parse_dt(value)
    if dt is None:
        return None
    return datetime(dt.year, dt.month, dt.day)


def scan_bsp(
    *,
    limit: int = 300,
    days: int = 365,
    recent_days: int = 3,
    bi_strict: bool = True,
    symbols: Iterable[Any] | None = None,
    config: dict[str, Any] | None = None,
) -> dict[str, Any]:
    logs: list[str] = []
    begin_time = (datetime.now() - timedelta(days=max(1, int(days)))).strftime('%Y-%m-%d')
    end_time = datetime.now().strftime('%Y-%m-%d')
    cutoff_date = datetime.now() - timedelta(days=max(1, int(recent_days)))
    chan_config = scanner_chan_config(bi_strict=bi_strict, extra=config)

    try:
        stock_list = get_tradable_stocks(symbols=symbols, limit=limit)
    except Exception as exc:
        return {
            'ok': False,
            'error': f'获取股票列表失败: {exc}',
            'source': 'easy-tdx',
            'results': [],
            'logs': [f'❌ 获取股票列表失败: {exc}'],
            'success_count': 0,
            'fail_count': 0,
            'found_count': 0,
        }

    logs.append(f'获取到 {len(stock_list)} 只可交易股票，开始扫描...')
    success_count = 0
    fail_count = 0
    results: list[dict[str, Any]] = []

    for idx, row in enumerate(stock_list):
        code = str(row['code'])
        market = str(row.get('market') or infer_market(code)).upper()
        name = str(row.get('name') or code)
        logs.append(f'🔍 扫描 {idx + 1}/{len(stock_list)} {code} {name}...')
        try:
            analysis = analyze_once(
                symbol=code,
                market=market,
                freq='DAILY',
                adjust='QFQ',
                start=begin_time,
                end=end_time,
                count=5000,
                config=chan_config,
            )
            if not analysis.get('ok', False):
                fail_count += 1
                logs.append(f"❌ {code} {name}: {str(analysis.get('error') or 'chan.py 计算失败')[:80]}")
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
            latest_buy = buy_points[0]
            latest_price = _to_float(row.get('price')) or _to_float(bars[-1].get('close'))
            change = _to_float(row.get('change'))
            if change is None:
                change = _bar_change_pct(bars)
            raw_index = int(latest_buy.get('raw_index') or latest_buy.get('rawIndex') or 0)
            bsp_price = _to_float(latest_buy.get('price')) or latest_price
            bsp_type = str(latest_buy.get('type') or 'BSP')
            bsp_time = str(latest_buy.get('time') or '')
            logs.append(f'✅ {code} {name}: 发现买点 {bsp_type}')
            results.append({
                'code': code,
                'market': market,
                'name': name,
                'price': latest_price,
                'change': change,
                'bsp_type': bsp_type,
                'bsp_time': bsp_time,
                'raw_index': raw_index,
                'bsp_price': bsp_price,
                'level': str(latest_buy.get('level') or ''),
            })
        except Exception as exc:
            fail_count += 1
            logs.append(f'❌ {code} {name}: {str(exc)[:80]}')
            continue

    return {
        'ok': True,
        'source': 'easy-tdx',
        'days': days,
        'recent_days': recent_days,
        'total': len(stock_list),
        'success_count': success_count,
        'fail_count': fail_count,
        'found_count': len(results),
        'results': results,
        'logs': logs,
        'config': {
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
        },
    }
