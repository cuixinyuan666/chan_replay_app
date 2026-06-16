#!/usr/bin/env python3
"""Apply the small S13 chip-panel integration patch locally.

GitHub contents writes replace whole files, while S13SingleStockReplayPage is a large
core page. This helper applies the intended minimal patch with guarded string
replacements so the branch can be updated safely from a local checkout.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S13 = ROOT / "lib/ui/pages/s13_single_stock_replay_page.dart"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = S13.read_text(encoding="utf-8")

    if "../widgets/s13_chip_distribution_panel.dart" not in text:
        text = replace_once(
            text,
            "import '../widgets/origin_kline_chart.dart';\n",
            "import '../widgets/origin_kline_chart.dart';\n"
            "import '../widgets/s13_chip_distribution_panel.dart';\n",
            "import insertion",
        )

    if "_showChipDistribution" not in text:
        text = replace_once(
            text,
            "  bool _loading = false,\n"
            "      _showBspCandidateTrail = true,\n"
            "      _panelOpen = false,\n"
            "      _playing = false;\n",
            "  bool _loading = false,\n"
            "      _showBspCandidateTrail = true,\n"
            "      _showChipDistribution = false,\n"
            "      _panelOpen = false,\n"
            "      _playing = false;\n",
            "chip state insertion",
        )

    toolbar_needle = (
        "                              _floatingIcon(Icons.architecture, '画线工具',\n"
        "                                  () => _toolboxOpenSignal.value++),\n"
        "                              const SizedBox(width: 4),\n"
        "                              const Icon(Icons.drag_indicator,\n"
    )
    if "Icons.stacked_bar_chart" not in text.split("Widget _floatingToolbar()", 1)[1].split("void _dragFloatingToolbar", 1)[0]:
        text = replace_once(
            text,
            toolbar_needle,
            "                              _floatingIcon(Icons.architecture, '画线工具',\n"
            "                                  () => _toolboxOpenSignal.value++),\n"
            "                              const SizedBox(width: 6),\n"
            "                              _floatingIcon(\n"
            "                                  Icons.stacked_bar_chart,\n"
            "                                  _showChipDistribution ? '关闭筹码分布' : '筹码分布',\n"
            "                                  () => setState(() =>\n"
            "                                      _showChipDistribution = !_showChipDistribution)),\n"
            "                              const SizedBox(width: 4),\n"
            "                              const Icon(Icons.drag_indicator,\n",
            "floating toolbar chip button insertion",
        )

    chart_needle = (
        "               onWindowSizeChanged: (v) => setState(() => _windowSize = v),\n"
        "               onPriceScaleChanged: (v) => setState(() => _priceScale = v))),\n"
        "       _nestedBspMarkerOverlay(),\n"
        "       _replayControlOverlay()\n"
    )
    if "S13ChipDistributionPanel(" not in text:
        text = replace_once(
            text,
            chart_needle,
            "               onWindowSizeChanged: (v) => setState(() => _windowSize = v),\n"
            "               onPriceScaleChanged: (v) => setState(() => _priceScale = v))),\n"
            "       S13ChipDistributionPanel(\n"
            "         snapshot: _activeSnapshot,\n"
            "         enabled: _showChipDistribution,\n"
            "         isStepMode: _isStepMode,\n"
            "         stepIndex: (s.rawBars.length - 1).clamp(0, s.rawBars.length - 1).toInt(),\n"
            "         crosshairIndex: _crosshairIndex,\n"
            "         visibleRightIndex: (_viewEndIndex ?? s.rawBars.length - 1)\n"
            "             .clamp(0, s.rawBars.length - 1)\n"
            "             .toInt(),\n"
            "         onClose: () => setState(() => _showChipDistribution = false),\n"
            "       ),\n"
            "       _nestedBspMarkerOverlay(),\n"
            "       _replayControlOverlay()\n",
            "chart stack chip panel insertion",
        )

    S13.write_text(text, encoding="utf-8")
    print("patched", S13.relative_to(ROOT))


if __name__ == "__main__":
    main()
