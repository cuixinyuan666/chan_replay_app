enum ReplayClockMode {
  once,
  strictMainLevel,
  strictLowestLevel,
}

extension ReplayClockModeX on ReplayClockMode {
  String get label {
    switch (this) {
      case ReplayClockMode.once:
        return '一次性显示';
      case ReplayClockMode.strictMainLevel:
        return '严格逐K-主级别';
      case ReplayClockMode.strictLowestLevel:
        return '严格逐K-最小级别';
    }
  }

  String get wireName {
    switch (this) {
      case ReplayClockMode.once:
        return 'once';
      case ReplayClockMode.strictMainLevel:
        return 'strict_main_level';
      case ReplayClockMode.strictLowestLevel:
        return 'strict_lowest_level';
    }
  }

  bool get isStepMode => this != ReplayClockMode.once;

  static ReplayClockMode fromWireName(Object? value) {
    final text = '${value ?? ''}'.trim().toLowerCase();
    switch (text) {
      case 'strict_main_level':
      case 'main':
      case 'main_level':
        return ReplayClockMode.strictMainLevel;
      case 'strict_lowest_level':
      case 'lowest':
      case 'lowest_level':
      case 'min':
        return ReplayClockMode.strictLowestLevel;
      case 'once':
      default:
        return ReplayClockMode.once;
    }
  }
}
