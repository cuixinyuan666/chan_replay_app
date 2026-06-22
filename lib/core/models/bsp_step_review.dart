enum BspReviewStatus { pending, correct, wrong }

class BspStepReviewItem {
  final String key;
  final String judgeKey;
  final String level;
  final int anchorRawIndex;
  final int displayRawIndex;
  final bool isBuy;
  final String label;
  final String displayLabel;
  final int firstFrameIndex;
  final BspReviewStatus status;

  const BspStepReviewItem({
    required this.key,
    required this.judgeKey,
    required this.level,
    required this.anchorRawIndex,
    required this.displayRawIndex,
    required this.isBuy,
    required this.label,
    required this.displayLabel,
    required this.firstFrameIndex,
    this.status = BspReviewStatus.pending,
  });

  BspStepReviewItem copyWith({BspReviewStatus? status}) => BspStepReviewItem(
        key: key,
        judgeKey: judgeKey,
        level: level,
        anchorRawIndex: anchorRawIndex,
        displayRawIndex: displayRawIndex,
        isBuy: isBuy,
        label: label,
        displayLabel: displayLabel,
        firstFrameIndex: firstFrameIndex,
        status: status ?? this.status,
      );
}

class BspReviewStats {
  final int appeared;
  final int judged;
  final int correct;
  final int wrong;
  final double? rate;
  final int fromFrame;
  final int toFrame;
  final DateTime? fromTime;
  final DateTime? toTime;
  final String reason;

  const BspReviewStats({
    this.appeared = 0,
    this.judged = 0,
    this.correct = 0,
    this.wrong = 0,
    this.rate,
    this.fromFrame = 0,
    this.toFrame = 0,
    this.fromTime,
    this.toTime,
    this.reason = '',
  });
}

class BspBottomLabel {
  final int rawIndex;
  final int anchorRawIndex;
  final String text;
  final bool isBuy;
  final BspReviewStatus status;
  final String level;

  const BspBottomLabel({
    required this.rawIndex,
    required this.anchorRawIndex,
    required this.text,
    required this.isBuy,
    required this.status,
    required this.level,
  });
}
