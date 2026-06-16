#!/usr/bin/env python3
"""Validate online-only chip distribution integration."""

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
    adapter = read("lib/core/analysis/chip_online_replay_adapter.dart")
    test_file = read("test/chip_distribution_test.dart")

    require(root_page, "static const int _scannerIndex = 2;", "stable scanner route index")
    require(root_page, "static const int _s8BatchIndex = 3;", "stable batch route index")
    require(root_page, "static const int _researchIndex = 4;", "stable research route index")
    require(root_page, "static const int _chipDistributionIndex = 5;", "append-only chip route index")
    require(root_page, "const _RouteBuilder(child: ChipDistributionPage())", "lazy route child")

    require(chip_page, "PythonMultiLevelChanAnalysisSource", "online analyze_multi source")
    require(chip_page, "source.analyzeMulti", "online analyze_multi call")
    require(chip_page, "ChipOnlineReplayAdapter.fromSnapshot", "snapshot to chip bars adapter")
    require(chip_page, "ChipOnlineReplayAdapter.resolveTargetIndex", "replay target resolver usage")
    require(chip_page, "只使用在线 analyze_multi 返回的 K 线", "online-only policy")
    require(chip_page, "不读取离线分笔文件", "no offline policy")
    require(chip_page, "_mode == 'step'", "step mode support")
    require(chip_page, "_crosshairIndex", "crosshair target state")
    require(chip_page, "_viewEndIndex", "visible right target state")
    require(chip_page, "卖侧筹码", "sell side metric")
    require(chip_page, "买侧筹码", "buy side metric")

    require(adapter, "fromSnapshot", "online snapshot adapter")
    require(adapter, "snapshot?.rawBars", "online bars source")
    require(adapter, "isStepMode ? stepIndex : null", "step target priority")
    require(adapter, "isStepMode ? null : crosshairIndex", "crosshair guarded by non-step")
    require(adapter, "isStepMode ? null : viewEndIndex", "visible right guarded by non-step")
    reject(adapter, "offline", "offline data dependency")

    require(engine, "final window = bars.sublist(start, safeTarget + 1);", "no future-data window")
    require(engine, "class ChipTickBins", "chip tick bins parser")
    require(engine, "chip_tick_bins", "chip tick bins field")
    require(engine, "priceSellVolume", "sell side support")
    require(engine, "priceBuyVolume", "buy side support")
    require(engine, "_foldOhlcvTriangular", "OHLCV fallback")
    require(engine, "class ChipTargetResolver", "target resolver")

    for needle in [
        "models/fx.dart",
        "models/bi.dart",
        "models/seg.dart",
        "models/zs.dart",
        "models/bsp.dart",
        "chan_snapshot.dart",
        "multi_level_chan_snapshot.dart",
    ]:
        reject(engine, needle, "chip engine structure dependency")

    require(test_file, "does not consume bars after target index", "future-data regression test")
    require(test_file, "chip target priority is step, crosshair, visible right, last bar", "target priority test")

    print(json.dumps({
        "ok": True,
        "route": "筹码分布",
        "branch_task": "hichanchoumafenbu",
        "checks": {
            "route_indexes_preserved": True,
            "online_analyze_multi_source": True,
            "online_snapshot_adapter": True,
            "no_offline_dependency": True,
            "no_future_window_guard": True,
            "chip_tick_bins_p_s_b_w_ready": True,
            "target_priority_step_crosshair_visible_right": True,
            "no_structure_dependency_in_engine": True,
            "tests_added": True,
        },
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
