import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Minimal custom title-bar controls for the borderless Windows shell.
///
/// The bar is hidden by default and fades in when the pointer reaches the top
/// edge. It is a UI shell helper only; it does not affect chart state.
class WindowsHoverTitleBar extends StatefulWidget {
  final Widget child;

  const WindowsHoverTitleBar({super.key, required this.child});

  @override
  State<WindowsHoverTitleBar> createState() => _WindowsHoverTitleBarState();
}

class _WindowsHoverTitleBarState extends State<WindowsHoverTitleBar> {
  bool _visible = false;

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Widget build(BuildContext context) {
    if (!_isWindows) return widget.child;
    return MouseRegion(
      onHover: (event) {
        final next = event.position.dy <= 8 || event.localPosition.dy <= 8;
        if (next != _visible) setState(() => _visible = next);
      },
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: 46,
            child: MouseRegion(
              onEnter: (_) => setState(() => _visible = true),
              onExit: (_) => setState(() => _visible = false),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 140),
                opacity: _visible ? 1 : 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) => windowManager.startDragging(),
                  onDoubleTap: () async {
                    final maximized = await windowManager.isMaximized();
                    if (maximized) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0D10).withValues(alpha: 0.92),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            '缠论K线复盘',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
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
                          onTap: () async {
                            final maximized = await windowManager.isMaximized();
                            if (maximized) {
                              await windowManager.unmaximize();
                            } else {
                              await windowManager.maximize();
                            }
                          },
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
          width: 46,
          height: 46,
          child: Icon(
            icon,
            size: 17,
            color: danger ? const Color(0xFFFF8A80) : Colors.white70,
          ),
        ),
      ),
    );
  }
}
