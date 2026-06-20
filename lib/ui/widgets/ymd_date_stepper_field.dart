import 'dart:ui';

import 'package:flutter/material.dart';

/// Compact YYYY-MM-DD date editor with per-year/month/day step buttons.
///
/// It keeps the attached [TextEditingController] as the source of truth so
/// existing request builders can continue reading plain `YYYY-MM-DD` text.
class YmdDateStepperField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final double width;
  final bool enabled;
  final DateTime minDate;
  final DateTime maxDate;

  YmdDateStepperField({
    super.key,
    required this.controller,
    required this.label,
    this.width = 190,
    this.enabled = true,
    DateTime? minDate,
    DateTime? maxDate,
  })  : minDate = minDate ?? DateTime(1990, 1, 1),
        maxDate = maxDate ?? DateTime(2100, 12, 31);

  @override
  State<YmdDateStepperField> createState() => _YmdDateStepperFieldState();
}

class _YmdDateStepperFieldState extends State<YmdDateStepperField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant YmdDateStepperField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChanged);
      widget.controller.addListener(_handleTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChanged);
    super.dispose();
  }

  void _handleTextChanged() {
    if (mounted) setState(() {});
  }

  DateTime get _fallbackDate {
    final now = DateTime.now();
    return _clampDate(DateTime(now.year, now.month, now.day));
  }

  DateTime get _date {
    final parsed = DateTime.tryParse(widget.controller.text.trim());
    if (parsed == null) return _fallbackDate;
    return _clampDate(DateTime(parsed.year, parsed.month, parsed.day));
  }

  DateTime _clampDate(DateTime value) {
    final min = DateTime(
      widget.minDate.year,
      widget.minDate.month,
      widget.minDate.day,
    );
    final max = DateTime(
      widget.maxDate.year,
      widget.maxDate.month,
      widget.maxDate.day,
    );
    if (value.isBefore(min)) return min;
    if (value.isAfter(max)) return max;
    return value;
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  DateTime _safeDate(int year, int month, int day) {
    final normalizedMonth = month.clamp(1, 12).toInt();
    final normalizedDay = day.clamp(
      1,
      _daysInMonth(year, normalizedMonth),
    ).toInt();
    return _clampDate(DateTime(year, normalizedMonth, normalizedDay));
  }

  void _setDate(DateTime next) {
    final text = _fmt(_clampDate(next));
    if (widget.controller.text == text) return;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _stepYear(int delta) {
    if (!widget.enabled) return;
    final d = _date;
    _setDate(_safeDate(d.year + delta, d.month, d.day));
  }

  void _stepMonth(int delta) {
    if (!widget.enabled) return;
    final d = _date;
    final rawMonth = d.month + delta;
    final nextYear = d.year + ((rawMonth - 1) ~/ 12);
    final nextMonth = ((rawMonth - 1) % 12) + 1;
    _setDate(_safeDate(nextYear, nextMonth, d.day));
  }

  void _stepDay(int delta) {
    if (!widget.enabled) return;
    _setDate(_date.add(Duration(days: delta)));
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final d = _date;
    final borderColor = widget.enabled ? Colors.white24 : Colors.white12;
    final textColor = widget.enabled ? Colors.white70 : Colors.white30;
    return SizedBox(
      width: widget.width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1C2330),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    widget.label,
                    style: TextStyle(color: textColor, fontSize: 10.5),
                  ),
                  const Spacer(),
                  Text(
                    _fmt(d),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _DateUnitStepper(
                      label: '年',
                      value: d.year.toString().padLeft(4, '0'),
                      enabled: widget.enabled,
                      onUp: () => _stepYear(1),
                      onDown: () => _stepYear(-1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _DateUnitStepper(
                      label: '月',
                      value: d.month.toString().padLeft(2, '0'),
                      enabled: widget.enabled,
                      onUp: () => _stepMonth(1),
                      onDown: () => _stepMonth(-1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _DateUnitStepper(
                      label: '日',
                      value: d.day.toString().padLeft(2, '0'),
                      enabled: widget.enabled,
                      onUp: () => _stepDay(1),
                      onDown: () => _stepDay(-1),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateUnitStepper extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _DateUnitStepper({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white70 : Colors.white30;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111722),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: enabled ? Colors.white12 : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _tinyButton(Icons.keyboard_arrow_down, enabled ? onDown : null),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: TextStyle(color: color, fontSize: 9.5)),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          _tinyButton(Icons.keyboard_arrow_up, enabled ? onUp : null),
        ],
      ),
    );
  }

  Widget _tinyButton(IconData icon, VoidCallback? onPressed) => SizedBox(
        width: 22,
        height: 34,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 15),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          color: Colors.white54,
          disabledColor: Colors.white12,
          tooltip: null,
        ),
      );
}
