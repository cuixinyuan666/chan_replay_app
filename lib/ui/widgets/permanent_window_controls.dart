import 'package:flutter/material.dart';

/// Top-right window control button row that stays visible above page overlays.
///
/// The widget is UI-only on purpose. Callers decide how to minimize, maximize,
/// restore or close according to the desktop/window package used by the app.
class PermanentWindowControls extends StatelessWidget {
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximizeRestore;
  final VoidCallback? onClose;
  final bool maximized;
  final EdgeInsetsGeometry padding;

  const PermanentWindowControls({
    super.key,
    this.onMinimize,
    this.onMaximizeRestore,
    this.onClose,
    this.maximized = false,
    this.padding = const EdgeInsets.only(top: 8, right: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        minimum: padding,
        child: Material(
          color: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xCC111722),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _WindowControlButton(
                  tooltip: '最小化',
                  icon: Icons.remove,
                  onPressed: onMinimize,
                ),
                _WindowControlButton(
                  tooltip: maximized ? '还原' : '最大化',
                  icon: maximized ? Icons.filter_none : Icons.crop_square,
                  onPressed: onMaximizeRestore,
                ),
                _WindowControlButton(
                  tooltip: '关闭',
                  icon: Icons.close,
                  danger: true,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowControlButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

  const _WindowControlButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = danger ? const Color(0xFFFF6B6B) : Colors.white70;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 34,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: onPressed == null
                ? baseColor.withValues(alpha: 0.34)
                : baseColor,
          ),
        ),
      ),
    );
  }
}
