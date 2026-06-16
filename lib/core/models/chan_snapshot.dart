import 'raw_bar.dart';
import 'merged_bar.dart';
import 'fx.dart';
import 'bi.dart';
import 'seg.dart';
import 'recursive_seg.dart';
import 'zs.dart';
import 'bsp.dart';
import 'plot_layer_item.dart';
import 'easy_tdx_indicator.dart';
import 'rhythm.dart';

class ChanSnapshot {
  final List<RawBar> rawBars;
  final List<MergedBar> mergedBars;
  final List<FX> fxs;
  final List<BI> bis;
  final List<SEG> segs;
  final Map<int, List<RecursiveSEG>> recursiveSegLayers;
  final List<ZS> zss;
  final List<BspPoint> bsps;
  final List<ZS> segZss;
  final List<PlotLayerItem> eigenBoxes;
  final List<PlotLayerItem> segEigenBoxes;
  final EasyTdxIndicators indicators;
  final List<RhythmLine> rhythmLines;
  final List<RhythmHit> rhythmHits;

  const ChanSnapshot({
    required this.rawBars,
    required this.mergedBars,
    required this.fxs,
    required this.bis,
    required this.segs,
    this.recursiveSegLayers = const <int, List<RecursiveSEG>>{},
    required this.zss,
    this.bsps = const [],
    this.segZss = const [],
    this.eigenBoxes = const [],
    this.segEigenBoxes = const [],
    this.indicators = const EasyTdxIndicators(),
    this.rhythmLines = const [],
    this.rhythmHits = const [],
  });

  factory ChanSnapshot.empty() => const ChanSnapshot(
        rawBars: [],
        mergedBars: [],
        fxs: [],
        bis: [],
        segs: [],
        recursiveSegLayers: <int, List<RecursiveSEG>>{},
        zss: [],
        bsps: [],
        segZss: [],
        eigenBoxes: [],
        segEigenBoxes: [],
        indicators: EasyTdxIndicators(),
        rhythmLines: [],
        rhythmHits: [],
      );
}
