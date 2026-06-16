#!/usr/bin/env python3
"""Validate online chip distribution integration for hichancmfb."""

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
    s13_page = read("lib/ui/pages/s13_single_stock_replay_page.dart")
    raw_bar = read("lib/core/models/raw_bar.dart")
    parser = read("lib/data/chan_snapshot_json_parser.dart")
    engine = read("lib/core/analysis/chip_distribution.dart")
    adapter = read("lib/core/analysis/chip_online_replay_adapter.dart")
    panel = read("lib/ui/widgets/s13_chip_distribution_panel.dart")
    test_file = read("test/chip_distribution_test.dart")

    require(root_page, "static const int _scannerIndex = 2;", "stable scanner route index")
    require(root_page, "static const int _s8BatchIndex = 3;", "stable batch route index")
    require(root_page, "static const int _researchIndex = 4;", "stable research route index")
    require(root_page, "static const int _settingsIndex = 5;", "stable settings route index")
    require(root_page, "static const int _cacheOptimizationIndex = 6;", "stable cache route index")
    require(root_page, "static const int _chipDistributionIndex = 7;", "append-only chip route index")
    require(root_page, "const _RouteBuilder(child: ChipDistributionPage())", "lazy route child")

    require(s13_page, "s13_chip_distribution_panel.dart", "S13 chip overlay import")
    require(s13_page, "_showChipDistribution", "S13 chip overlay toggle state")
    require(s13_page, "Icons.stacked_bar_chart", "S13 chip toolbar button")
    require(s13_page, "S13ChipDistributionPanel(", "S13 chart stack chip overlay")
    require(s13_page, "snapshot: _activeSnapshot", "S13 overlay uses active snapshot")
    require(s13_page, "crosshairIndex: _crosshairIndex", "S13 overlay crosshair target")
    require(s13_page, "visibleRightIndex:", "S13 overlay visible-right target")

    require(chip_page, "PythonMultiLevelChanAnalysisSource", "online analyze_multi source")
    require(chip_page, "source.analyzeMulti", "online analyze_multi call")
    require(chip_page, "ChipOnlineReplayAdapter.fromSnapshot", "snapshot to chip bars adapter")
    require(chip_page, "ChipOnlineReplayAdapter.resolveTargetIndex", "replay target resolver usage")
    require(chip_page, "只使用在线 analyze_multi 返回的 K 线", "online-only policy")
    require(chip_page, "不读取离线分笔文件", "no offline-file policy")
    require(chip_page, "_mode == 'step'", "step mode support")
    require(chip_page, "_crosshairIndex", "crosshair target state")
    require(chip_page, "_viewEndIndex", "visible right target state")
    require(chip_page, "卖侧筹码", "sell side metric")
    require(chip_page, "买侧筹码", "buy side metric")

    require(raw_bar, "final ChipTickBins chipTickBins;", "RawBar chip bins field")
    require(raw_bar, "this.chipTickBins = const ChipTickBins()", "RawBar chip bins default")
    require(raw_bar, "ChipTickBins? chipTickBins", "RawBar copyWith chip bins")

    require(parser, "ChipTickBins.fromJson(", "backend bar chip_tick_bins parser")
    require(parser, "row['chip_tick_bins'] ?? row['chipTickBins']", "snake/camel chip bins field support")
    require(parser, "chipTickBins: chipTickBins", "RawBar parser preserves chip bins")

    require(adapter, "fromSnapshot", "online snapshot adapter")
    require(adapter, "snapshot?.rawBars", "online bars source")
    require(adapter, "bar.chipTickBins", "adapter consumes RawBar chip bins")
    require(adapter, "priceVolume: bar.chipTickBins.totalByPrice", "adapter total bins passthrough")
    require(adapter, "priceSellVolume: bar.chipTickBins.sellByPrice", "adapter sell bins passthrough")
    require(adapter, "priceBuyVolume: bar.chipTickBins.buyByPrice", "adapter buy bins passthrough")
    require(adapter, "isStepMode ? stepIndex : null", "step target priority")
    require(adapter, "isStepMode ? null : crosshairIndex", "crosshair guarded by non-step")
    require(adapter, "isStepMode ? null : viewEndIndex", "visible right guarded by non-step")
    reject(adapter, "offline", "offline data dependency")

    require(panel, "内嵌筹码 overlay", "S13 in-chart overlay doc")
    require(panel, "Positioned.fill", "S13 chip uses full chart overlay")
    require(panel, "IgnorePointer", "S13 chip overlay does not block chart gestures")
    require(panel, "_InChartChipDistributionPainter", "S13 in-chart chip painter")
    require(panel, "chip_tick_bins 优先", "S13 overlay exact-bin policy text")
    require(panel, "priceToY", "S13 chip aligns to chart price axis")
    require(panel, "exactBarCount", "S13 exact bucket coverage metric")
    require(panel, "精确桶", "S13 exact bucket coverage UI")
    reject(panel, "width: 286", "legacy floating card width")
    reject(panel, "height: 360", "legacy floating card height")

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
    require(test_file, "online replay adapter preserves backend chip_tick_bins from RawBar", "online exact-bin passthrough test")

    print(json.dumps({
        "ok": True,
        "route": "单股多级别/K线图内筹码分布",
        "branch_task": "hichancmfb",
        "checks": {
            "route_indexes_preserved": True,
            "online_analyze_multi_source": True,
            "raw_bar_chip_bins_preserved": True,
            "backend_json_parser_preserves_chip_bins": True,
            "online_snapshot_adapter_preserves_chip_bins": True,
            "in_chart_chip_overlay": True,
            "overlay_does_not_block_chart_gestures": True,
            "no_legacy_floating_card": True,
            "no_offline_dependency": True,
            "no_future_window_guard": True,
            "chip_tick_bins_p_s_b_w_ready": True,
            "target_priority_step_crosshair_visible_right": True,
            "s13_exact_bucket_coverage_display": True,
            "no_structure_dependency_in_engine": True,
            "tests_added": True,
        },
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
