import 'package:flutter/material.dart';

import 'auto_collapsible_side_toolbar.dart';

/// S13-specific adapter for the reusable left side toolbar shell.
class S13QuickSideToolbar extends StatelessWidget {
  final List<SideToolbarSection> sections;

  const S13QuickSideToolbar({
    super.key,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return AutoCollapsibleSideToolbar(
      top: 44,
      bottom: 12,
      expandedWidth: 430,
      initiallyExpanded: true,
      autoCollapseDelay: const Duration(seconds: 5),
      header: _header(),
      sections: sections,
    );
  }

  Widget _header() => const Row(
        children: <Widget>[
          Icon(Icons.account_tree, color: Color(0xFFFFD54F), size: 18),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '单股多级别复盘',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
}
