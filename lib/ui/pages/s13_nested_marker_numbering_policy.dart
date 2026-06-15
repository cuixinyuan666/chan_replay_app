class S13NestedMarkerNumberingPolicy {
  const S13NestedMarkerNumberingPolicy();

  String? sequenceLabel({required int sequenceNumber, required int sequenceTotal}) {
    if (sequenceTotal <= 1) return null;
    if (sequenceNumber <= 0 || sequenceNumber > sequenceTotal) return null;
    return '$sequenceNumber';
  }

  int compareTriggerRawIndex(int a, int b) => a.compareTo(b);
}

class S13NestedMarkerTriggerIdentity {
  final String sourceLevel;
  final int sourceRawIndex;
  final int activeRawIndex;

  const S13NestedMarkerTriggerIdentity({
    required this.sourceLevel,
    required this.sourceRawIndex,
    required this.activeRawIndex,
  });

  String get key => '$activeRawIndex|$sourceLevel|$sourceRawIndex';
}
