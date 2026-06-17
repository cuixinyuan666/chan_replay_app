import 'package:flutter/material.dart';

import 'auto_collapsible_side_toolbar.dart';

/// S13-specific adapter for the reusable left side toolbar shell.
class S13QuickSideToolbar extends StatelessWidget {
  final bool settingsPanelOpen;
  final List<SideToolbarSection> settingsSections;
  final VoidCallback onToggleSettingsPanel;

  const S13QuickSideToolbar({
    super.key,
    required this.settingsPanelOpen,
    required this.settingsSections,
    required this.onToggleSettingsPanel,
  });

  @override
  Widget build(BuildContext context) {
    return AutoCollapsibleSideToolbar(
      top: 44,
      bottom: 12,
      expandedWidth: settingsPanelOpen ? 430 : 240,
      initiallyExpanded: true,
      autoCollapseDelay: const Duration(seconds: 5),
      header: _header(),
      sections: <SideToolbarSection>[
        SideToolbarSection(
          title: '快捷入口',
          children: <Widget>[
            _actionButton(
              icon: Icons.tune,
              label: settingsPanelOpen ? '收回工具栏' : '展开工具栏',
              onPressed: onToggleSettingsPanel,
            ),
          ],
        ),
        if (settingsPanelOpen) ...settingsSections,
      ],
    );
  }

  Widget _header() => const Row(
        children: <Widget>[
          Icon(Icons.account_tree, color: Color(0xFFFFD54F), size: 18),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '单股多级别',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0x221E293B),
          foregroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Colors.white12),
          ),
        ),
      ),
    );
  }
}
