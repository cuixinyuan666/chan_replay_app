import 'package:flutter/foundation.dart';

/// Commands that can be sent from the root unified tool menu into the S13 chart.
///
/// The controller is intentionally UI-agnostic. It only describes user intent,
/// feature availability, and the latest switch state, so S13 descendants can
/// consume commands without importing root page widgets or menu widgets.
enum S13ChartToolCommandType {
  openUnifiedPanel,
  openDrawingToolbox,
  setChipDistribution,
  setBspCandidateTrail,
  setRhythmLines,
  setHits1382,
}

@immutable
class S13ChartToolCommand {
  final int sequence;
  final S13ChartToolCommandType type;
  final bool? enabled;

  const S13ChartToolCommand({
    required this.sequence,
    required this.type,
    this.enabled,
  });
}

@immutable
class S13ChartToolState {
  final bool chipDistributionAvailable;
  final bool drawingToolboxAvailable;
  final bool bspCandidateTrailAvailable;
  final bool rhythmLinesAvailable;
  final bool hits1382Available;
  final bool chipDistribution;
  final bool bspCandidateTrail;
  final bool rhythmLines;
  final bool hits1382;

  const S13ChartToolState({
    required this.chipDistributionAvailable,
    required this.drawingToolboxAvailable,
    required this.bspCandidateTrailAvailable,
    required this.rhythmLinesAvailable,
    required this.hits1382Available,
    required this.chipDistribution,
    required this.bspCandidateTrail,
    required this.rhythmLines,
    required this.hits1382,
  });

  static const initial = S13ChartToolState(
    chipDistributionAvailable: false,
    drawingToolboxAvailable: false,
    bspCandidateTrailAvailable: false,
    rhythmLinesAvailable: false,
    hits1382Available: false,
    chipDistribution: false,
    bspCandidateTrail: true,
    rhythmLines: true,
    hits1382: true,
  );

  bool get anyAttached =>
      chipDistributionAvailable ||
      drawingToolboxAvailable ||
      bspCandidateTrailAvailable ||
      rhythmLinesAvailable ||
      hits1382Available;

  S13ChartToolState copyWith({
    bool? chipDistributionAvailable,
    bool? drawingToolboxAvailable,
    bool? bspCandidateTrailAvailable,
    bool? rhythmLinesAvailable,
    bool? hits1382Available,
    bool? chipDistribution,
    bool? bspCandidateTrail,
    bool? rhythmLines,
    bool? hits1382,
  }) {
    return S13ChartToolState(
      chipDistributionAvailable:
          chipDistributionAvailable ?? this.chipDistributionAvailable,
      drawingToolboxAvailable:
          drawingToolboxAvailable ?? this.drawingToolboxAvailable,
      bspCandidateTrailAvailable:
          bspCandidateTrailAvailable ?? this.bspCandidateTrailAvailable,
      rhythmLinesAvailable: rhythmLinesAvailable ?? this.rhythmLinesAvailable,
      hits1382Available: hits1382Available ?? this.hits1382Available,
      chipDistribution: chipDistribution ?? this.chipDistribution,
      bspCandidateTrail: bspCandidateTrail ?? this.bspCandidateTrail,
      rhythmLines: rhythmLines ?? this.rhythmLines,
      hits1382: hits1382 ?? this.hits1382,
    );
  }
}

class S13ChartToolController {
  static final S13ChartToolController shared = S13ChartToolController._();

  S13ChartToolController._();

  final ValueNotifier<S13ChartToolState> state =
      ValueNotifier<S13ChartToolState>(S13ChartToolState.initial);
  final ValueNotifier<S13ChartToolCommand?> command =
      ValueNotifier<S13ChartToolCommand?>(null);

  int _sequence = 0;

  bool get attached => state.value.anyAttached;

  void setAvailability({
    bool? chipDistributionAvailable,
    bool? drawingToolboxAvailable,
    bool? bspCandidateTrailAvailable,
    bool? rhythmLinesAvailable,
    bool? hits1382Available,
  }) {
    state.value = state.value.copyWith(
      chipDistributionAvailable: chipDistributionAvailable,
      drawingToolboxAvailable: drawingToolboxAvailable,
      bspCandidateTrailAvailable: bspCandidateTrailAvailable,
      rhythmLinesAvailable: rhythmLinesAvailable,
      hits1382Available: hits1382Available,
    );
  }

  void sync({
    bool? chipDistribution,
    bool? bspCandidateTrail,
    bool? rhythmLines,
    bool? hits1382,
  }) {
    state.value = state.value.copyWith(
      chipDistribution: chipDistribution,
      bspCandidateTrail: bspCandidateTrail,
      rhythmLines: rhythmLines,
      hits1382: hits1382,
    );
  }

  void openUnifiedPanel() => _emit(S13ChartToolCommandType.openUnifiedPanel);

  void openDrawingToolbox() => _emit(S13ChartToolCommandType.openDrawingToolbox);

  void setChipDistribution(bool enabled) {
    state.value = state.value.copyWith(chipDistribution: enabled);
    _emit(S13ChartToolCommandType.setChipDistribution, enabled: enabled);
  }

  void setBspCandidateTrail(bool enabled) {
    state.value = state.value.copyWith(bspCandidateTrail: enabled);
    _emit(S13ChartToolCommandType.setBspCandidateTrail, enabled: enabled);
  }

  void setRhythmLines(bool enabled) {
    state.value = state.value.copyWith(rhythmLines: enabled);
    _emit(S13ChartToolCommandType.setRhythmLines, enabled: enabled);
  }

  void setHits1382(bool enabled) {
    state.value = state.value.copyWith(hits1382: enabled);
    _emit(S13ChartToolCommandType.setHits1382, enabled: enabled);
  }

  void _emit(S13ChartToolCommandType type, {bool? enabled}) {
    command.value = S13ChartToolCommand(
      sequence: ++_sequence,
      type: type,
      enabled: enabled,
    );
  }
}
