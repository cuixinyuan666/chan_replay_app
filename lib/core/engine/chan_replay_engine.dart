import 'chan_config.dart';
import 'include_processor.dart';
import 'fx_engine.dart';
import 'bi_engine.dart';
import 'seg_engine.dart';
import 'zs_engine.dart';
import '../models/raw_bar.dart';
import '../models/chan_snapshot.dart';

class ChanReplayEngine {
  ChanConfig config;
  final _rawBars = <RawBar>[];

  final IncludeProcessor _includeProcessor = IncludeProcessor();
  final FxEngine _fxEngine = FxEngine();
  final BiEngine _biEngine = BiEngine();
  final SegEngine _segEngine = SegEngine();
  final ZsEngine _zsEngine = ZsEngine();

  ChanReplayEngine({ChanConfig? config}) : config = config ?? ChanConfig.chanPyDefault();

  void reset() => _rawBars.clear();

  void setConfig(ChanConfig next) {
    config = next;
  }

  ChanSnapshot feed(RawBar bar) {
    _rawBars.add(bar.copyWith(index: _rawBars.length));
    return getSnapshot();
  }

  ChanSnapshot feedMany(List<RawBar> bars) {
    reset();
    for (var i = 0; i < bars.length; i++) {
      _rawBars.add(bars[i].copyWith(index: i));
    }
    return getSnapshot();
  }

  ChanSnapshot undo() {
    if (_rawBars.isNotEmpty) _rawBars.removeLast();
    return getSnapshot();
  }

  ChanSnapshot getSnapshot() {
    final raw = List<RawBar>.unmodifiable(_rawBars);
    final merged = _includeProcessor.process(raw, enabled: config.enableInclude);
    final fxs = _fxEngine.detect(merged, config);
    final bis = _biEngine.build(fxs, config, mergedBars: merged);
    final segs = _segEngine.build(bis, config);
    final zss = _zsEngine.build(bis, config, segs: segs);

    return ChanSnapshot(
      rawBars: raw,
      mergedBars: List.unmodifiable(merged),
      fxs: List.unmodifiable(fxs),
      bis: List.unmodifiable(bis),
      segs: List.unmodifiable(segs),
      zss: List.unmodifiable(zss),
    );
  }
}
