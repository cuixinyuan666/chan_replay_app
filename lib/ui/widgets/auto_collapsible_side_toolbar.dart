import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Declarative section model for [AutoCollapsibleSideToolbar].
class SideToolbarSection {
  final String title;
  final List<Widget> children;
  final VoidCallback? onTitleTap;

  const SideToolbarSection({
    required this.title,
    required this.children,
    this.onTitleTap,
  });
}

/// A left-side toolbar shell that stays behind its `>` toggle until opened.
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
    this.initiallyExpanded = false,
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant AutoCollapsibleSideToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _setExpanded(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
    widget.onExpandedChanged?.call(value);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_expanded || event is! PointerScrollEvent) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    if (max <= min) return;

    final rawNext = _scrollController.offset + event.scrollDelta.dy;
    double next;
    if (rawNext > max) {
      next = min;
    } else if (rawNext < min) {
      next = max;
    } else {
      next = rawNext;
    }
    _scrollController.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = Positioned(
      left: 0,
      top: widget.top,
      bottom: widget.bottom,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: _expanded ? widget.expandedWidth : widget.collapsedWidth,
        child: MouseRegion(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: _handlePointerSignal,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: <Widget>[
                  if (_expanded)
                    Positioned.fill(
                      child: _ToolbarBody(
                        header: widget.header,
                        sections: widget.sections,
                        scrollController: _scrollController,
                        onSectionTitleTap: (section) {
                          _setExpanded(false);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            section.onTitleTap?.call();
                          });
                        },
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

    // In the collapsed state, keep this widget's hit-test area confined to the
    // visible rail. A full-screen transparent Stack can otherwise intercept
    // chart gestures while making the toggle appear unresponsive.
    if (!_expanded) return toolbar;

    return Positioned.fill(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _setExpanded(false),
            ),
          ),
          toolbar,
        ],
      ),
    );
  }
}

class _ToolbarBody extends StatelessWidget {
  final Widget? header;
  final List<SideToolbarSection> sections;
  final ScrollController scrollController;
  final ValueChanged<SideToolbarSection> onSectionTitleTap;

  const _ToolbarBody({
    required this.header,
    required this.sections,
    required this.scrollController,
    required this.onSectionTitleTap,
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
                _SectionDivider(
                  title: sections[i].title,
                  onTap: sections[i].onTitleTap == null
                      ? null
                      : () => onSectionTitleTap(sections[i]),
                ),
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
  final VoidCallback? onTap;

  const _SectionDivider({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: <Widget>[
        const Expanded(child: Divider(color: Colors.white24, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '- $title -',
            style: TextStyle(
              color: onTap == null ? Colors.white70 : const Color(0xFFFFD54F),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white24, height: 1)),
      ],
    );
    if (onTap == null) return row;
    return Tooltip(
      message: '打开$title',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
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
        child: InkWell(
          key: const ValueKey<String>('side-toolbar-toggle'),
          borderRadius: BorderRadius.circular(999),
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
