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
    easy_tdx_source = read("lib/data/easy_tdx_kline_source.dart")
    panel = read("lib/ui/widgets/s13_chip_distribution_panel.dart")
    store = read("lib/ui/widgets/s13_chip_distribution_store.dart")
    recursive_chart = read("lib/ui/widgets/recursive_seg_origin_kline_chart.dart")
    origin_chart = read("lib/ui/widgets/origin_kline_chart.dart")
    test_file = read("test/chip_distribution_test.dart")

    require(root_page, "static const int _scannerIndex = 2;", "stable scanner route index")
    require(root_page, "static const int _s8BatchIndex = 3;", "stable batch route index")
    require(root_page, "static const int _researchIndex = 4;", "stable research route index")
    require(root_page, "static const int _settingsIndex = 5;", "stable settings route index")
    require(root_page, "static const int _cacheOptimizationIndex = 6;", "stable cache route index")
    require(root_page, "static const int _chipDistributionIndex = 7;", "append-only chip route index")
    require(root_page, "const _RouteBuilder(child: ChipDistributionPage())", "lazy route child")

    require(s13_page, "s13_chip_distribution_panel.dart", "S13 chip controller import")
    require(s13_page, "recursive_seg_origin_kline_chart.dart", "S13 origin chart adapter import")
    require(s13_page, "_showChipDistribution", "S13 chip toggle state")
    require(s13_page, "Icons.stacked_bar_chart", "S13 chip toolbar button")
    require(s13_page, "S13ChipDistributionPanel(", "S13 chart stack chip controller")
    require(s13_page, "RecursiveSegOriginKlineChart(", "S13 chart uses origin chart adapter")
    require(s13_page, "crosshairIndex: _crosshairIndex", "S13 chip crosshair target")
    require(s13_page, "visibleRightIndex:", "S13 chip visible-right target")

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

    require(easy_tdx_source, "loadListingChipBars", "listing-range chip K loader")
    require(easy_tdx_source, "/api/tdx/kline", "easy-tdx kline endpoint")
    require(easy_tdx_source, "'period': period.trim().toUpperCase()", "period query parameter")
    require(easy_tdx_source, "count = 200000", "large default listing count")
    require(easy_tdx_source, "ChipDistributionBar.fromJson", "easy-tdx rows parsed as chip bars")
    require(easy_tdx_source, "chipTickBins: ChipTickBins(", "RawBar preserves exact bins from kline source")
    reject(easy_tdx_source, "'freq': period", "legacy freq query parameter")

    require(panel, "State<S13ChipDistributionPanel>", "S13 chip controller is stateful for lazy loading")
    require(panel, "_scheduleLazyLoad", "S13 chip lazy load scheduler")
    require(panel, "EasyTdxKlineSource", "S13 chip independent easy-tdx source")
    require(panel, "loadListingChipBars", "S13 chip independent listing-range load")
    require(panel, "endDate: cutoff", "S13 chip request ends at displayed cutoff")
    require(panel, "count: 200000", "S13 chip large count request")
    require(panel, "S13ChipDistributionStore.publish", "S13 chip publishes painter spec")
    require(panel, "lookback: 1000000", "S13 chip uses full loaded listing range")
    require(panel, "showDialog<void>", "S13 chip load success popup")
    require(panel, "筹码分布的获取区间为:", "required load range popup text")
    require(panel, "独立拉取首个可得K", "listing/first-available range label")
    require(panel, "targetRawIndex: rawBars[targetIndex].index", "display cutoff raw index bridge")
    reject(panel, "rawBars.sublist(0, targetIndex + 1)", "old replay-window-only chip source")
    reject(panel, "_ChipOverlayPainter", "old sibling custom painter overlay")
    reject(panel, "Positioned.fill", "old full chart chip overlay")
    reject(panel, "const dynamic", "invalid dynamic const fallback")

    require(store, "ValueNotifier<S13ChipDistributionSpec?>", "chip store notifier")
    require(store, "S13ChipDistributionSpec", "chip painter spec")
    require(store, "toDrawingObjects", "chip bins converted to drawing objects")
    require(store, "TradingViewDrawingTool.rectangle", "chip bins rendered as rectangles")
    require(store, "DrawingObject(", "chip bins become origin drawing objects")
    require(store, "locked: true", "chip objects are non-interactive locked objects")
    require(store, "updateChartContext", "origin chart publishes symbol/period context")

    require(recursive_chart, "s13_chip_distribution_store.dart", "recursive chart imports chip store")
    require(recursive_chart, "S13ChipDistributionStore.updateChartContext", "origin adapter updates chip context")
    require(recursive_chart, "ValueListenableBuilder<S13ChipDistributionSpec?>", "origin adapter listens to chip result")
    require(recursive_chart, "...chipObjects", "chip objects fed into OriginKlineChart")
    require(recursive_chart, "base.OriginKlineChart", "chip is passed to origin chart")
    require(recursive_chart, "_OriginChartPainter -> DrawingObjectPainter.paintObjects", "main painter chain policy text")

    require(origin_chart, "DrawingObjectPainter.paintObjects", "OriginKlineChart main painter object path")

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
        "route": "单股多级别/OriginKlineChart主绘制链筹码分布",
        "branch_task": "hichancmfb",
        "checks": {
            "route_indexes_preserved": True,
            "online_analyze_multi_source": True,
            "raw_bar_chip_bins_preserved": True,
            "backend_json_parser_preserves_chip_bins": True,
            "online_snapshot_adapter_preserves_chip_bins": True,
            "chip_lazy_load": True,
            "range_popup_after_load": True,
            "easy_tdx_listing_range_request": True,
            "uses_tdx_kline_period_param": True,
            "first_available_to_cutoff_policy": True,
            "origin_main_painter_chain": True,
            "chip_bins_as_locked_origin_drawing_objects": True,
            "no_legacy_sibling_chip_painter": True,
            "no_replay_window_only_source": True,
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
