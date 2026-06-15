enum S13NestedMarkerTriggerState {
  current,
  candidateTrail,
}

class S13NestedMarkerNumberingPolicy {
  const S13NestedMarkerNumberingPolicy();

  String? sequenceLabel({required int sequenceNumber, required int sequenceTotal}) {
    if (sequenceTotal <= 1) return null;
    if (sequenceNumber <= 0 || sequenceNumber > sequenceTotal) return null;
    return '$sequenceNumber';
  }

  int compareTriggerRawIndex(int a, int b) => a.compareTo(b);

  int compareTriggerState(
    S13NestedMarkerTriggerState a,
    S13NestedMarkerTriggerState b,
  ) {
    return 0;
  }
}

class S13NestedMarkerTriggerIdentity {
  final String sourceLevel;
  final int sourceRawIndex;
  final int activeRawIndex;
  final S13NestedMarkerTriggerState state;

  const S13NestedMarkerTriggerIdentity({
    required this.sourceLevel,
    required this.sourceRawIndex,
    required this.activeRawIndex,
    this.state = S13NestedMarkerTriggerState.current,
  });

  bool get isCandidateTrail => state == S13NestedMarkerTriggerState.candidateTrail;

  String get key => '$activeRawIndex|$sourceLevel|$sourceRawIndex|${state.name}';
}
