from __future__ import annotations

from typing import Any

from .a_multilevel_native_timed_engine import analyze_multi_native_timed


def analyze_multi(
    *,
    symbol: str,
    market: str | None,
    levels: list[str] | str | None,
    adjust: str = 'QFQ',
    mode: str = 'once',
    main_level: str | None = None,
    clock_level: str | None = None,
    start: str | None = None,
    end: str | None = None,
    count: int = 50000,
    config: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Timed multi-level App adapter entrypoint.

    This keeps native CChan(lv_list) as the calculation source and only adds
    timing metadata through `a_multilevel_native_timed_engine`.
    """
    return analyze_multi_native_timed(
        symbol=symbol,
        market=market,
        levels=levels,
        adjust=adjust,
        mode=mode,
        main_level=main_level,
        clock_level=clock_level,
        start=start,
        end=end,
        count=count,
        config=config,
    )
