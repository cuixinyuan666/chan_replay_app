#!/usr/bin/env python3
"""Validate chan.py JSON exported to Flutter.

This script checks the fields that origin_vespa_tdx expects from the Python
single-source calculation route. It does not import or modify Vespa chan.py.

Usage:
  python tools/validate_chanpy_output_contract.py path/to/analysis.json

The JSON may be a direct backend response or a saved object containing:
  bars / merged_bars / fx / bi / seg / zs / bsp / frames / meta
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

TOP_LEVEL_LISTS = ("bars", "merged_bars", "fx", "bi", "seg", "zs", "bsp")
REQUIRED_BSP_FIELDS = ("index", "raw_index", "time", "price", "is_buy", "types", "bi_idx", "klu_idx", "is_sure")
REQUIRED_MERGED_FIELDS = ("start_raw_index", "end_raw_index", "raw_index", "open", "high", "low", "close")
BSP_TYPES = {"1", "1p", "2", "2s", "3a", "3b"}


@dataclass(frozen=True)
class Problem:
    path: str
    message: str


def get_any(d: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in d:
            return d[key]
    return None


def normalize_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def check_top_level(root: dict[str, Any]) -> list[Problem]:
    problems: list[Problem] = []
    for key in TOP_LEVEL_LISTS:
        if key not in root:
            problems.append(Problem(key, "missing top-level list"))
        elif not isinstance(root[key], list):
            problems.append(Problem(key, "must be a list"))
    if "frames" in root and not isinstance(root["frames"], list):
        problems.append(Problem("frames", "must be a list when present"))
    if "meta" in root and not isinstance(root["meta"], dict):
        problems.append(Problem("meta", "must be a dict when present"))
    return problems


def check_bsp(root: dict[str, Any], prefix: str = "bsp") -> list[Problem]:
    problems: list[Problem] = []
    for i, item in enumerate(normalize_list(root.get("bsp"))):
        p = f"{prefix}[{i}]"
        if not isinstance(item, dict):
            problems.append(Problem(p, "must be an object"))
            continue
        for key in REQUIRED_BSP_FIELDS:
            if key not in item:
                problems.append(Problem(f"{p}.{key}", "missing required BSP field"))
        types = item.get("types", item.get("type"))
        if isinstance(types, str):
            type_values = [x.strip() for x in types.split(",") if x.strip()]
        elif isinstance(types, list):
            type_values = [str(x).strip() for x in types if str(x).strip()]
        else:
            type_values = []
        if not type_values:
            problems.append(Problem(f"{p}.types", "must contain at least one BSP type"))
        unknown = [x for x in type_values if x not in BSP_TYPES]
        if unknown:
            problems.append(Problem(f"{p}.types", f"unknown BSP type(s): {unknown}"))
        is_sure = item.get("is_sure")
        if is_sure is not None and not isinstance(is_sure, bool):
            problems.append(Problem(f"{p}.is_sure", "must be boolean when present"))
    return problems


def check_merged_bars(root: dict[str, Any], prefix: str = "merged_bars") -> list[Problem]:
    problems: list[Problem] = []
    last_end = -1
    for i, item in enumerate(normalize_list(root.get("merged_bars"))):
        p = f"{prefix}[{i}]"
        if not isinstance(item, dict):
            problems.append(Problem(p, "must be an object"))
            continue
        for key in REQUIRED_MERGED_FIELDS:
            if key not in item:
                problems.append(Problem(f"{p}.{key}", "missing required merged bar field"))
        start = get_any(item, "start_raw_index", "startRawIndex", "begin_raw_index")
        end = get_any(item, "end_raw_index", "endRawIndex")
        high = item.get("high")
        low = item.get("low")
        open_ = item.get("open")
        close = item.get("close")
        if isinstance(start, int) and isinstance(end, int):
            if start > end:
                problems.append(Problem(p, "start_raw_index must be <= end_raw_index"))
            if end < last_end:
                problems.append(Problem(p, "merged bars should be ordered by end_raw_index"))
            last_end = end
        for name, value in (("high", high), ("low", low), ("open", open_), ("close", close)):
            if value is not None and not isinstance(value, (int, float)):
                problems.append(Problem(f"{p}.{name}", "must be numeric"))
        if isinstance(high, (int, float)) and isinstance(low, (int, float)) and high < low:
            problems.append(Problem(p, "high must be >= low"))
    return problems


def check_frames(root: dict[str, Any]) -> list[Problem]:
    problems: list[Problem] = []
    frames = root.get("frames", [])
    if not isinstance(frames, list):
        return problems
    for i, frame in enumerate(frames):
        if not isinstance(frame, dict):
            problems.append(Problem(f"frames[{i}]", "must be an object"))
            continue
        problems.extend(check_bsp(frame, prefix=f"frames[{i}].bsp"))
        problems.extend(check_merged_bars(frame, prefix=f"frames[{i}].merged_bars"))
    return problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("json_file", type=Path)
    args = parser.parse_args()
    root = json.loads(args.json_file.read_text(encoding="utf-8"))
    if not isinstance(root, dict):
        print("FAIL: root JSON must be an object", file=sys.stderr)
        return 1

    problems = []
    problems.extend(check_top_level(root))
    problems.extend(check_bsp(root))
    problems.extend(check_merged_bars(root))
    problems.extend(check_frames(root))

    if problems:
        print("FAIL: chan.py output contract mismatch")
        for problem in problems:
            print(f"- {problem.path}: {problem.message}")
        return 1
    print("PASS: chan.py output contract is compatible with Flutter V2 display route")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
