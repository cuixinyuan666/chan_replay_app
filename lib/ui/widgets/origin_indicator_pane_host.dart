import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import 'origin_indicator_pane.dart';

class OriginIndicatorPaneHost extends StatelessWidget {
  final Widget chart;
  final ChanSnapshot snapshot;
  final bool showVol;
  final bool showMacd;
  final int windowSize;
  final int? viewEndIndex;
  final int? crosshairIndex;
  final double singlePaneHeight;
  final double doublePaneHeight;

  const OriginIndicatorPaneHost({
    super.key,
    required this.chart,
    required this.snapshot,
    this.showVol = true,
    this.showMacd = false,
    required this.windowSize,
    this.viewEndIndex,
    this.crosshairIndex,
    this.singlePaneHeight = 102,
    this.doublePaneHeight = 176,
  });

  bool get _showVol => showVol && snapshot.indicators.vol.isNotEmpty;
  bool get _showMacd => showMacd && snapshot.indicators.macd.isNotEmpty;
  bool get _showPane => _showVol || _showMacd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: chart),
        if (_showPane)
          SizedBox(
            height: _showVol && _showMacd ? doublePaneHeight : singlePaneHeight,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12, width: 0.8)),
              ),
              child: OriginIndicatorPane(
                snapshot: snapshot,
                showVol: _showVol,
                showMacd: _showMacd,
                windowSize: windowSize,
                viewEndIndex: viewEndIndex,
                crosshairIndex: crosshairIndex,
              ),
            ),
          ),
      ],
    );
  }
}
