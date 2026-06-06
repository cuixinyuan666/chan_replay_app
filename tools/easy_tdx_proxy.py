"""EasyTDX HTTP proxy for the Flutter Chan Replay App.

The Flutter Android app cannot import a Python package directly. Run this small
HTTP service on your PC/VPS, then point the app to http://<host>:8765.

Install:
    pip install fastapi uvicorn easy-tdx

Run:
    python tools/easy_tdx_proxy.py --host 0.0.0.0 --port 8765
"""

from __future__ import annotations

import argparse
from datetime import date, datetime
from enum import Enum
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

try:
    from easy_tdx import Tdx
except Exception as exc:  # pragma: no cover - runtime dependency check
    Tdx = None  # type: ignore[assignment]
    EASY_TDX_IMPORT_ERROR = exc
else:
    EASY_TDX_IMPORT_ERROR = None


app = FastAPI(title="Chan Replay EasyTDX Proxy", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Market(str, Enum):
    SH = "SH"
    SZ = "SZ"


class Period(str, Enum):
    MIN1 = "MIN1"
    MIN5 = "MIN5"
    MIN15 = "MIN15"
    MIN30 = "MIN30"
    MIN60 = "MIN60"
    DAILY = "DAILY"
    WEEKLY = "WEEKLY"
    MONTHLY = "MONTHLY"


class Adjust(str, Enum):
    NONE = "NONE"
    QFQ = "QFQ"
    HFQ = "HFQ"


def _ensure_easy_tdx() -> type[Any]:
    if Tdx is None:
        raise HTTPException(
            status_code=500,
            detail=f"easy-tdx is not available: {EASY_TDX_IMPORT_ERROR}",
        )
    return Tdx


def _normalize_row(row: Any) -> dict[str, Any]:
    if hasattr(row, "to_dict"):
        row = row.to_dict()
    if not isinstance(row, dict):
        row = dict(row)

    raw_time = (
        row.get("datetime")
        or row.get("time")
        or row.get("date")
        or row.get("trade_date")
    )
    if isinstance(raw_time, (datetime, date)):
        time_text = raw_time.isoformat()
    else:
        time_text = str(raw_time) if raw_time is not None else ""

    return {
        "time": time_text,
        "open": _float_value(row.get("open")),
        "high": _float_value(row.get("high")),
        "low": _float_value(row.get("low")),
        "close": _float_value(row.get("close")),
        "volume": _float_value(row.get("volume") or row.get("vol"), 0.0),
    }


def _float_value(value: Any, default: float | None = None) -> float | None:
    if value is None:
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _market_value(market: Market) -> str:
    # easy-tdx accepts SH/SZ in its high-level Tdx wrapper.
    return market.value


def _period_value(period: Period) -> str:
    # Keep a conservative string mapping. If your installed easy-tdx version uses
    # another enum, edit only this function instead of the Flutter app.
    return period.value


def _adjust_value(adjust: Adjust) -> str | None:
    if adjust == Adjust.NONE:
        return None
    return adjust.value


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": Tdx is not None,
        "provider": "easy-tdx",
        "error": str(EASY_TDX_IMPORT_ERROR) if EASY_TDX_IMPORT_ERROR else None,
    }


@app.get("/kline")
def kline(
    market: Market = Query(..., description="SH or SZ"),
    code: str = Query(..., min_length=6, max_length=6, description="Stock code, e.g. 000001"),
    period: Period = Query(Period.DAILY),
    adjust: Adjust = Query(Adjust.QFQ),
    count: int = Query(500, ge=1, le=5000),
) -> dict[str, Any]:
    tdx_cls = _ensure_easy_tdx()
    tdx = tdx_cls()
    try:
        rows = tdx.kline(
            symbol=code,
            market=_market_value(market),
            period=_period_value(period),
            adjust=_adjust_value(adjust),
            count=count,
        )
    except TypeError:
        # Compatibility fallback for easy-tdx variants that use positional args
        # or omit the adjust argument.
        try:
            rows = tdx.kline(_market_value(market), code, _period_value(period), count)
        except Exception as exc:  # pragma: no cover - external service
            raise HTTPException(status_code=502, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover - external service
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    if rows is None:
        rows = []
    if hasattr(rows, "to_dict"):
        rows = rows.to_dict("records")

    bars = [_normalize_row(row) for row in rows]
    bars = [
        bar
        for bar in bars
        if bar["time"] and bar["open"] is not None and bar["high"] is not None and bar["low"] is not None and bar["close"] is not None
    ]
    return {
        "provider": "easy-tdx",
        "market": market.value,
        "code": code,
        "period": period.value,
        "adjust": adjust.value,
        "count": len(bars),
        "data": bars,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()

    import uvicorn

    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
