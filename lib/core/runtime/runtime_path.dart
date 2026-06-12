import 'package:flutter/foundation.dart';

/// Runtime path selector for B1.
///
/// This is a UI/runtime routing policy only. It does not implement Chan
/// calculation. Chan calculation authority remains original python/chan.py.
enum RuntimePath {
  highSpeed,
  slowPath,
}

extension RuntimePathDiagnostics on RuntimePath {
  String get wireName {
    switch (this) {
      case RuntimePath.highSpeed:
        return 'high_speed';
      case RuntimePath.slowPath:
        return 'slow_path';
    }
  }

  String get label {
    switch (this) {
      case RuntimePath.highSpeed:
        return '高速路（默认）';
      case RuntimePath.slowPath:
        return '慢速路（原始校验/调试）';
    }
  }

  bool get isHighSpeed => this == RuntimePath.highSpeed;

  Map<String, Object> get diagnostics => {
        'runtime_path': wireName,
        'high_speed_enabled': isHighSpeed,
        'slow_path_enabled': !isHighSpeed,
        'runtime_path_default': 'high_speed',
        'runtime_path_policy': 'high_speed_default_slow_path_debug_only',
      };

  List<String> get diagnosticLines => [
        'runtime_path: $wireName',
        'high_speed_enabled: $isHighSpeed',
        'slow_path_enabled: ${!isHighSpeed}',
        'runtime_path_default: high_speed',
        'runtime_path_policy: high_speed_default_slow_path_debug_only',
      ];
}

class RuntimePathController {
  const RuntimePathController._();

  static final ValueNotifier<RuntimePath> selected =
      ValueNotifier<RuntimePath>(RuntimePath.highSpeed);

  static RuntimePath get current => selected.value;

  static void set(RuntimePath path) {
    selected.value = path;
  }

  static List<String> diagnosticLines([RuntimePath? path]) =>
      (path ?? current).diagnosticLines;

  static Map<String, Object> diagnostics([RuntimePath? path]) =>
      (path ?? current).diagnostics;
}
