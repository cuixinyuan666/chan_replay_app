import 'package:flutter/material.dart';

/// Legacy top-right window control overlay.
///
/// K-line pages now rely on the lower-level window controls/title-bar layer.
/// Keeping this widget inert avoids duplicate minimize/maximize/close buttons
/// from covering chart-level controls while preserving old call sites.
class PermanentWindowControls extends StatelessWidget {
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximizeRestore;
  final VoidCallback? onClose;
  final bool maximized;
  final EdgeInsets padding;

  const PermanentWindowControls({
    super.key,
    this.onMinimize,
    this.onMaximizeRestore,
    this.onClose,
    this.maximized = false,
    this.padding = const EdgeInsets.only(top: 8, right: 8),
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
