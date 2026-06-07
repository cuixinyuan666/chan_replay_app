import 'package:flutter/material.dart';

class ReplayControllerBar extends StatelessWidget {
  final bool playing;
  final bool enabled;
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
    this.enabled = true,
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
      constraints: const BoxConstraints(minHeight: 58, maxHeight: 66),
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            child: Row(
              children: [
                _barIcon('重置', Icons.restart_alt, enabled ? onReset : null),
                _barIcon('后退一根K线', Icons.skip_previous, enabled ? onStepBack : null),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: IconButton.filled(
                    tooltip: enabled ? (playing ? '暂停' : '播放') : '一次性显示模式',
                    onPressed: enabled ? onTogglePlay : null,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white30,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                _barIcon('前进一根K线', Icons.skip_next, enabled ? onStepForward : null),
                const SizedBox(width: 6),
                Text(
                  '$cursor / $total',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  enabled ? 'Bar Replay' : 'Full View',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 20,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                min: 0,
                max: max,
                divisions: total > 0 ? total : null,
                value: value.clamp(0.0, max).toDouble(),
                onChanged: enabled ? onSliderChanged : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barIcon(String tooltip, IconData icon, VoidCallback? onPressed) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: Colors.white70,
      disabledColor: Colors.white24,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    );
  }
}
