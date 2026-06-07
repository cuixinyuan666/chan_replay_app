#!/usr/bin/env python3
"""Diff normalized chan.py and Dart engine outputs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--chanpy", default="build/chanpy_compare/chanpy.json")
    parser.add_argument("--dart", default="build/chanpy_compare/dart.json")
    parser.add_argument("--out-json", default="build/chanpy_compare/diff_report.json")
    parser.add_argument("--out-md", default="build/chanpy_compare/diff_report.md")
    return parser.parse_args()


def load(path: str) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def pick_key(module: str, item: dict[str, Any]) -> tuple[Any, ...]:
    if module == "fx":
        return (item.get("raw_index"), item.get("type"), _round(item.get("price")))
    if module == "bi":
        return (
            item.get("start_raw_index"),
            item.get("end_raw_index"),
            item.get("direction"),
            _round(item.get("start_price")),
            _round(item.get("end_price")),
        )
    if module == "seg":
        return (item.get("start_bi_index"), item.get("end_bi_index"), item.get("direction"), item.get("is_sure"))
    if module == "zs":
        return (
            item.get("start_bi_index"),
            item.get("end_bi_index"),
            _round(item.get("zg")),
            _round(item.get("zd")),
            _round(item.get("gg")),
            _round(item.get("dd")),
        )
    return tuple(sorted(item.items()))


def _round(value: Any) -> Any:
    try:
        return round(float(value), 6)
    except (TypeError, ValueError):
        return value


def diff_module(module: str, left: list[dict[str, Any]], right: list[dict[str, Any]]) -> dict[str, Any]:
    left_keys = [pick_key(module, item) for item in left]
    right_keys = [pick_key(module, item) for item in right]
    max_len = max(len(left_keys), len(right_keys))
    first_mismatch = None
    mismatch_count = 0
    for i in range(max_len):
        lval = left_keys[i] if i < len(left_keys) else None
        rval = right_keys[i] if i < len(right_keys) else None
        if lval != rval:
            mismatch_count += 1
            if first_mismatch is None:
                first_mismatch = {
                    "index": i,
                    "chanpy_key": lval,
                    "dart_key": rval,
                    "chanpy_item": left[i] if i < len(left) else None,
                    "dart_item": right[i] if i < len(right) else None,
                }
    return {
        "chanpy_count": len(left),
        "dart_count": len(right),
        "count_delta": len(right) - len(left),
        "mismatch_count": mismatch_count,
        "first_mismatch": first_mismatch,
    }


def make_markdown(report: dict[str, Any]) -> str:
    lines = ["# chanpy_compare diff report", ""]
    lines.append(f"CSV: `{report.get('csv')}`")
    lines.append("")
    lines.append("| module | chan.py | Dart | delta | mismatches |")
    lines.append("|---|---:|---:|---:|---:|")
    for module in ["fx", "bi", "seg", "zs"]:
        row = report["modules"][module]
        lines.append(
            f"| {module.upper()} | {row['chanpy_count']} | {row['dart_count']} | {row['count_delta']} | {row['mismatch_count']} |"
        )
    lines.append("")
    for module in ["fx", "bi", "seg", "zs"]:
        row = report["modules"][module]
        lines.append(f"## {module.upper()}")
        if row["first_mismatch"] is None:
            lines.append("No mismatch found in normalized keys.")
        else:
            lines.append("```json")
            lines.append(json.dumps(row["first_mismatch"], ensure_ascii=False, indent=2))
            lines.append("```")
        lines.append("")
    lines.append("## 修复顺序")
    lines.append("")
    lines.append("先修 BI，再修 SEG，再修 ZS。FX 只在确认包含关系和分型生命周期确实不一致时才改。")
    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    chanpy = load(args.chanpy)
    dart = load(args.dart)
    report = {
        "csv": dart.get("csv") or chanpy.get("csv"),
        "chanpy_engine": chanpy.get("engine"),
        "dart_engine": dart.get("engine"),
        "modules": {},
    }
    for module in ["fx", "bi", "seg", "zs"]:
        report["modules"][module] = diff_module(module, chanpy.get(module, []), dart.get(module, []))

    out_json = Path(args.out_json)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    out_md = Path(args.out_md)
    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text(make_markdown(report), encoding="utf-8")
    print(f"Diff report written: {out_json} and {out_md}")


if __name__ == "__main__":
    main()
