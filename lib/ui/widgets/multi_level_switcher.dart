import 'package:flutter/material.dart';

class MultiLevelSwitcher extends StatelessWidget {
  final List<String> levels;
  final String activeLevel;
  final ValueChanged<String> onChanged;
  final String title;
  final bool enabled;

  const MultiLevelSwitcher({
    super.key,
    required this.levels,
    required this.activeLevel,
    required this.onChanged,
    this.title = '级别',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cleanLevels = [
      for (final level in levels)
        if (level.trim().isNotEmpty) level.trim().toUpperCase(),
    ];
    if (cleanLevels.isEmpty) return const SizedBox.shrink();

    final selected = cleanLevels.contains(activeLevel.toUpperCase())
        ? activeLevel.toUpperCase()
        : cleanLevels.first;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final level in cleanLevels)
                ChoiceChip(
                  label: Text(level),
                  selected: level == selected,
                  onSelected: enabled ? (_) => onChanged(level) : null,
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(
                    color: level == selected ? Colors.black : Colors.white70,
                    fontSize: 12,
                    fontWeight:
                        level == selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  selectedColor: const Color(0xFFFFD54F),
                  backgroundColor: const Color(0xFF20242E),
                  disabledColor: const Color(0xFF161A22),
                  side: BorderSide(
                    color: level == selected
                        ? const Color(0xFFFFD54F)
                        : Colors.white24,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
