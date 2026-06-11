import 'package:flutter/material.dart';

import '../../core/models/chan_snapshot.dart';
import '../../core/models/multi_level_chan_snapshot.dart';
import '../../core/models/replay_clock_mode.dart';

class MultiLevelLayerStatusPanel extends StatelessWidget {
  final MultiLevelChanSnapshot fullSnapshot;
  final MultiLevelChanSnapshot? currentSnapshot;
  final String activeLevel;
  final ReplayClockMode clockMode;
  final bool compact;
  final VoidCallback? onMinimize;

  const MultiLevelLayerStatusPanel({
    super.key,
    required this.fullSnapshot,
    this.currentSnapshot,
    required this.activeLevel,
    this.clockMode = ReplayClockMode.once,
    this.compact = false,
    this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    if (fullSnapshot.isEmpty) return const SizedBox.shrink();
    final current = currentSnapshot ?? fullSnapshot;
    final levels = fullSnapshot.levels.isNotEmpty
        ? fullSnapshot.levels
        : fullSnapshot.snapshots.keys.toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xDD11141B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              const Text(
                '多级别图层状态',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _chip(clockMode.label, clockMode.isStepMode
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFF8AB4FF)),
              if (onMinimize != null) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: '最小化图层状态',
                  child: InkWell(
                    onTap: onMinimize,
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(Icons.remove, size: 15, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          for (final level in levels)
            _levelBlock(
              level: level,
              full: fullSnapshot.of(level),
              current: current.of(level),
              active: level.toUpperCase() == activeLevel.toUpperCase(),
            ),
        ],
      ),
    );
  }

  Widget _levelBlock({
    required String level,
    required ChanSnapshot? full,
    required ChanSnapshot? current,
    required bool active,
  }) {
    if (full == null) return const SizedBox.shrink();
    final visible = current ?? full;
    final rows = [
      _LayerCount('K', visible.rawBars.length, full.rawBars.length),
      _LayerCount('FX', visible.fxs.length, full.fxs.length),
      _LayerCount('BI', visible.bis.length, full.bis.length),
      _LayerCount('SEG', visible.segs.length, full.segs.length),
      _LayerCount('ZS', visible.zss.length, full.zss.length),
      _LayerCount('BSP', visible.bsps.length, full.bsps.length),
      _LayerCount('合并K', visible.mergedBars.length, full.mergedBars.length),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? const Color(0x222A5CAA) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0x668AB4FF) : Colors.white10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    level,
                    style: TextStyle(
                      color: active ? const Color(0xFFFFD54F) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 6),
                    _chip('当前', const Color(0xFFFFD54F)),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: [
                  for (final row in rows)
                    _chip(
                      clockMode.isStepMode
                          ? '${row.label} ${row.current}/${row.total}'
                          : '${row.label} ${row.total}',
                      row.total == 0
                          ? const Color(0xFFEF5350)
                          : row.current == 0 && clockMode.isStepMode
                              ? Colors.white38
                              : const Color(0xFF66BB6A),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LayerCount {
  final String label;
  final int current;
  final int total;

  const _LayerCount(this.label, this.current, this.total);
}
