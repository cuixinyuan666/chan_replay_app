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
    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _barIcon('重置', Icons.restart_alt, onReset),
              _barIcon('后退一根K线', Icons.skip_previous, onStepBack),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: IconButton.filled(
                  tooltip: playing ? '暂停' : '播放',
                  onPressed: onTogglePlay,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2962FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              _barIcon('前进一根K线', Icons.skip_next, onStepForward),
              const SizedBox(width: 8),
              Text(
                '$cursor / $total',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              const Text(
                'Bar Replay',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              min: 0,
              max: max,
              divisions: total > 0 ? total : null,
              value: value.clamp(0.0, max).toDouble(),
              onChanged: onSliderChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barIcon(String tooltip, IconData icon, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: Colors.white70,
      visualDensity: VisualDensity.compact,
    );
  }
}
