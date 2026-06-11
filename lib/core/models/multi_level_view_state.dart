import 'multi_level_chan_snapshot.dart';
import 'replay_clock_mode.dart';

class MultiLevelViewState {
  final String activeLevel;
  final String clockLevel;
  final ReplayClockMode clockMode;
  final bool enabled;

  const MultiLevelViewState({
    this.activeLevel = '',
    this.clockLevel = '',
    this.clockMode = ReplayClockMode.once,
    this.enabled = false,
  });

  factory MultiLevelViewState.disabled() => const MultiLevelViewState();

  factory MultiLevelViewState.fromSnapshot(
    MultiLevelChanSnapshot snapshot, {
    ReplayClockMode clockMode = ReplayClockMode.once,
    bool enabled = true,
  }) {
    final active = snapshot.safeActiveLevel;
    return MultiLevelViewState(
      activeLevel: active,
      clockLevel: active,
      clockMode: clockMode,
      enabled: enabled && snapshot.isNotEmpty,
    );
  }

  MultiLevelViewState copyWith({
    String? activeLevel,
    String? clockLevel,
    ReplayClockMode? clockMode,
    bool? enabled,
  }) {
    return MultiLevelViewState(
      activeLevel: activeLevel ?? this.activeLevel,
      clockLevel: clockLevel ?? this.clockLevel,
      clockMode: clockMode ?? this.clockMode,
      enabled: enabled ?? this.enabled,
    );
  }

  MultiLevelViewState withActiveLevel(String level) {
    final normalized = level.trim().toUpperCase();
    if (normalized.isEmpty) return this;
    return copyWith(activeLevel: normalized);
  }

  MultiLevelViewState withClockLevel(String level) {
    final normalized = level.trim().toUpperCase();
    if (normalized.isEmpty) return this;
    return copyWith(clockLevel: normalized);
  }

  MultiLevelViewState withClockMode(ReplayClockMode mode) {
    return copyWith(clockMode: mode);
  }
}
