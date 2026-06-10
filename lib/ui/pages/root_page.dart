import 'package:flutter/material.dart';

import 'ashare_bsp_scanner_page.dart';
import 'origin_replay_page_v2.dart';

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  static const int _replayIndex = 0;
  static const int _scannerIndex = 1;

  int _index = _replayIndex;

  bool get _showingScanner => _index == _scannerIndex;

  void _openReplay() => setState(() => _index = _replayIndex);
  void _openScanner() => setState(() => _index = _scannerIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              OriginReplayPageV2(),
              AshareBspScannerPage(),
            ],
          ),
          _RouteToolButton(
            tooltip: _showingScanner ? '返回复盘' : '扫描器',
            icon: _showingScanner ? Icons.candlestick_chart : Icons.radar,
            selected: _showingScanner,
            onPressed: _showingScanner ? _openReplay : _openScanner,
          ),
        ],
      ),
    );
  }
}

class _RouteToolButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  const _RouteToolButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 3,
      bottom: 18,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 42,
            height: 38,
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(icon, size: 19),
              color: selected ? Colors.white : Colors.white70,
              disabledColor: Colors.white24,
              style: IconButton.styleFrom(
                backgroundColor: selected
                    ? const Color(0xFF2962FF)
                    : const Color(0xEE131722),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF8AB4FF)
                      : Colors.white.withValues(alpha: 0.10),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
