import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Minimal custom title-bar controls for the borderless Windows shell.
///
/// The hover trigger is intentionally only a very thin strip at the top edge.
/// The actual hit-test area is restricted to the right-top control capsule so
/// chart/tool-bar widgets below it remain clickable.
class WindowsHoverTitleBar extends StatefulWidget {
  final Widget child;

  const WindowsHoverTitleBar({super.key, required this.child});

  @override
  State<WindowsHoverTitleBar> createState() => _WindowsHoverTitleBarState();
}

class _WindowsHoverTitleBarState extends State<WindowsHoverTitleBar> {
  bool _visible = false;

  bool get _isWindows => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Widget build(BuildContext context) {
    if (!_isWindows) return widget.child;
    return MouseRegion(
      onHover: (event) {
        if (event.position.dy <= 6 && !_visible) setState(() => _visible = true);
      },
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: 6,
            child: MouseRegion(
              onEnter: (_) => setState(() => _visible = true),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 6,
            right: 10,
            width: 154,
            height: 34,
            child: IgnorePointer(
              ignoring: !_visible,
              child: MouseRegion(
                onEnter: (_) => setState(() => _visible = true),
                onExit: (_) => setState(() => _visible = false),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: _visible ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0D10).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 10,
                          offset: Offset(0, 2),
                          color: Color(0x66000000),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (_) => windowManager.startDragging(),
                          onDoubleTap: _toggleMaximize,
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.drag_indicator, size: 15, color: Colors.white38),
                          ),
                        ),
                        _WindowButton(
                          semanticLabel: '最小化',
                          icon: Icons.remove,
                          onTap: () => windowManager.minimize(),
                        ),
                        _WindowButton(
                          semanticLabel: '最大化 / 还原',
                          icon: Icons.crop_square,
                          onTap: _toggleMaximize,
                        ),
                        _WindowButton(
                          semanticLabel: '关闭',
                          icon: Icons.close,
                          danger: true,
                          onTap: () => windowManager.close(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMaximize() async {
    final maximized = await windowManager.isMaximized();
    if (maximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
}

class _WindowButton extends StatelessWidget {
  final String semanticLabel;
  final IconData icon;
  final bool danger;
  final VoidCallback onTap;

  const _WindowButton({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 34,
          child: Icon(
            icon,
            size: 16,
            color: danger ? const Color(0xFFFF8A80) : Colors.white70,
          ),
        ),
      ),
    );
  }
}
