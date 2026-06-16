import 'package:flutter/foundation.dart';

/// Commands that can be sent from the root unified tool menu into the S13 chart.
///
/// The controller is intentionally UI-agnostic.  It only describes user intent
/// and the latest switch state, so S13 can consume commands without importing
/// root page widgets or menu widgets.
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
  final bool attached;
  final bool chipDistribution;
  final bool bspCandidateTrail;
  final bool rhythmLines;
  final bool hits1382;

  const S13ChartToolState({
    required this.attached,
    required this.chipDistribution,
    required this.bspCandidateTrail,
    required this.rhythmLines,
    required this.hits1382,
  });

  static const initial = S13ChartToolState(
    attached: false,
    chipDistribution: false,
    bspCandidateTrail: true,
    rhythmLines: true,
    hits1382: true,
  );

  S13ChartToolState copyWith({
    bool? attached,
    bool? chipDistribution,
    bool? bspCandidateTrail,
    bool? rhythmLines,
    bool? hits1382,
  }) {
    return S13ChartToolState(
      attached: attached ?? this.attached,
      chipDistribution: chipDistribution ?? this.chipDistribution,
      bspCandidateTrail: bspCandidateTrail ?? this.bspCandidateTrail,
      rhythmLines: rhythmLines ?? this.rhythmLines,
      hits1382: hits1382 ?? this.hits1382,
    );
  }
}

class S13ChartToolController {
  final ValueNotifier<S13ChartToolState> state =
      ValueNotifier<S13ChartToolState>(S13ChartToolState.initial);
  final ValueNotifier<S13ChartToolCommand?> command =
      ValueNotifier<S13ChartToolCommand?>(null);

  int _sequence = 0;

  bool get attached => state.value.attached;

  void sync({
    required bool chipDistribution,
    required bool bspCandidateTrail,
    required bool rhythmLines,
    required bool hits1382,
  }) {
    state.value = state.value.copyWith(
      attached: true,
      chipDistribution: chipDistribution,
      bspCandidateTrail: bspCandidateTrail,
      rhythmLines: rhythmLines,
      hits1382: hits1382,
    );
  }

  void detach() {
    state.value = state.value.copyWith(attached: false);
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

  void dispose() {
    state.dispose();
    command.dispose();
  }
}
