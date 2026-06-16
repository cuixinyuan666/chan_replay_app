import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact, draggable entry point for chart/replay tools.
///
/// Keep this widget state-local and route-callback driven so feature branches can
/// merge back into hichan without touching individual replay pages.
class UnifiedDraggableToolMenu extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onOpen;
  final List<UnifiedToolMenuSection> sections;
  final Offset initialOffset;

  const UnifiedDraggableToolMenu({
    super.key,
    required this.currentIndex,
    required this.onOpen,
    required this.sections,
    this.initialOffset = const Offset(16, 112),
  });

  @override
  State<UnifiedDraggableToolMenu> createState() =>
      _UnifiedDraggableToolMenuState();
}

class _UnifiedDraggableToolMenuState extends State<UnifiedDraggableToolMenu> {
  static const double _buttonSize = 46;
  static const double _panelWidth = 420;
  static const double _panelMinHeight = 260;
  static const double _panelMaxHeight = 620;

  late Offset _offset = widget.initialOffset;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final left = _offset.dx.clamp(0.0, math.max(0.0, screen.width - 68));
    final top = _offset.dy.clamp(0.0, math.max(0.0, screen.height - 68));
    final panelHeight = (screen.height - top - 18)
        .clamp(_panelMinHeight, math.min(_panelMaxHeight, screen.height - 24));
    final panelLeft = (left + _buttonSize + 10 + _panelWidth > screen.width)
        ? math.max(8.0, left - _panelWidth - 10)
        : left + _buttonSize + 10;

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: _drag,
              child: _UnifiedMenuButton(
                open: _open,
                selectedLabel: _currentLabel,
                onPressed: () => setState(() => _open = !_open),
              ),
            ),
            if (_open)
              Transform.translate(
                offset: Offset(panelLeft - left - _buttonSize, 0),
                child: SizedBox(
                  width: _panelWidth,
                  height: panelHeight,
                  child: _UnifiedMenuPanel(
                    currentIndex: widget.currentIndex,
                    sections: widget.sections,
                    onClose: () => setState(() => _open = false),
                    onOpenRoute: _openRoute,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _currentLabel {
    for (final section in widget.sections) {
      for (final group in section.groups) {
        for (final item in group.items) {
          if (item.routeIndex == widget.currentIndex) return item.label;
        }
      }
    }
    return '工具';
  }

  void _drag(DragUpdateDetails details) {
    final screen = MediaQuery.sizeOf(context);
    setState(() {
      final next = _offset + details.delta;
      _offset = Offset(
        next.dx.clamp(0.0, math.max(0.0, screen.width - 68)),
        next.dy.clamp(0.0, math.max(0.0, screen.height - 68)),
      );
    });
  }

  void _openRoute(int routeIndex) {
    setState(() => _open = false);
    widget.onOpen(routeIndex);
  }
}

class _UnifiedMenuButton extends StatelessWidget {
  final bool open;
  final String selectedLabel;
  final VoidCallback onPressed;

  const _UnifiedMenuButton({
    required this.open,
    required this.selectedLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '统一工具入口：$selectedLabel\n拖动按钮可调整位置',
      child: SizedBox(
        width: 46,
        height: 46,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(open ? Icons.close : Icons.widgets_outlined, size: 20),
          color: Colors.white,
          style: IconButton.styleFrom(
            backgroundColor: open
                ? const Color(0xFF2962FF)
                : const Color(0xE6131722),
            side: BorderSide(
              color: open ? const Color(0xFF8AB4FF) : Colors.white24,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 8,
            shadowColor: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _UnifiedMenuPanel extends StatelessWidget {
  final int currentIndex;
  final List<UnifiedToolMenuSection> sections;
  final VoidCallback onClose;
  final ValueChanged<int> onOpenRoute;

  const _UnifiedMenuPanel({
    required this.currentIndex,
    required this.sections,
    required this.onClose,
    required this.onOpenRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 20,
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xF2131722),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              blurRadius: 22,
              offset: Offset(0, 10),
              color: Color(0xAA000000),
            ),
          ],
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.account_tree, color: Color(0xFFFFD54F)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '统一工具入口',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                itemCount: sections.length,
                itemBuilder: (context, index) => _sectionTile(sections[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile(UnifiedToolMenuSection section) {
    return Theme(
      data: ThemeData.dark().copyWith(
        dividerColor: Colors.transparent,
        visualDensity: VisualDensity.compact,
      ),
      child: ExpansionTile(
        initiallyExpanded: section.initiallyExpanded,
        leading: Icon(section.icon, size: 19, color: const Color(0xFFFFD54F)),
        title: Text(
          section.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: section.description == null
            ? null
            : Text(
                section.description!,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: <Widget>[
          for (final group in section.groups) _groupTile(group),
        ],
      ),
    );
  }

  Widget _groupTile(UnifiedToolMenuGroup group) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: ExpansionTile(
        initiallyExpanded: group.initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 8, right: 2, bottom: 6),
        leading: Icon(group.icon, size: 17, color: Colors.white70),
        title: Text(
          group.title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: <Widget>[
          for (final item in group.items) _itemTile(item),
        ],
      ),
    );
  }

  Widget _itemTile(UnifiedToolMenuItem item) {
    final selected = item.routeIndex == currentIndex;
    final enabled = item.enabled && item.routeIndex != null;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      minLeadingWidth: 24,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      enabled: enabled,
      selected: selected,
      selectedTileColor: const Color(0x332962FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: Icon(
        item.icon,
        color: selected ? const Color(0xFF8AB4FF) : Colors.white60,
        size: 18,
      ),
      title: Text(
        item.label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: item.description == null
          ? null
          : Text(
              item.description!,
              style: const TextStyle(color: Colors.white38, fontSize: 10.5),
            ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 16)
          : const Icon(Icons.chevron_right, color: Colors.white30, size: 16),
      onTap: enabled ? () => onOpenRoute(item.routeIndex!) : null,
    );
  }
}

class UnifiedToolMenuSection {
  final String title;
  final IconData icon;
  final String? description;
  final bool initiallyExpanded;
  final List<UnifiedToolMenuGroup> groups;

  const UnifiedToolMenuSection({
    required this.title,
    required this.icon,
    required this.groups,
    this.description,
    this.initiallyExpanded = false,
  });
}

class UnifiedToolMenuGroup {
  final String title;
  final IconData icon;
  final bool initiallyExpanded;
  final List<UnifiedToolMenuItem> items;

  const UnifiedToolMenuGroup({
    required this.title,
    required this.icon,
    required this.items,
    this.initiallyExpanded = false,
  });
}

class UnifiedToolMenuItem {
  final String label;
  final IconData icon;
  final int? routeIndex;
  final String? description;
  final bool enabled;

  const UnifiedToolMenuItem({
    required this.label,
    required this.icon,
    required this.routeIndex,
    this.description,
    this.enabled = true,
  });
}
