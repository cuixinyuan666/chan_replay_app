import '../core/runtime/runtime_path.dart';
import '../core/settings/chan_config_store.dart';
import 'python_multi_level_chan_analysis_source.dart';

class ChanConfiguredMultiLevelAnalysisSource {
  final PythonMultiLevelChanAnalysisSource _source;

  ChanConfiguredMultiLevelAnalysisSource({
    required String baseUrl,
  }) : _source = PythonMultiLevelChanAnalysisSource(baseUrl: baseUrl);

  Future<PythonMultiLevelChanAnalysis> analyzeMulti({
    required String mode,
    required String market,
    required String code,
    required List<String> levels,
    required String adjust,
    required Map<String, dynamic> config,
    String? mainLevel,
    String? clockLevel,
    int? count,
    DateTime? startDate,
    DateTime? endDate,
    RuntimePath? runtimePath,
  }) {
    return _source.analyzeMulti(
      mode: mode,
      market: market,
      code: code,
      levels: levels,
      adjust: adjust,
      mainLevel: mainLevel,
      clockLevel: clockLevel,
      count: count,
      startDate: startDate,
      endDate: endDate,
      runtimePath: runtimePath,
      config: ChanConfigStore.backendConfig(base: config),
    );
  }

  void close() => _source.close();
}
