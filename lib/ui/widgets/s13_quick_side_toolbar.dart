import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../settings/kline_appearance_controller.dart';
import 'auto_collapsible_side_toolbar.dart';

/// K-line chart entry adapter for the reusable left side toolbar shell.
class S13QuickSideToolbar extends StatelessWidget {
  final List<SideToolbarSection> sections;
  final String Function()? currentSettingsTextBuilder;

  const S13QuickSideToolbar({
    super.key,
    required this.sections,
    this.currentSettingsTextBuilder,
  });

  static const List<Color> _klinePalette = <Color>[
    Color(0xFFFFD54F),
    Color(0xFF00E676),
    Color(0xFFFF5252),
    Color(0xFF40C4FF),
    Color(0xFFB388FF),
    Color(0xFFFFFFFF),
  ];

  static const List<Color> _backgroundPalette = <Color>[
    Color(0xFF0D1117),
    Color(0xFF000000),
    Color(0xFF131722),
    Color(0xFF1C2330),
    Color(0xFF102027),
    Color(0xFF21151A),
  ];

  static const List<Color> _themePalette = <Color>[
    Color(0xFFFFD54F),
    Color(0xFF40C4FF),
    Color(0xFF00E676),
    Color(0xFFFF7043),
    Color(0xFFB388FF),
    Color(0xFF26A69A),
  ];

  @override
  Widget build(BuildContext context) {
    return AutoCollapsibleSideToolbar(
      top: 44,
      bottom: 12,
      expandedWidth: 430,
      initiallyExpanded: false,
      autoCollapseDelay: const Duration(seconds: 5),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _header(),
          const SizedBox(height: 10),
          _appearanceControls(),
        ],
      ),
      sections: _effectiveSections(),
    );
  }

  List<SideToolbarSection> _effectiveSections() {
    return <SideToolbarSection>[
      for (final section in sections)
        if (section.title == '页面')
          SideToolbarSection(
            title: section.title,
            children: _dedupePageChildren(section.children),
          )
        else
          section,
    ];
  }

  List<Widget> _dedupePageChildren(List<Widget> children) {
    final filtered = <Widget>[];
    for (final child in children) {
      final next = _filterDuplicatePageRouteButtons(child);
      if (next != null) filtered.add(next);
    }
    return filtered;
  }

  Widget? _filterDuplicatePageRouteButtons(Widget child) {
    if (child is Wrap) {
      final filtered = <Widget>[];
      for (var i = 0; i < child.children.length; i++) {
        final item = child.children[i];
        final isCurrentPageSelfRoute = i == 0;
        final hasDuplicateLabel = _isDuplicateCurrentPageRoute(_textOf(item));
        if (!isCurrentPageSelfRoute && !hasDuplicateLabel) {
          filtered.add(item);
        }
      }
      if (filtered.isEmpty) return null;
      return Wrap(
        spacing: child.spacing,
        runSpacing: child.runSpacing,
        alignment: child.alignment,
        runAlignment: child.runAlignment,
        crossAxisAlignment: child.crossAxisAlignment,
        textDirection: child.textDirection,
        verticalDirection: child.verticalDirection,
        clipBehavior: child.clipBehavior,
        children: filtered,
      );
    }
    return _isDuplicateCurrentPageRoute(_textOf(child)) ? null : child;
  }

  bool _isDuplicateCurrentPageRoute(String label) {
    final compact = label.replaceAll(RegExp(r'\s+'), '');
    return compact == '复盘' ||
        compact == '单股多级别' ||
        compact == '单股多级别复盘' ||
        compact == 'K线图';
  }

  Widget _appearanceControls() {
    return ValueListenableBuilder<KlineAppearanceSettings>(
      valueListenable: KlineAppearanceController.selected,
      builder: (context, settings, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x661C2330),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.palette, size: 16, color: Color(0xFFFFD54F)),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'K线图外观',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: KlineAppearanceController.reset,
                      child: const Text('默认', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _colorRow(
                  label: 'K线颜色',
                  colors: _klinePalette,
                  selected: settings.klineColor,
                  onSelected: KlineAppearanceController.setKlineColor,
                ),
                const SizedBox(height: 8),
                _opacitySlider(settings.klineOpacity),
                const SizedBox(height: 8),
                _colorRow(
                  label: '背景颜色',
                  colors: _backgroundPalette,
                  selected: settings.chartBackgroundColor,
                  onSelected: KlineAppearanceController.setChartBackgroundColor,
                ),
                const SizedBox(height: 8),
                _colorRow(
                  label: 'App主题色',
                  colors: _themePalette,
                  selected: settings.appThemeColor,
                  onSelected: KlineAppearanceController.setAppThemeColor,
                ),
                const SizedBox(height: 6),
                Text(
                  settings.toEvidenceText(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _opacitySlider(double opacity) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 64,
          child: Text('透明度', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: opacity,
            min: 0,
            max: 0.65,
            divisions: 13,
            label: opacity.toStringAsFixed(2),
            onChanged: KlineAppearanceController.setKlineOpacity,
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            opacity.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _colorRow({
    required String label,
    required List<Color> colors,
    required Color selected,
    required ValueChanged<Color> onSelected,
  }) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 64,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final color in colors)
                _colorButton(
                  color: color,
                  selected: color == selected,
                  onPressed: () => onSelected(color),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _colorButton({
    required Color color,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2.4 : 1,
            ),
            boxShadow: selected
                ? const <BoxShadow>[
                    BoxShadow(color: Color(0x88FFFFFF), blurRadius: 7),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _copyCurrentToolbarSettings(BuildContext context) async {
    final text = _toolbarSettingsText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('当前工具栏设置已复制'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _toolbarSettingsText() {
    final explicit = currentSettingsTextBuilder?.call().trim();
    if (explicit != null && explicit.isNotEmpty) {
      return '$explicit\n[K线图外观]\n${KlineAppearanceController.current.toEvidenceText()}';
    }

    final buffer = StringBuffer()
      ..writeln('KLINE_CHART_CURRENT_TOOLBAR_SETTINGS')
      ..writeln('generated_at=${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln('[K线图外观]')
      ..writeln(KlineAppearanceController.current.toEvidenceText())
      ..writeln();
    for (final section in _effectiveSections()) {
      buffer.writeln('[${section.title}]');
      final lines = <String>[];
      for (final child in section.children) {
        _collectWidgetSettings(child, lines, depth: 0);
      }
      if (lines.isEmpty) {
        buffer.writeln('-');
      } else {
        for (final line in lines) {
          buffer.writeln(line);
        }
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  void _collectWidgetSettings(
    Widget widget,
    List<String> out, {
    required int depth,
  }) {
    final indent = ''.padLeft(depth * 2);
    if (widget is Text) {
      final text = widget.data?.trim();
      if (text != null && text.isNotEmpty) out.add('$indent- text=$text');
      return;
    }
    if (widget is TextField) {
      final label = widget.decoration?.labelText ?? widget.decoration?.hintText ?? 'TextField';
      out.add('$indent- $label=${widget.controller?.text ?? ''}');
      return;
    }
    if (widget is FilterChip) {
      out.add('$indent- ${_textOf(widget.label)}=${widget.selected}');
      return;
    }
    if (widget is ChoiceChip) {
      out.add('$indent- ${_textOf(widget.label)}=${widget.selected}');
      return;
    }
    if (widget is SwitchListTile) {
      out.add('$indent- ${_textOf(widget.title)}=${widget.value}');
      if (widget.subtitle != null) {
        out.add('$indent  subtitle=${_textOf(widget.subtitle!)}');
      }
      return;
    }
    if (widget is CheckboxListTile) {
      out.add('$indent- ${_textOf(widget.title)}=${widget.value}');
      if (widget.subtitle != null) {
        out.add('$indent  subtitle=${_textOf(widget.subtitle!)}');
      }
      return;
    }
    if (widget is ListTile) {
      out.add('$indent- ${_textOf(widget.title)}');
      if (widget.subtitle != null) {
        out.add('$indent  subtitle=${_textOf(widget.subtitle!)}');
      }
      return;
    }
    if (widget is ButtonStyleButton) {
      final label = _textOf(widget.child);
      if (label.isNotEmpty) out.add('$indent- button=$label');
      return;
    }
    if (widget is Tooltip) {
      if (widget.message != null && widget.message!.trim().isNotEmpty) {
        out.add('$indent- tooltip=${widget.message}');
      }
      if (widget.child != null) {
        _collectWidgetSettings(widget.child!, out, depth: depth + 1);
      }
      return;
    }
    if (widget is SizedBox) {
      final child = widget.child;
      if (child != null) _collectWidgetSettings(child, out, depth: depth);
      return;
    }
    if (widget is Padding) {
      final child = widget.child;
      if (child != null) _collectWidgetSettings(child, out, depth: depth);
      return;
    }
    if (widget is Align) {
      final child = widget.child;
      if (child != null) _collectWidgetSettings(child, out, depth: depth);
      return;
    }
    if (widget is Expanded) {
      _collectWidgetSettings(widget.child, out, depth: depth);
      return;
    }
    if (widget is Flexible) {
      _collectWidgetSettings(widget.child, out, depth: depth);
      return;
    }
    if (widget is Container) {
      final child = widget.child;
      if (child != null) _collectWidgetSettings(child, out, depth: depth);
      return;
    }
    if (widget is Wrap) {
      for (final child in widget.children) {
        _collectWidgetSettings(child, out, depth: depth);
      }
      return;
    }
    if (widget is Row) {
      for (final child in widget.children) {
        _collectWidgetSettings(child, out, depth: depth);
      }
      return;
    }
    if (widget is Column) {
      for (final child in widget.children) {
        _collectWidgetSettings(child, out, depth: depth);
      }
      return;
    }
  }

  String _textOf(Widget? widget) {
    if (widget == null) return '';
    if (widget is Text) return widget.data ?? '';
    if (widget is RichText) return widget.text.toPlainText();
    if (widget is Tooltip) return widget.message ?? _textOf(widget.child);
    if (widget is SizedBox) return _textOf(widget.child);
    if (widget is Padding) return _textOf(widget.child);
    if (widget is Align) return _textOf(widget.child);
    if (widget is Expanded) return _textOf(widget.child);
    if (widget is Flexible) return _textOf(widget.child);
    if (widget is Container) return _textOf(widget.child);
    if (widget is Row) {
      return widget.children
          .map(_textOf)
          .where((text) => text.trim().isNotEmpty)
          .join(' ');
    }
    if (widget is Column) {
      return widget.children
          .map(_textOf)
          .where((text) => text.trim().isNotEmpty)
          .join(' ');
    }
    return '';
  }

  Widget _header() => const Row(
        children: <Widget>[
          Icon(Icons.candlestick_chart, color: Color(0xFFFFD54F), size: 18),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'K线图',
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
