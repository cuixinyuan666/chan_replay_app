#!/usr/bin/env python3
"""Validate easy-tdx / indicator fields in backend JSON.

This validator focuses on display data contracts and does not import or modify
Vespa chan.py. It is safe to run against saved /api/chan/analyze responses.

Usage:
  python tools/validate_easy_tdx_indicator_contract.py path/to/analysis.json
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

BAR_NUMERIC_FIELDS = ("open", "high", "low", "close")
OPTIONAL_BAR_NUMERIC_FIELDS = ("volume", "vol", "amount", "turnover")
INDICATOR_SERIES_KEYS = ("vol", "amount", "turnover", "boll", "macd")


@dataclass(frozen=True)
class Problem:
    path: str
    message: str


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def check_bars(root: dict[str, Any]) -> list[Problem]:
    problems: list[Problem] = []
    bars = root.get("bars")
    if not isinstance(bars, list):
        return [Problem("bars", "must be a list")]

    for i, bar in enumerate(bars):
        p = f"bars[{i}]"
        if not isinstance(bar, dict):
            problems.append(Problem(p, "must be an object"))
            continue
        for field in ("time", *BAR_NUMERIC_FIELDS):
            if field not in bar:
                problems.append(Problem(f"{p}.{field}", "missing required bar field"))
        for field in BAR_NUMERIC_FIELDS:
            value = bar.get(field)
            if value is not None and not is_number(value):
                problems.append(Problem(f"{p}.{field}", "must be numeric"))
        high, low = bar.get("high"), bar.get("low")
        open_, close = bar.get("open"), bar.get("close")
        if all(is_number(x) for x in (high, low, open_, close)):
            if high < max(open_, close, low):
                problems.append(Problem(p, "high must be >= max(open, close, low)"))
            if low > min(open_, close, high):
                problems.append(Problem(p, "low must be <= min(open, close, high)"))
        for field in OPTIONAL_BAR_NUMERIC_FIELDS:
            if field in bar and bar[field] is not None and not is_number(bar[field]):
                problems.append(Problem(f"{p}.{field}", "must be numeric or null"))
    return problems


def check_indicator_point(point: Any, path: str) -> list[Problem]:
    problems: list[Problem] = []
    if not isinstance(point, dict):
        return [Problem(path, "indicator point must be an object")]
    raw_index = point.get("raw_index", point.get("rawIndex"))
    if raw_index is not None and not isinstance(raw_index, int):
        problems.append(Problem(f"{path}.raw_index", "must be int when present"))
    if "value" in point and point["value"] is not None and not is_number(point["value"]):
        problems.append(Problem(f"{path}.value", "must be numeric or null"))
    return problems


def check_indicators(root: dict[str, Any]) -> list[Problem]:
    problems: list[Problem] = []
    indicators = root.get("indicators", {})
    if indicators in ({}, None):
        return problems
    if not isinstance(indicators, dict):
        return [Problem("indicators", "must be an object when present")]

    for key in INDICATOR_SERIES_KEYS:
        if key not in indicators:
            continue
        value = indicators[key]
        if key == "macd":
            problems.extend(check_macd(value))
            continue
        if key == "boll":
            problems.extend(check_boll(value))
            continue
        if not isinstance(value, list):
            problems.append(Problem(f"indicators.{key}", "must be a list"))
            continue
        for i, point in enumerate(value):
            problems.extend(check_indicator_point(point, f"indicators.{key}[{i}]"))
    return problems


def check_macd(value: Any) -> list[Problem]:
    problems: list[Problem] = []
    if not isinstance(value, list):
        return [Problem("indicators.macd", "must be a list")]
    for i, point in enumerate(value):
        p = f"indicators.macd[{i}]"
        if not isinstance(point, dict):
            problems.append(Problem(p, "must be an object"))
            continue
        for field in ("dif", "dea", "hist"):
            if field in point and point[field] is not None and not is_number(point[field]):
                problems.append(Problem(f"{p}.{field}", "must be numeric or null"))
    return problems


def check_boll(value: Any) -> list[Problem]:
    problems: list[Problem] = []
    if not isinstance(value, list):
        return [Problem("indicators.boll", "must be a list")]
    for i, point in enumerate(value):
        p = f"indicators.boll[{i}]"
        if not isinstance(point, dict):
            problems.append(Problem(p, "must be an object"))
            continue
        for field in ("upper", "mid", "lower"):
            if field in point and point[field] is not None and not is_number(point[field]):
                problems.append(Problem(f"{p}.{field}", "must be numeric or null"))
    return problems


def check_meta(root: dict[str, Any]) -> list[Problem]:
    meta = root.get("meta", {})
    if meta in ({}, None):
        return []
    if not isinstance(meta, dict):
        return [Problem("meta", "must be an object when present")]
    problems: list[Problem] = []
    warnings = meta.get("warnings")
    if warnings is not None and not isinstance(warnings, list):
        problems.append(Problem("meta.warnings", "must be a list when present"))
    warning = meta.get("warning")
    if warning is not None and not isinstance(warning, str):
        problems.append(Problem("meta.warning", "must be a string when present"))
    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("json_file", type=Path)
    args = parser.parse_args()
    root = json.loads(args.json_file.read_text(encoding="utf-8"))
    if not isinstance(root, dict):
        print("FAIL: root JSON must be an object", file=sys.stderr)
        return 1

    problems: list[Problem] = []
    problems.extend(check_bars(root))
    problems.extend(check_indicators(root))
    problems.extend(check_meta(root))

    if problems:
        print("FAIL: easy-tdx / indicator display contract mismatch")
        for problem in problems:
            print(f"- {problem.path}: {problem.message}")
        return 1
    print("PASS: easy-tdx / indicator display contract is compatible")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
