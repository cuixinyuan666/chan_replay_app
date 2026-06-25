import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Minimal custom title-bar layer for the borderless Windows shell.
///
/// The only visible window control is close. A thin top strip remains draggable
/// so the app window can still be moved without reintroducing min/max buttons.
class WindowsHoverTitleBar extends StatelessWidget {
  final Widget child;

  const WindowsHoverTitleBar({super.key, required this.child});

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Widget build(BuildContext context) {
    if (!_isWindows) return child;
    return Stack(
      children: <Widget>[
        child,
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: 6,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => windowManager.startDragging(),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
