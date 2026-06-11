enum SignalVisibilityState {
  forming,
  candidate,
  confirmed,
  invalid,
  futureOnly,
}

extension SignalVisibilityStateX on SignalVisibilityState {
  String get label {
    switch (this) {
      case SignalVisibilityState.forming:
        return '形成中';
      case SignalVisibilityState.candidate:
        return '候选';
      case SignalVisibilityState.confirmed:
        return '已确认';
      case SignalVisibilityState.invalid:
        return '失效';
      case SignalVisibilityState.futureOnly:
        return '事后确认';
    }
  }

  String get wireName {
    switch (this) {
      case SignalVisibilityState.forming:
        return 'forming';
      case SignalVisibilityState.candidate:
        return 'candidate';
      case SignalVisibilityState.confirmed:
        return 'confirmed';
      case SignalVisibilityState.invalid:
        return 'invalid';
      case SignalVisibilityState.futureOnly:
        return 'future_only';
    }
  }

  bool get isTradableAtCursor =>
      this == SignalVisibilityState.candidate ||
      this == SignalVisibilityState.confirmed;

  bool get isNoFutureSafe => this != SignalVisibilityState.futureOnly;

  static SignalVisibilityState fromWireName(Object? value) {
    final text = '${value ?? ''}'.trim().toLowerCase();
    switch (text) {
      case 'forming':
        return SignalVisibilityState.forming;
      case 'confirmed':
        return SignalVisibilityState.confirmed;
      case 'invalid':
        return SignalVisibilityState.invalid;
      case 'future_only':
      case 'futureonly':
      case 'future':
        return SignalVisibilityState.futureOnly;
      case 'candidate':
      default:
        return SignalVisibilityState.candidate;
    }
  }
}
