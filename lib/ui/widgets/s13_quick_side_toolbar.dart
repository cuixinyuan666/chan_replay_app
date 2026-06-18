import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auto_collapsible_side_toolbar.dart';

/// S13-specific adapter for the reusable left side toolbar shell.
class S13QuickSideToolbar extends StatelessWidget {
  final List<SideToolbarSection> sections;
  final String Function()? currentSettingsTextBuilder;

  const S13QuickSideToolbar({
    super.key,
    required this.sections,
    this.currentSettingsTextBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AutoCollapsibleSideToolbar(
      top: 44,
      bottom: 12,
      expandedWidth: 430,
      initiallyExpanded: true,
      autoCollapseDelay: const Duration(seconds: 5),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _header(),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () => _copyCurrentToolbarSettings(context),
            icon: const Icon(Icons.copy_all, size: 16),
            label: const Text('复制当前工具栏设置'),
          ),
        ],
      ),
      sections: sections,
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
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final buffer = StringBuffer()
      ..writeln('S13_CURRENT_TOOLBAR_SETTINGS')
      ..writeln('generated_at=${DateTime.now().toIso8601String()}')
      ..writeln();
    for (final section in sections) {
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
