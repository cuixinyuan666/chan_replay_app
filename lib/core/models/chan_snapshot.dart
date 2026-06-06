import 'raw_bar.dart';
import 'merged_bar.dart';
import 'fx.dart';
import 'bi.dart';
import 'zs.dart';

class ChanSnapshot {
  final List<RawBar> rawBars;
  final List<MergedBar> mergedBars;
  final List<FX> fxs;
  final List<BI> bis;
  final List<ZS> zss;

  const ChanSnapshot({
    required this.rawBars,
    required this.mergedBars,
    required this.fxs,
    required this.bis,
    required this.zss,
  });

  factory ChanSnapshot.empty() => const ChanSnapshot(
        rawBars: [],
        mergedBars: [],
        fxs: [],
        bis: [],
        zss: [],
      );
}
