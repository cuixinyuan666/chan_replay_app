from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta
from math import isfinite
from typing import Any, Iterable

from .a_bsp_scanner import get_tradable_stocks, scanner_chan_config
from .a_multilevel_engine_timed import analyze_multi
from .chanpy_engine import analyze_once
from .easy_tdx_provider import infer_market, normalize_symbol

DEFAULT_LEVELS = ('DAILY', 'WEEKLY', 'MONTHLY', 'MIN60', 'MIN30', 'MIN15', 'MIN5', 'MIN1')
DEFAULT_DOMAINS = ('bi', 'seg', 'seg2', 'seg3', 'seg4', 'seg5', 'seg6', 'seg7', 'seg8', 'seg9')
DEFAULT_TYPES = ('1', '1p', '2', '2s', '3a', '3b', 'B1', 'B1p', 'B2', 'B2s', 'B3a', 'B3b', 'S1', 'S1p', 'S2', 'S2s', 'S3a', 'S3b')


def condition_catalog() -> dict[str, Any]:
    return {
        'ok': True,
        'levels': list(DEFAULT_LEVELS),
        'domains': [
            {'value': 'bi', 'label': '笔买卖点/原生 BSP'},
            {'value': 'seg', 'label': '线段买卖点'},
            *[{'value': f'seg{i}', 'label': f'{i}段买卖点/递归段域'} for i in range(2, 10)],
        ],
        'sides': [{'value': 'buy', 'label': '买点'}, {'value': 'sell', 'label': '卖点'}, {'value': 'any', 'label': '买卖不限'}],
        'types': list(DEFAULT_TYPES),
        'operators': ['all', 'any'],
        'entry_rule_kinds': ['condition_group'],
        'exit_rule_kinds': ['fixed_horizon', 'condition_group', 'take_profit_pct', 'stop_loss_pct'],
        'domain_policy': 'seg2/seg3/... first read native recursive BSP keys. When only bi BSP exists the result is marked fallback_to_bi_bsp, never silently promoted.',
    }


def _obj(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _to_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        number = float(str(value).replace(',', '').strip())
        return number if isfinite(number) else None
    except Exception:
        return None


def _to_int(value: Any) -> int | None:
    try:
        return int(value)
    except Exception:
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


def _normalize_code(value: Any) -> str:
    code = normalize_symbol(str(value or '000001'))
    digits = ''.join(ch for ch in code if ch.isdigit())[-6:]
    return digits or code


def _payload_levels(payload: dict[str, Any], conditions: list[dict[str, Any]] | None = None) -> list[str]:
    raw = payload.get('levels') or payload.get('lv_list') or payload.get('level_order')
    if isinstance(raw, str):
        levels = [part.strip().upper() for part in raw.replace('，', ',').split(',') if part.strip()]
    elif isinstance(raw, list):
        levels = [str(item).strip().upper() for item in raw if str(item).strip()]
    else:
        levels = []
    for condition in conditions or []:
        level = str(condition.get('level') or '').strip().upper()
        if level and level not in levels:
            levels.append(level)
    return levels or ['DAILY', 'MIN30', 'MIN5']


def _conditions(group: Any) -> list[dict[str, Any]]:
    raw = group.get('conditions') if isinstance(group, dict) else group
    return [dict(item) for item in raw] if isinstance(raw, list) else []


def _analysis_for(payload: dict[str, Any], conditions: list[dict[str, Any]]) -> dict[str, Any]:
    code = _normalize_code(payload.get('symbol') or payload.get('code'))
    market = str(payload.get('market') or infer_market(code)).upper()
    levels = _payload_levels(payload, conditions)
    config = scanner_chan_config(
        bi_strict=bool(payload.get('bi_strict', True)),
        extra=payload.get('config') if isinstance(payload.get('config'), dict) else {},
    )
    common = dict(
        symbol=code,
        market=market,
        adjust=str(payload.get('adjust') or 'QFQ'),
        start=payload.get('start'),
        end=payload.get('end'),
        count=int(payload.get('count') or 5000),
        config=config,
    )
    if len(levels) <= 1:
        result = analyze_once(freq=levels[0], **common)
        result['levels'] = {levels[0]: result}
        result['main_level'] = levels[0]
        return result
    return analyze_multi(
        levels=levels,
        mode=str(payload.get('mode') or 'once'),
        main_level=payload.get('main_level') or payload.get('mainLevel') or levels[0],
        clock_level=payload.get('clock_level') or payload.get('clockLevel') or levels[0],
        **common,
    )


def _level_payload(analysis: dict[str, Any], level: str) -> dict[str, Any]:
    target = level.upper()
    for key in ('levels', 'snapshots'):
        container = analysis.get(key)
        if isinstance(container, dict):
            for name, value in container.items():
                if str(name).upper() == target and isinstance(value, dict):
                    return value
        if isinstance(container, list):
            for value in container:
                if isinstance(value, dict) and str(value.get('level') or value.get('freq') or '').upper() == target:
                    return value
    return analysis if any(key in analysis for key in ('bars', 'bsp', 'bi', 'seg')) else {}


def _bars(payload: dict[str, Any]) -> list[dict[str, Any]]:
    rows = payload.get('bars') or payload.get('raw_bars') or payload.get('rawBars')
    return [dict(item) for item in rows if isinstance(item, dict)] if isinstance(rows, list) else []


def _domain_keys(domain: str) -> list[str]:
    d = domain.lower().strip() or 'bi'
    if d in {'bi', 'bsp'}:
        return ['bsp', 'bsps', 'bi_bsp', 'bi_bsps']
    if d in {'seg', 'seg1'}:
        return ['seg_bsp', 'seg_bsps', 'segment_bsp', 'segment_bsps', 'bsp']
    if d.startswith('seg'):
        n = ''.join(ch for ch in d if ch.isdigit())
        return [f'{d}_bsp', f'{d}_bsps', f'seg{n}_bsp', f'seg{n}_bsps', 'recursive_bsps', 'recursive_bsp', 'segseg_bsp', 'segseg_bsps', 'bsp']
    return [f'{d}_bsp', f'{d}_bsps', d, 'bsp']


def _domain_rows(level_payload: dict[str, Any], domain: str) -> tuple[list[dict[str, Any]], str]:
    source_key = ''
    rows: list[dict[str, Any]] = []
    for key in _domain_keys(domain):
        raw = level_payload.get(key)
        if isinstance(raw, list):
            rows = [dict(item) for item in raw if isinstance(item, dict)]
            source_key = key
            if rows:
                break
    if not rows:
        return [], 'missing'
    d = domain.lower().strip() or 'bi'
    status = 'native'
    if d not in {'bi', 'bsp'} and source_key == 'bsp':
        status = 'fallback_to_bi_bsp'
    if d.startswith('seg') and d not in {'seg', 'seg1'} and source_key in {'recursive_bsps', 'recursive_bsp'}:
        wanted = _to_int(''.join(ch for ch in d if ch.isdigit()))
        rows = [row for row in rows if _to_int(row.get('degree') or row.get('seg_degree') or row.get('level_order')) == wanted]
    return rows, status


def _raw_index(row: dict[str, Any]) -> int | None:
    for key in ('raw_index', 'rawIndex', 'raw_idx', 'bar_index', 'idx', 'index'):
        value = _to_int(row.get(key))
        if value is not None:
            return value
    return None


def _signal_type(row: dict[str, Any]) -> str:
    return str(row.get('type') or row.get('bsp_type') or row.get('bs_type') or row.get('name') or '').strip()


def _signal_side(row: dict[str, Any]) -> str:
    text = (_signal_type(row) + ' ' + str(row.get('side') or row.get('direction') or '')).lower()
    if text.startswith('b') or 'buy' in text or '买' in text:
        return 'buy'
    if text.startswith('s') or 'sell' in text or '卖' in text:
        return 'sell'
    return ''


def _tokens(value: Any) -> set[str]:
    compact = ''.join(ch for ch in str(value or '').upper().replace('BUY', 'B').replace('SELL', 'S') if ch.isalnum())
    if not compact:
        return set()
    result = {compact}
    if compact[0] in {'B', 'S'} and len(compact) > 1:
        result.add(compact[1:])
    else:
        result.add('B' + compact)
        result.add('S' + compact)
    return result


def _type_ok(signal_type: str, wanted: Any, side: str) -> bool:
    if isinstance(wanted, str):
        wanted_list = [part.strip() for part in wanted.replace('，', ',').split(',') if part.strip()]
    elif isinstance(wanted, list):
        wanted_list = wanted
    else:
        wanted_list = []
    wanted_tokens = set().union(*[_tokens(item) for item in wanted_list]) if wanted_list else set()
    if not wanted_tokens:
        return True
    signal_tokens = _tokens(signal_type)
    if side in {'buy', 'sell'}:
        prefix = 'B' if side == 'buy' else 'S'
        signal_tokens |= {prefix + token for token in signal_tokens if not token.startswith(('B', 'S'))}
    return bool(signal_tokens & wanted_tokens)


def collect_signals(analysis: dict[str, Any], conditions: list[dict[str, Any]], levels: list[str]) -> dict[str, list[dict[str, Any]]]:
    domains = sorted({str(c.get('domain') or 'bi').strip().lower() or 'bi' for c in conditions} | {'bi'})
    output: dict[str, list[dict[str, Any]]] = {}
    for level in levels:
        level_payload = _level_payload(analysis, level)
        rows: list[dict[str, Any]] = []
        for domain in domains:
            domain_rows, status = _domain_rows(level_payload, domain)
            for row in domain_rows:
                rows.append({
                    'level': level,
                    'domain': domain,
                    'domain_status': status,
                    'type': _signal_type(row),
                    'side': _signal_side(row),
                    'raw_index': _raw_index(row),
                    'time': row.get('time') or row.get('dt') or row.get('date'),
                    'price': _to_float(row.get('price') or row.get('bsp_price') or row.get('close')),
                    'source': row,
                })
        output[level] = sorted(rows, key=lambda item: _to_int(item.get('raw_index')) or -1)
    return output


def evaluate_group(group: dict[str, Any], signals: dict[str, list[dict[str, Any]]], *, as_of_raw_index: int | None = None) -> dict[str, Any]:
    conds = _conditions(group)
    op = str(group.get('operator') or group.get('op') or 'all').lower()
    if op not in {'all', 'any'}:
        op = 'all'
    now = datetime.now()
    rows = []
    for cond in conds:
        level = str(cond.get('level') or 'DAILY').upper()
        domain = str(cond.get('domain') or 'bi').lower()
        side = str(cond.get('side') or 'buy').lower()
        if side not in {'buy', 'sell', 'any'}:
            side = 'any'
        recent_bars = _to_int(cond.get('recent_bars') or cond.get('recentBars'))
        recent_days = _to_int(cond.get('recent_days') or cond.get('recentDays'))
        matched = []
        max_raw = max([_to_int(s.get('raw_index')) or -1 for s in signals.get(level, [])] or [-1])
        for signal in signals.get(level, []):
            raw = _to_int(signal.get('raw_index'))
            if signal.get('domain') != domain:
                continue
            if side != 'any' and signal.get('side') and signal.get('side') != side:
                continue
            if not _type_ok(str(signal.get('type') or ''), cond.get('types') or cond.get('type') or cond.get('bsp_types'), side):
                continue
            if as_of_raw_index is not None:
                if raw is None or raw > as_of_raw_index:
                    continue
                if recent_bars is not None and as_of_raw_index - raw > recent_bars:
                    continue
            elif recent_bars is not None and raw is not None and max_raw - raw > recent_bars:
                continue
            if recent_days is not None:
                dt = _parse_dt(signal.get('time'))
                if dt is None or now - dt > timedelta(days=recent_days):
                    continue
            matched.append(signal)
        rows.append({'condition': cond, 'matched': bool(matched), 'matched_count': len(matched), 'latest': matched[-1] if matched else None, 'matches': matched[-8:]})
    ok = bool(rows) and (any(row['matched'] for row in rows) if op == 'any' else all(row['matched'] for row in rows))
    latest = [row['latest'] for row in rows if row.get('latest')]
    latest.sort(key=lambda item: _to_int(item.get('raw_index')) or -1)
    return {'ok': ok, 'operator': op, 'condition_count': len(rows), 'matched_condition_count': sum(1 for row in rows if row['matched']), 'conditions': rows, 'latest_signal': latest[-1] if latest else None}


def analyze_single(payload: dict[str, Any]) -> dict[str, Any]:
    group = _obj(payload.get('condition_group') or {'operator': payload.get('operator') or 'all', 'conditions': payload.get('conditions') or []})
    conds = _conditions(group)
    levels = _payload_levels(payload, conds)
    analysis = _analysis_for(payload, conds)
    signals = collect_signals(analysis, conds, levels)
    return {
        'ok': bool(analysis.get('ok', True)),
        'mode': 'single_symbol_condition_analysis',
        'symbol': _normalize_code(payload.get('symbol') or payload.get('code')),
        'market': str(payload.get('market') or infer_market(_normalize_code(payload.get('symbol') or payload.get('code')))).upper(),
        'levels': levels,
        'condition_group': group,
        'match': evaluate_group(group, signals),
        'signals': signals,
        'analysis': analysis if bool(payload.get('include_analysis', False)) else None,
        'meta': {'chan_calculation_authority': 'python/chan.py via backend only', 'dart_chan_calculation': False},
    }


@dataclass
class Trade:
    symbol: str
    market: str
    rule_name: str
    entry_raw_index: int
    entry_time: str
    entry_price: float
    exit_raw_index: int
    exit_time: str
    exit_price: float
    exit_reason: str
    bars_held: int

    def to_dict(self) -> dict[str, Any]:
        ret = (self.exit_price - self.entry_price) / self.entry_price * 100.0 if self.entry_price else 0.0
        return {**self.__dict__, 'return_pct': ret, 'jump': {'symbol': self.symbol, 'market': self.market, 'entry_raw_index': self.entry_raw_index, 'exit_raw_index': self.exit_raw_index}}


def _bar_raw(bar: dict[str, Any], fallback: int) -> int:
    return _to_int(bar.get('raw_index') or bar.get('rawIndex') or bar.get('index')) or fallback


def _bar_price(bar: dict[str, Any], key: str) -> float | None:
    return _to_float(bar.get(key)) or _to_float(bar.get('close'))


def _summary(trades: list[Trade], rule_name: str) -> dict[str, Any]:
    values = [t.to_dict()['return_pct'] for t in trades]
    wins = [v for v in values if v > 0]
    losses = [v for v in values if v < 0]
    win_rate = len(wins) / len(values) if values else 0.0
    avg_win = sum(wins) / len(wins) if wins else 0.0
    avg_loss = sum(losses) / len(losses) if losses else 0.0
    pl = avg_win / abs(avg_loss) if avg_loss < 0 else (avg_win if avg_win > 0 else 0.0)
    avg_ret = sum(values) / len(values) if values else 0.0
    score = win_rate * 100.0 + min(pl, 10.0) * 6.0 + avg_ret * 1.2
    return {'rule_name': rule_name, 'trade_count': len(trades), 'win_rate': win_rate, 'profit_loss_ratio': pl, 'avg_return_pct': avg_ret, 'model_score': score, 'win_count': len(wins), 'loss_count': len(losses)}


def _run_rule(payload: dict[str, Any], analysis: dict[str, Any], signals: dict[str, list[dict[str, Any]]], rule: dict[str, Any], levels: list[str]) -> dict[str, Any]:
    code = _normalize_code(payload.get('symbol') or payload.get('code'))
    market = str(payload.get('market') or infer_market(code)).upper()
    rule_name = str(rule.get('name') or rule.get('rule_name') or 'rule')
    main_level = str(rule.get('main_level') or payload.get('main_level') or levels[0]).upper()
    bars = _bars(_level_payload(analysis, main_level))
    entry = _obj(rule.get('entry') or payload.get('condition_group') or {'conditions': payload.get('conditions') or []})
    exit_rule = _obj(rule.get('exit') or {})
    horizon = int(rule.get('max_holding_bars') or exit_rule.get('horizon') or payload.get('horizon') or 5)
    take_profit = _to_float(rule.get('take_profit_pct') or exit_rule.get('take_profit_pct'))
    stop_loss = _to_float(rule.get('stop_loss_pct') or exit_rule.get('stop_loss_pct'))
    trades: list[Trade] = []
    open_pos: dict[str, Any] | None = None
    for i, bar in enumerate(bars):
        raw = _bar_raw(bar, i)
        close = _bar_price(bar, 'close')
        if close is None:
            continue
        if open_pos is not None:
            held = i - int(open_pos['entry_i'])
            reason = ''
            exit_price = close
            if take_profit is not None and ((_bar_price(bar, 'high') or close) - float(open_pos['entry_price'])) / float(open_pos['entry_price']) * 100 >= take_profit:
                reason = 'take_profit_pct'
                exit_price = _bar_price(bar, 'high') or close
            if not reason and stop_loss is not None and ((_bar_price(bar, 'low') or close) - float(open_pos['entry_price'])) / float(open_pos['entry_price']) * 100 <= -abs(stop_loss):
                reason = 'stop_loss_pct'
                exit_price = _bar_price(bar, 'low') or close
            if not reason and exit_rule.get('conditions') and evaluate_group(exit_rule, signals, as_of_raw_index=raw)['ok']:
                reason = 'exit_condition_group'
            if not reason and held >= horizon:
                reason = 'fixed_horizon'
            if reason:
                trades.append(Trade(code, market, rule_name, int(open_pos['entry_raw_index']), str(open_pos['entry_time']), float(open_pos['entry_price']), raw, str(bar.get('dt') or bar.get('time') or bar.get('date') or ''), float(exit_price), reason, held))
                open_pos = None
                continue
        if open_pos is None and i + 1 < len(bars) and evaluate_group(entry, signals, as_of_raw_index=raw)['ok']:
            next_bar = bars[i + 1]
            entry_price = _bar_price(next_bar, 'open') or _bar_price(next_bar, 'close')
            if entry_price is not None:
                open_pos = {'entry_i': i + 1, 'entry_raw_index': _bar_raw(next_bar, i + 1), 'entry_time': next_bar.get('dt') or next_bar.get('time') or next_bar.get('date') or '', 'entry_price': entry_price}
    return {'rule_name': rule_name, 'main_level': main_level, 'summary': _summary(trades, rule_name), 'trades': [t.to_dict() for t in trades], 'entry': entry, 'exit': exit_rule, 'lookahead_policy': 'entry uses next bar open after signal raw_index'}


def backtest_single(payload: dict[str, Any]) -> dict[str, Any]:
    rules_raw = payload.get('rules')
    rules = [dict(item) for item in rules_raw if isinstance(item, dict)] if isinstance(rules_raw, list) and rules_raw else [{'name': payload.get('rule_name') or 'condition_rule_1', 'entry': payload.get('condition_group') or {'conditions': payload.get('conditions') or []}, 'exit': payload.get('exit') or {'horizon': payload.get('horizon') or 5}}]
    all_conditions: list[dict[str, Any]] = []
    for rule in rules:
        all_conditions.extend(_conditions(rule.get('entry')))
        all_conditions.extend(_conditions(rule.get('exit')))
    levels = _payload_levels(payload, all_conditions)
    analysis = _analysis_for(payload, all_conditions)
    signals = collect_signals(analysis, all_conditions, levels)
    results = [_run_rule(payload, analysis, signals, rule, levels) for rule in rules]
    results.sort(key=lambda item: float(item['summary'].get('model_score') or 0), reverse=True)
    return {'ok': bool(analysis.get('ok', True)), 'mode': 'single_symbol_multi_rule_backtest', 'levels': levels, 'rules': results, 'ranking': [r['summary'] for r in results], 'signals': signals, 'meta': {'same_bar_lookahead': False, 'entry_fill_policy': 'next_bar_open', 'sort_key': 'model_score desc'}}


def _payload_symbols(value: Any) -> list[Any] | None:
    if isinstance(value, str):
        rows = [part.strip() for part in value.replace('，', ',').split(',') if part.strip()]
        return rows or None
    return value if isinstance(value, list) else None


def scan_market(payload: dict[str, Any]) -> dict[str, Any]:
    limit = max(1, min(int(payload.get('limit') or 300), 5000))
    group = _obj(payload.get('condition_group') or {'operator': 'all', 'conditions': payload.get('conditions') or []})
    if not _conditions(group):
        group = {'operator': 'all', 'conditions': [{'id': 'default_recent_buy', 'level': payload.get('main_level') or 'DAILY', 'domain': 'bi', 'side': payload.get('side') or 'buy', 'types': payload.get('types') or payload.get('bsp_types') or ['1', '1p', '2', '2s', '3a', '3b'], 'recent_days': payload.get('recent_days') or 3}]}
    rows = get_tradable_stocks(symbols=_payload_symbols(payload.get('symbols')), limit=limit)
    results: list[dict[str, Any]] = []
    failures: list[dict[str, Any]] = []
    for row in rows:
        code = str(row.get('code') or '')
        if not code:
            continue
        request = dict(payload, symbol=code, market=row.get('market') or infer_market(code), condition_group=group)
        try:
            analyzed = analyze_single(request)
            match = _obj(analyzed.get('match'))
            if match.get('ok'):
                latest = _obj(match.get('latest_signal'))
                results.append({'rank': len(results) + 1, 'code': code, 'market': str(row.get('market') or infer_market(code)).upper(), 'name': str(row.get('name') or code), 'price': row.get('price'), 'change': row.get('change'), 'matched_condition_count': match.get('matched_condition_count'), 'latest_level': latest.get('level'), 'latest_domain': latest.get('domain'), 'latest_type': latest.get('type'), 'latest_side': latest.get('side'), 'latest_time': latest.get('time'), 'latest_raw_index': latest.get('raw_index'), 'domain_status': latest.get('domain_status'), 'jump': {'symbol': code, 'market': str(row.get('market') or infer_market(code)).upper(), 'level': latest.get('level'), 'raw_index': latest.get('raw_index')}})
        except Exception as exc:
            failures.append({'code': code, 'error': str(exc)[:180]})
    return {'ok': True, 'mode': 'market_condition_scan', 'total': len(rows), 'found_count': len(results), 'fail_count': len(failures), 'results': results, 'failures': failures[:50], 'condition_group': group, 'catalog': condition_catalog(), 'android_policy': 'When easy-tdx is unavailable, pass explicit symbols. The condition engine itself is backend-only and does not use Flutter/Dart Chan calculation.'}
