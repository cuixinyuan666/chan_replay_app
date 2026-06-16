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
  static final Expando<List<RhythmLine>> _rhythmLineCache =
      Expando<List<RhythmLine>>('chan_snapshot_rhythm_lines_by_raw_bars');
  static final Expando<List<RhythmHit>> _rhythmHitCache =
      Expando<List<RhythmHit>>('chan_snapshot_rhythm_hits_by_raw_bars');

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

  ChanSnapshot({
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
    List<RhythmLine> rhythmLines = const [],
    List<RhythmHit> rhythmHits = const [],
  })  : rhythmLines = rhythmLines.isNotEmpty
            ? rhythmLines
            : (_rhythmLineCache[rawBars] ?? const <RhythmLine>[]),
        rhythmHits = rhythmHits.isNotEmpty
            ? rhythmHits
            : (_rhythmHitCache[rawBars] ?? const <RhythmHit>[]) {
    if (rhythmLines.isNotEmpty) {
      _rhythmLineCache[rawBars] = rhythmLines;
    }
    if (rhythmHits.isNotEmpty) {
      _rhythmHitCache[rawBars] = rhythmHits;
    }
  }

  factory ChanSnapshot.empty() => ChanSnapshot(
        rawBars: const [],
        mergedBars: const [],
        fxs: const [],
        bis: const [],
        segs: const [],
        recursiveSegLayers: const <int, List<RecursiveSEG>>{},
        zss: const [],
        bsps: const [],
        segZss: const [],
        eigenBoxes: const [],
        segEigenBoxes: const [],
        indicators: const EasyTdxIndicators(),
        rhythmLines: const [],
        rhythmHits: const [],
      );
}
