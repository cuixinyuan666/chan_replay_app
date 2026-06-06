import 'package:flutter/material.dart';

class ReplayControllerBar extends StatelessWidget {
  final bool playing;
  final int cursor;
  final int total;
  final VoidCallback onReset;
  final VoidCallback onStepBack;
  final VoidCallback onStepForward;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSliderChanged;

  const ReplayControllerBar({
    super.key,
    required this.playing,
    required this.cursor,
    required this.total,
    required this.onReset,
    required this.onStepBack,
    required this.onStepForward,
    required this.onTogglePlay,
    required this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final max = total <= 0 ? 1.0 : total.toDouble();
    final value = cursor.clamp(0, total).toDouble();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '重置',
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt),
                ),
                IconButton(
                  tooltip: '后退一根K线',
                  onPressed: onStepBack,
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton.filled(
                  tooltip: playing ? '暂停' : '播放',
                  onPressed: onTogglePlay,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: '前进一根K线',
                  onPressed: onStepForward,
                  icon: const Icon(Icons.skip_next),
                ),
                const SizedBox(width: 8),
                Text('$cursor / $total'),
              ],
            ),
            Slider(
              min: 0,
              max: max,
              divisions: total > 0 ? total : null,
              value: value.clamp(0.0, max),
              onChanged: onSliderChanged,
            ),
          ],
        ),
      ),
    );
  }
}
