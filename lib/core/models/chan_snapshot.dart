import 'raw_bar.dart';
import 'merged_bar.dart';
import 'fx.dart';
import 'bi.dart';
import 'seg.dart';
import 'zs.dart';
import 'bsp.dart';
import 'plot_layer_item.dart';

class ChanSnapshot {
  final List<RawBar> rawBars;
  final List<MergedBar> mergedBars;
  final List<FX> fxs;
  final List<BI> bis;
  final List<SEG> segs;
  final List<ZS> zss;
  final List<BspPoint> bsps;
  final List<ZS> segZss;
  final List<PlotLayerItem> eigenBoxes;
  final List<PlotLayerItem> segEigenBoxes;

  const ChanSnapshot({
    required this.rawBars,
    required this.mergedBars,
    required this.fxs,
    required this.bis,
    required this.segs,
    required this.zss,
    this.bsps = const [],
    this.segZss = const [],
    this.eigenBoxes = const [],
    this.segEigenBoxes = const [],
  });

  factory ChanSnapshot.empty() => const ChanSnapshot(
        rawBars: [],
        mergedBars: [],
        fxs: [],
        bis: [],
        segs: [],
        zss: [],
        bsps: [],
        segZss: [],
        eigenBoxes: [],
        segEigenBoxes: [],
      );
}
