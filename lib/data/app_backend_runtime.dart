import 'dart:io';

class AppBackendRuntimeStatus {
  final String backendUrl;
  final String processSource;
  final String pythonRuntime;
  final bool appBundledBackendAvailable;
  final bool analyzeMultiExpected;
  final List<String> checkedPaths;
  final String status;
  final String message;

  const AppBackendRuntimeStatus({
    required this.backendUrl,
    required this.processSource,
    required this.pythonRuntime,
    required this.appBundledBackendAvailable,
    required this.analyzeMultiExpected,
    required this.checkedPaths,
    required this.status,
    required this.message,
  });

  String toDiagnosticText() {
    return [
      'backend runtime diagnostics',
      'button: Copy Backend',
      'backend_url: $backendUrl',
      'process_source: $processSource',
      'python_runtime: $pythonRuntime',
      'app_bundled_backend_available: $appBundledBackendAvailable',
      'analyze_multi_expected: $analyzeMultiExpected',
      'checked_paths:',
      for (final path in checkedPaths) '- $path',
      'status: $status',
      'message: $message',
    ].join('\n');
  }
}

class AppBackendRuntime {
  const AppBackendRuntime._();

  static Future<AppBackendRuntimeStatus> inspect({
    required String backendUrl,
  }) async {
    final checked = _candidateBackendPaths();
    final existing = <String>[];
    for (final path in checked) {
      if (await File(path).exists()) existing.add(path);
    }
    final available = existing.isNotEmpty;
    return AppBackendRuntimeStatus(
      backendUrl: backendUrl,
      processSource: available ? 'app_managed_candidate' : 'none',
      pythonRuntime: available ? 'app_bundled_candidate' : 'missing_app_bundled',
      appBundledBackendAvailable: available,
      analyzeMultiExpected: available,
      checkedPaths: checked,
      status: available ? 'candidate_found' : 'blocked',
      message: available
          ? 'Found a candidate app-bundled backend file, but launcher wiring still needs verification.'
          : 'No app-bundled backend entry was found. Normal workflow is blocked until the app bundles and launches a backend exposing /api/chan/analyze_multi.',
    );
  }

  static List<String> _candidateBackendPaths() {
    final sep = Platform.pathSeparator;
    return [
      ['python', 'a_server.py'].join(sep),
      ['python', 'a_backend_server.py'].join(sep),
      ['python', 'a_chan_backend.py'].join(sep),
      ['assets', 'python', 'a_server.py'].join(sep),
      ['data', 'flutter_assets', 'assets', 'python', 'a_server.py'].join(sep),
    ];
  }
}
