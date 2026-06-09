import 'package:flutter/material.dart';

import 'ashare_bsp_scanner_page.dart';
import 'origin_replay_page_v2.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _RootLeftToolbar(
            index: _index,
            onChanged: (value) => setState(() => _index = value),
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                OriginReplayPageV2(),
                AshareBspScannerPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RootLeftToolbar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _RootLeftToolbar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      color: const Color(0xFF10141D),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _item(
              context,
              value: 0,
              icon: Icons.candlestick_chart,
              label: '复盘',
            ),
            const SizedBox(height: 8),
            _item(
              context,
              value: 1,
              icon: Icons.radar,
              label: '扫描器',
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required int value,
    required IconData icon,
    required String label,
  }) {
    final selected = index == value;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2962FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF8AB4FF)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? Colors.white : Colors.white60),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
