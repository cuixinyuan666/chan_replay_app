import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Declarative section model for [AutoCollapsibleSideToolbar].
class SideToolbarSection {
  final String title;
  final List<Widget> children;

  const SideToolbarSection({
    required this.title,
    required this.children,
  });
}

/// A left-side toolbar shell that can auto-collapse after user inactivity.
class AutoCollapsibleSideToolbar extends StatefulWidget {
  final List<SideToolbarSection> sections;
  final Widget? header;
  final bool initiallyExpanded;
  final Duration autoCollapseDelay;
  final double expandedWidth;
  final double collapsedWidth;
  final double top;
  final double bottom;
  final ValueChanged<bool>? onExpandedChanged;

  const AutoCollapsibleSideToolbar({
    super.key,
    required this.sections,
    this.header,
    this.initiallyExpanded = true,
    this.autoCollapseDelay = const Duration(seconds: 5),
    this.expandedWidth = 286,
    this.collapsedWidth = 52,
    this.top = 12,
    this.bottom = 12,
    this.onExpandedChanged,
  });

  @override
  State<AutoCollapsibleSideToolbar> createState() =>
      _AutoCollapsibleSideToolbarState();
}

class _AutoCollapsibleSideToolbarState
    extends State<AutoCollapsibleSideToolbar> {
  late bool _expanded;
  Timer? _autoCollapseTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _restartAutoCollapseTimer();
  }

  @override
  void didUpdateWidget(covariant AutoCollapsibleSideToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoCollapseDelay != widget.autoCollapseDelay) {
      _restartAutoCollapseTimer();
    }
  }

  @override
  void dispose() {
    _autoCollapseTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _setExpanded(bool value) {
    if (_expanded == value) {
      if (value) _restartAutoCollapseTimer();
      return;
    }
    setState(() => _expanded = value);
    widget.onExpandedChanged?.call(value);
    if (value) {
      _restartAutoCollapseTimer();
    } else {
      _autoCollapseTimer?.cancel();
    }
  }

  void _markUserActivity() {
    if (!_expanded) return;
    _restartAutoCollapseTimer();
  }

  void _restartAutoCollapseTimer() {
    _autoCollapseTimer?.cancel();
    if (!_expanded || widget.autoCollapseDelay <= Duration.zero) return;
    _autoCollapseTimer = Timer(widget.autoCollapseDelay, () {
      if (mounted) _setExpanded(false);
    });
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_expanded || event is! PointerScrollEvent) return;
    if (!_scrollController.hasClients) return;
    final next = (_scrollController.offset + event.scrollDelta.dy).clamp(
      _scrollController.position.minScrollExtent,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(next.toDouble());
    _markUserActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: widget.top,
      bottom: widget.bottom,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: _expanded ? widget.expandedWidth : widget.collapsedWidth,
        child: MouseRegion(
          onEnter: (_) => _markUserActivity(),
          onHover: (_) => _markUserActivity(),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _markUserActivity(),
            onPointerMove: (_) => _markUserActivity(),
            onPointerSignal: _handlePointerSignal,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _expanded ? null : () => _setExpanded(true),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_expanded,
                      child: AnimatedOpacity(
                        opacity: _expanded ? 1 : 0,
                        duration: const Duration(milliseconds: 120),
                        child: _ToolbarBody(
                          header: widget.header,
                          sections: widget.sections,
                          scrollController: _scrollController,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ToolbarToggleButton(
                      expanded: _expanded,
                      onPressed: () => _setExpanded(!_expanded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarBody extends StatelessWidget {
  final Widget? header;
  final List<SideToolbarSection> sections;
  final ScrollController scrollController;

  const _ToolbarBody({
    required this.header,
    required this.sections,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6111722),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 10, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (header != null) ...[
                header!,
                const SizedBox(height: 10),
              ],
              for (var i = 0; i < sections.length; i++) ...[
                _SectionDivider(title: sections[i].title),
                const SizedBox(height: 8),
                ...sections[i].children,
                if (i != sections.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String title;

  const _SectionDivider({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: Colors.white24, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '- $title -',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white24, height: 1)),
      ],
    );
  }
}

class _ToolbarToggleButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;

  const _ToolbarToggleButton({
    required this.expanded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = expanded ? '收回左侧工具栏' : '展开左侧工具栏';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xF01E293B),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 10,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Text(
              expanded ? '<' : '>',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
