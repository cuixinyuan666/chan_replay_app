#!/usr/bin/env python3
"""Validate the standalone chip distribution page wiring.

This validator is intentionally static: it verifies that the new page is a root-level
route, that the chip calculation remains UI/market-data only, and that Dart does
not gain FX/BI/SEG/ZS/BSP calculation authority.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.exists():
        raise AssertionError(f"missing file: {rel}")
    return path.read_text(encoding="utf-8")


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def reject(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"forbidden {label}: {needle}")


def main() -> None:
    root_page = read("lib/ui/pages/root_page.dart")
    chip_page = read("lib/ui/pages/chip_distribution_page.dart")
    engine = read("lib/core/analysis/chip_distribution.dart")
    test_file = read("test/chip_distribution_test.dart")

    require(root_page, "import 'chip_distribution_page.dart';", "root route import")
    require(root_page, "static const int _chipDistributionIndex", "root route index")
    require(root_page, "const _RouteBuilder(child: ChipDistributionPage())", "lazy route child")
    require(root_page, "tooltip: '筹码分布'", "route tooltip")
    require(root_page, "Icons.stacked_bar_chart", "route icon")

    require(chip_page, "class ChipDistributionPage", "page class")
    require(chip_page, "ChipDistributionEngine", "page engine usage")
    require(chip_page, "当前页面为独立筹码分布研究页", "page independence tooltip")
    require(chip_page, "不提供交易建议", "non-recommendation policy")

    require(engine, "class ChipDistributionEngine", "engine class")
    require(engine, "final window = bars.sublist(start, safeTarget + 1);", "no future-data window")
    require(engine, "priceVolume", "exact price-volume support")
    require(engine, "_foldOhlcvTriangular", "OHLCV fallback")
    require(engine, "不依赖任何 Widget", "UI decoupling comment")

    forbidden_imports = [
        "models/fx.dart",
        "models/bi.dart",
        "models/seg.dart",
        "models/zs.dart",
        "models/bsp.dart",
        "chan_snapshot.dart",
        "multi_level_chan_snapshot.dart",
        "python/chan.py",
    ]
    for needle in forbidden_imports:
        reject(engine, needle, "chip engine Chan-structure dependency")

    require(test_file, "does not consume bars after target index", "future-data regression test")
    require(test_file, "exact price-volume bins are preferred", "exact-bin regression test")

    print(json.dumps({
        "ok": True,
        "route": "筹码分布",
        "branch_task": "hichanchoumafenbu",
        "checks": {
            "root_route_added": True,
            "standalone_page_added": True,
            "chip_engine_added": True,
            "no_future_window_guard": True,
            "exact_price_volume_priority": True,
            "ohlcv_fallback": True,
            "no_dart_chan_structure_authority": True,
            "tests_added": True,
        },
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
