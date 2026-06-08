from __future__ import annotations

import json
from typing import Any

from easy_tdx_runtime import infer_market, load_kline_json, normalize_symbol


def analyze_json(payload_json: str) -> str:
    payload = json.loads(payload_json or '{}')
    code = normalize_symbol(str(payload.get('symbol') or payload.get('code') or '000001'))
    market = str(payload.get('market') or infer_market(code)).upper()
    freq = str(payload.get('freq') or payload.get('period') or 'DAILY').upper()
    adjust = str(payload.get('adjust') or 'QFQ').upper()
    mode = str(payload.get('mode') or 'once').lower()

    kline_payload = dict(payload)
    kline_payload['symbol'] = code
    kline_payload['market'] = market
    kline_payload['freq'] = freq
    kline_payload['adjust'] = adjust
    bars_result = json.loads(load_kline_json(json.dumps(kline_payload, ensure_ascii=False)))
    bars = bars_result.get('bars') or []
    if not bars_result.get('ok', False):
        return json.dumps({
            'ok': False,
            'error': bars_result.get('error') or 'Android easy-tdx 获取K线失败',
            'bars': [],
            'fx': [],
            'bi': [],
            'seg': [],
            'zs': [],
            'bsp': [],
            'frames': [],
            'meta': {
                'engine': 'chan.py',
                'platform': 'android-chaquopy',
                'mode': mode,
            },
        }, ensure_ascii=False)

    try:
        # The actual chan.py runtime will be wired here after the chan.py package is bundled
        # into the APK and its imports are verified under Chaquopy.
        import Chan  # noqa: F401
        warning = 'chan.py imported, but Android exporter is not wired yet'
    except Exception as exc:
        warning = f'Android APK 尚未完成 chan.py 运行时打包或导出接线: {exc}'

    return json.dumps({
        'ok': True,
        'bars': bars,
        'fx': [],
        'bi': [],
        'seg': [],
        'zs': [],
        'bsp': [],
        'frames': [],
        'meta': {
            'engine': 'chan.py',
            'platform': 'android-chaquopy',
            'symbol': f'{code}.{market}',
            'name': code,
            'freq': freq,
            'adjust': adjust,
            'mode': mode,
            'warning': warning,
        },
    }, ensure_ascii=False)
