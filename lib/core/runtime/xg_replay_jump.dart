import 'package:flutter/foundation.dart';

class XgReplayJumpRequest {
  final String symbol;
  final String market;
  final List<String> levels;
  final String targetLevel;
  final int rawIndex;
  final DateTime? startDate;
  final DateTime? endDate;
  final String source;

  const XgReplayJumpRequest({
    required this.symbol,
    required this.market,
    required this.levels,
    required this.targetLevel,
    required this.rawIndex,
    this.startDate,
    this.endDate,
    this.source = 'xg',
  });
}

class XgReplayJumpBus {
  static final ValueNotifier<XgReplayJumpRequest?> request = ValueNotifier<XgReplayJumpRequest?>(null);

  static void publish(XgReplayJumpRequest next) {
    request.value = next;
  }
}
