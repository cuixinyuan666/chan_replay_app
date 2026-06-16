from __future__ import annotations

import json
from typing import Any

from fastapi import Body
from fastapi.responses import StreamingResponse

from .a_bsp_scanner import scan_bsp_events
from .a_xg_condition_engine import analyze_single, backtest_single, condition_catalog, scan_market
from .a_xg_s8_engine import scan_s8_market
from .main import _scanner_args, app


@app.get('/api/xg/catalog')
def xg_catalog() -> dict[str, Any]:
    return condition_catalog()


@app.post('/api/xg/single')
def xg_single(payload: dict[str, Any] = Body(...)) -> dict[str, Any]:
    return analyze_single(payload)


@app.post('/api/xg/backtest')
def xg_backtest(payload: dict[str, Any] = Body(...)) -> dict[str, Any]:
    return backtest_single(payload)


@app.post('/api/xg/scan')
def xg_scan(payload: dict[str, Any] = Body(...)) -> dict[str, Any]:
    return scan_market(payload)


@app.post('/api/xg/s8/scan')
def xg_s8_scan(payload: dict[str, Any] = Body(...)) -> dict[str, Any]:
    return scan_s8_market(payload)


@app.post('/api/scanner/bsp/scan_stream')
def scanner_bsp_scan_stream_post(payload: dict[str, Any] | None = Body(None)) -> StreamingResponse:
    args = _scanner_args(payload)

    def _iter():
        for event in scan_bsp_events(**args):
            yield json.dumps(event, ensure_ascii=False) + '\n'

    return StreamingResponse(_iter(), media_type='application/x-ndjson')
