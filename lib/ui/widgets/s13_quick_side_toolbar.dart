import 'package:flutter/material.dart';

import 'auto_collapsible_side_toolbar.dart';

/// Low-risk S13-specific adapter for the reusable left side toolbar shell.
///
/// It only hosts the first migrated entries requested by the hichan UI task:
/// toolbar, drawing tools and chip distribution. The large S13 settings panel can
/// be passed as [settingsPanel] so existing business widgets do not need to be
/// rewritten during the first integration step.
class S13QuickSideToolbar extends StatelessWidget {
  final bool settingsPanelOpen;
  final bool chipDistributionVisible;
  final bool loading;
  final Widget settingsPanel;
  final VoidCallback onToggleSettingsPanel;
  final VoidCallback onOpenDrawingTools;
  final VoidCallback onToggleChipDistribution;

  const S13QuickSideToolbar({
    super.key,
    required this.settingsPanelOpen,
    required this.chipDistributionVisible,
    required this.loading,
    required this.settingsPanel,
    required this.onToggleSettingsPanel,
    required this.onOpenDrawingTools,
    required this.onToggleChipDistribution,
  });

  @override
  Widget build(BuildContext context) {
    return AutoCollapsibleSideToolbar(
      top: 44,
      bottom: 12,
      expandedWidth: settingsPanelOpen ? 430 : 286,
      initiallyExpanded: true,
      autoCollapseDelay: const Duration(seconds: 5),
      header: _header(),
      sections: <SideToolbarSection>[
        SideToolbarSection(
          title: '快捷入口',
          children: <Widget>[
            _actionButton(
              icon: Icons.tune,
              label: settingsPanelOpen ? '收回工具栏面板' : '展开工具栏面板',
              onPressed: onToggleSettingsPanel,
            ),
            const SizedBox(height: 8),
            _actionButton(
              icon: Icons.architecture,
              label: '画线工具',
              onPressed: onOpenDrawingTools,
            ),
            const SizedBox(height: 8),
            _actionButton(
              icon: Icons.stacked_bar_chart,
              label: chipDistributionVisible ? '关闭筹码分布' : '筹码分布',
              selected: chipDistributionVisible,
              onPressed: loading ? null : onToggleChipDistribution,
            ),
          ],
        ),
        if (settingsPanelOpen)
          SideToolbarSection(
            title: '工具栏',
            children: <Widget>[
              SizedBox(
                height: MediaQuery.sizeOf(context).height - 170,
                child: settingsPanel,
              ),
            ],
          ),
      ],
    );
  }

  Widget _header() => Row(
        children: const <Widget>[
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
    bool selected = false,
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
          backgroundColor: selected
              ? const Color(0x5542A5F5)
              : const Color(0x221E293B),
          foregroundColor: selected ? const Color(0xFFBBDEFB) : Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: selected ? const Color(0x8842A5F5) : Colors.white12,
            ),
          ),
        ),
      ),
    );
  }
}
