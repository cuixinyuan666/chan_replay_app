import 'package:flutter/material.dart';

import '../../core/models/rhythm.dart';
import '../drawing/drawing_object.dart';

class S13RhythmGroupStyle {
  final int lineColor;
  final double lineWidth;
  final bool dashed;
  final double textFontSize;

  const S13RhythmGroupStyle({
    required this.lineColor,
    required this.lineWidth,
    required this.dashed,
    required this.textFontSize,
  });

  S13RhythmGroupStyle copyWith({
    int? lineColor,
    double? lineWidth,
    bool? dashed,
    double? textFontSize,
  }) =>
      S13RhythmGroupStyle(
        lineColor: lineColor ?? this.lineColor,
        lineWidth: lineWidth ?? this.lineWidth,
        dashed: dashed ?? this.dashed,
        textFontSize: textFontSize ?? this.textFontSize,
      );
}

class S13RhythmHitStyle {
  final bool enabled;
  final int color;
  final double lineWidth;
  final bool dashed;
  final double fontSize;
  final int overflowLimit;

  const S13RhythmHitStyle({
    this.enabled = true,
    this.color = 0xFF7C3AED,
    this.lineWidth = 1.0,
    this.dashed = true,
    this.fontSize = 14,
    this.overflowLimit = 4,
  });

  S13RhythmHitStyle copyWith({
    bool? enabled,
    int? color,
    double? lineWidth,
    bool? dashed,
    double? fontSize,
    int? overflowLimit,
  }) =>
      S13RhythmHitStyle(
        enabled: enabled ?? this.enabled,
        color: color ?? this.color,
        lineWidth: lineWidth ?? this.lineWidth,
        dashed: dashed ?? this.dashed,
        fontSize: fontSize ?? this.fontSize,
        overflowLimit: overflowLimit ?? this.overflowLimit,
      );
}

class S13RhythmDisplaySettings {
  final bool enabled;
  final bool fractToBiEnabled;
  final bool biToSegEnabled;
  final bool segToSegsegEnabled;
  final int maxLayer;
  final String calcMode;
  final List<S13RhythmGroupStyle> groups;
  final S13RhythmHitStyle hit;

  const S13RhythmDisplaySettings({
    this.enabled = true,
    this.fractToBiEnabled = true,
    this.biToSegEnabled = true,
    this.segToSegsegEnabled = true,
    this.maxLayer = 9,
    this.calcMode = 'normal',
    this.groups = defaultGroups,
    this.hit = const S13RhythmHitStyle(),
  });

  static const defaultGroups = <S13RhythmGroupStyle>[
    S13RhythmGroupStyle(lineColor: 0xFF9333EA, lineWidth: 1.2, dashed: true, textFontSize: 12),
    S13RhythmGroupStyle(lineColor: 0xFF0F766E, lineWidth: 1.6, dashed: false, textFontSize: 13),
    S13RhythmGroupStyle(lineColor: 0xFF2563EB, lineWidth: 2.0, dashed: true, textFontSize: 14),
    S13RhythmGroupStyle(lineColor: 0xFFEA580C, lineWidth: 2.4, dashed: false, textFontSize: 15),
    S13RhythmGroupStyle(lineColor: 0xFFBE123C, lineWidth: 2.8, dashed: true, textFontSize: 16),
  ];

  S13RhythmDisplaySettings copyWith({
    bool? enabled,
    bool? fractToBiEnabled,
    bool? biToSegEnabled,
    bool? segToSegsegEnabled,
    int? maxLayer,
    String? calcMode,
    List<S13RhythmGroupStyle>? groups,
    S13RhythmHitStyle? hit,
  }) =>
      S13RhythmDisplaySettings(
        enabled: enabled ?? this.enabled,
        fractToBiEnabled: fractToBiEnabled ?? this.fractToBiEnabled,
        biToSegEnabled: biToSegEnabled ?? this.biToSegEnabled,
        segToSegsegEnabled: segToSegsegEnabled ?? this.segToSegsegEnabled,
        maxLayer: (maxLayer ?? this.maxLayer).clamp(0, 9).toInt(),
        calcMode: _normalizeCalcMode(calcMode ?? this.calcMode),
        groups: groups ?? this.groups,
        hit: hit ?? this.hit,
      );

  bool lineVisible(RhythmLine line) {
    if (!enabled) return false;
    if (line.layer > maxLayer) return false;
    final source = line.sourceKind.trim().toLowerCase();
    final parent = line.level.trim().toLowerCase();
    final p = '${source}->${line.parentLevel}'.toLowerCase();
    if ((p == 'fx->bi' || p == 'fract->bi') && !fractToBiEnabled) return false;
    if (p == 'bi->seg' && !biToSegEnabled) return false;
    if (p == 'seg->segseg' && !segToSegsegEnabled) return false;
    if (source == 'fx' || source == 'fract' || parent.isNotEmpty) return true;
    return true;
  }

  bool hitVisible(RhythmHit hitRow) => hit.enabled;

  DrawingStyle lineStyle(RhythmLine line) {
    final style = groupStyle(line.layer);
    return DrawingStyle(
      colorValue: style.lineColor,
      strokeWidth: style.lineWidth,
      opacity: 0.88,
      dashed: style.dashed,
      fontSize: style.textFontSize,
    );
  }

  DrawingStyle hitStyle(RhythmHit hitRow) => DrawingStyle(
        colorValue: hit.color,
        strokeWidth: hit.lineWidth,
        opacity: 0.95,
        dashed: hit.dashed,
        fontSize: hit.fontSize,
      );

  String hitText(RhythmHit hitRow) => '1.382 ${hitRow.displayLabel}';

  S13RhythmGroupStyle groupStyle(int layer) {
    if (groups.isEmpty) return defaultGroups.first;
    final index = (layer <= 0 ? 0 : layer - 1).clamp(0, groups.length - 1).toInt();
    return groups[index];
  }

  static String _normalizeCalcMode(String value) {
    final v = value.trim();
    return const {'normal', 'transition', 'strict1382'}.contains(v) ? v : 'normal';
  }
}

Future<S13RhythmDisplaySettings?> showS13RhythmDisplaySettingsDialog({
  required BuildContext context,
  required S13RhythmDisplaySettings initial,
}) {
  var draft = initial;
  return showDialog<S13RhythmDisplaySettings>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: const Color(0xFF151924),
        title: const Text('节奏线设置', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: draft.enabled,
                  onChanged: (v) => setState(() => draft = draft.copyWith(enabled: v)),
                  title: const Text('启用节奏线', style: TextStyle(color: Colors.white70)),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: draft.hit.enabled,
                  onChanged: (v) => setState(() => draft = draft.copyWith(hit: draft.hit.copyWith(enabled: v))),
                  title: const Text('启用 1.382 命中', style: TextStyle(color: Colors.white70)),
                ),
                const Divider(color: Colors.white12),
                _calcModeDropdown(draft, (v) => setState(() => draft = draft.copyWith(calcMode: v))),
                _intSlider(
                  label: '最大层级 maxLayer',
                  value: draft.maxLayer,
                  min: 0,
                  max: 9,
                  onChanged: (v) => setState(() => draft = draft.copyWith(maxLayer: v)),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: draft.fractToBiEnabled,
                  onChanged: (v) => setState(() => draft = draft.copyWith(fractToBiEnabled: v ?? true)),
                  title: const Text('分型 -> 笔', style: TextStyle(color: Colors.white70)),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: draft.biToSegEnabled,
                  onChanged: (v) => setState(() => draft = draft.copyWith(biToSegEnabled: v ?? true)),
                  title: const Text('笔 -> 线段', style: TextStyle(color: Colors.white70)),
                ),
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: draft.segToSegsegEnabled,
                  onChanged: (v) => setState(() => draft = draft.copyWith(segToSegsegEnabled: v ?? true)),
                  title: const Text('线段 -> 二段', style: TextStyle(color: Colors.white70)),
                ),
                const Divider(color: Colors.white12),
                for (var i = 0; i < draft.groups.length; i++)
                  _groupTile(i, draft.groups[i], (next) {
                    final groups = List<S13RhythmGroupStyle>.from(draft.groups);
                    groups[i] = next;
                    setState(() => draft = draft.copyWith(groups: groups));
                  }),
                const Divider(color: Colors.white12),
                _hitTile(draft.hit, (next) => setState(() => draft = draft.copyWith(hit: next))),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => setState(() => draft = const S13RhythmDisplaySettings()),
            child: const Text('恢复默认'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft),
            child: const Text('应用'),
          ),
        ],
      ),
    ),
  );
}

Widget _calcModeDropdown(S13RhythmDisplaySettings draft, ValueChanged<String> onChanged) =>
    DropdownButtonFormField<String>(
      value: draft.calcMode,
      dropdownColor: const Color(0xFF20242E),
      decoration: const InputDecoration(
        labelText: 'calcMode',
        labelStyle: TextStyle(color: Colors.white54),
      ),
      style: const TextStyle(color: Colors.white),
      items: const <DropdownMenuItem<String>>[
        DropdownMenuItem(value: 'normal', child: Text('normal')),
        DropdownMenuItem(value: 'transition', child: Text('transition')),
        DropdownMenuItem(value: 'strict1382', child: Text('strict1382')),
      ],
      onChanged: (v) => onChanged(v ?? 'normal'),
    );

Widget _intSlider({
  required String label,
  required int value,
  required int min,
  required int max,
  required ValueChanged<int> onChanged,
}) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$label: $value', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );

Widget _groupTile(int index, S13RhythmGroupStyle style, ValueChanged<S13RhythmGroupStyle> onChanged) =>
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Group ${index + 1}', style: const TextStyle(color: Colors.white70)),
      children: <Widget>[
        _colorDropdown('线颜色', style.lineColor, (v) => onChanged(style.copyWith(lineColor: v))),
        _doubleSlider('线宽', style.lineWidth, 0.4, 5.0, (v) => onChanged(style.copyWith(lineWidth: v))),
        _doubleSlider('文字大小', style.textFontSize, 9.0, 22.0, (v) => onChanged(style.copyWith(textFontSize: v))),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: style.dashed,
          onChanged: (v) => onChanged(style.copyWith(dashed: v)),
          title: const Text('虚线', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );

Widget _hitTile(S13RhythmHitStyle style, ValueChanged<S13RhythmHitStyle> onChanged) =>
    ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: true,
      title: const Text('1.382 命中样式', style: TextStyle(color: Colors.white70)),
      children: <Widget>[
        _colorDropdown('颜色', style.color, (v) => onChanged(style.copyWith(color: v))),
        _doubleSlider('线宽', style.lineWidth, 0.4, 5.0, (v) => onChanged(style.copyWith(lineWidth: v))),
        _doubleSlider('文字大小', style.fontSize, 9.0, 22.0, (v) => onChanged(style.copyWith(fontSize: v))),
        _intSlider(label: 'overflowLimit', value: style.overflowLimit, min: 0, max: 12, onChanged: (v) => onChanged(style.copyWith(overflowLimit: v))),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: style.dashed,
          onChanged: (v) => onChanged(style.copyWith(dashed: v)),
          title: const Text('虚线', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );

Widget _doubleSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('$label: ${value.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Slider(value: value, min: min, max: max, divisions: ((max - min) * 10).round(), onChanged: onChanged),
      ],
    );

Widget _colorDropdown(String label, int value, ValueChanged<int> onChanged) =>
    DropdownButtonFormField<int>(
      value: value,
      dropdownColor: const Color(0xFF20242E),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54)),
      style: const TextStyle(color: Colors.white),
      items: const <DropdownMenuItem<int>>[
        DropdownMenuItem(value: 0xFF9333EA, child: Text('紫色')),
        DropdownMenuItem(value: 0xFF0F766E, child: Text('青绿')),
        DropdownMenuItem(value: 0xFF2563EB, child: Text('蓝色')),
        DropdownMenuItem(value: 0xFFEA580C, child: Text('橙色')),
        DropdownMenuItem(value: 0xFFBE123C, child: Text('红色')),
        DropdownMenuItem(value: 0xFF7C3AED, child: Text('命中紫')),
        DropdownMenuItem(value: 0xFF8AB4FF, child: Text('浅蓝')),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
