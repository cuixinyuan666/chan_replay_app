#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'patch failed: {label}, expected 1 match, got {count}')
    return text.replace(old, new, 1)


def main() -> int:
    text = TARGET.read_text(encoding='utf-8')
    if 'chip_history_baseline_levels_fallback' in text:
        print('OK S13 chip history evidence fallback patch already applied')
        return 0

    old = """  Map<String, String> _chipHistorySeedEvidence(ChanSnapshot snapshot) {
    final seed = snapshot.meta['chip_history_seed'];
    if (seed is! Map) {
      return const <String, String>{
        'history_seed_status': 'none',
        'history_seed_level': 'none',
        'history_seed_baseline_source_level': 'none',
        'history_seed_listing_date': 'none',
        'history_seed_calc_start': 'none',
        'history_seed_visible_start': 'none',
        'history_seed_baseline_history_end': 'none',
        'history_seed_baseline_bar_count': '0',
        'history_seed_history_bar_count': '0',
        'history_seed_total_weight': '0',
        'history_seed_includes_first_visible_bar': 'false',
      };
    }
    final meta = Map<String, dynamic>.from(seed);
    return <String, String>{
      'history_seed_status': _chipMetaText(meta, 'status'),
      'history_seed_level': _chipMetaText(meta, 'level'),
      'history_seed_baseline_source_level':
          _chipMetaText(meta, 'baseline_source_level'),
      'history_seed_listing_date': _chipMetaText(meta, 'listing_date'),
      'history_seed_calc_start': _chipMetaText(meta, 'chip_calc_start'),
      'history_seed_visible_start': _chipMetaText(meta, 'visible_start'),
      'history_seed_baseline_history_end':
          _chipMetaText(meta, 'baseline_history_end'),
      'history_seed_baseline_bar_count':
          _chipMetaText(meta, 'baseline_bar_count'),
      'history_seed_history_bar_count':
          _chipMetaText(meta, 'history_bar_count'),
      'history_seed_total_weight': _chipMetaText(meta, 'seed_total_weight'),
      'history_seed_includes_first_visible_bar':
          _chipMetaText(meta, 'seed_includes_first_visible_bar'),
    };
  }
"""
    new = """  Map<String, String> _chipHistorySeedEvidence(ChanSnapshot snapshot) {
    final seed = snapshot.meta['chip_history_seed'];
    final fallbackLevels = _analysis?.meta['chip_history_baseline_levels'];
    final fallbackSeed = fallbackLevels is Map
        ? fallbackLevels[_activeLevel] ??
            fallbackLevels[_activeLevel.toUpperCase()] ??
            fallbackLevels[_activeLevel.toLowerCase()]
        : null;
    final rawMeta = seed is Map ? seed : fallbackSeed;
    if (rawMeta is! Map) {
      final firstBins = snapshot.rawBars.isNotEmpty
          ? snapshot.rawBars.first.chipTickBins
          : null;
      final source = '${firstBins?['source'] ?? ''}'.trim();
      if (source == 'backend_chip_history_seed') {
        return <String, String>{
          'history_seed_status': 'seed_detected_no_meta',
          'history_seed_level': _activeLevel,
          'history_seed_baseline_source_level': 'none',
          'history_seed_listing_date': 'none',
          'history_seed_calc_start': 'none',
          'history_seed_visible_start': snapshot.rawBars.isEmpty
              ? 'none'
              : _chartEvidenceTime(snapshot.rawBars.first.time),
          'history_seed_baseline_history_end': 'none',
          'history_seed_baseline_bar_count': '0',
          'history_seed_history_bar_count': '0',
          'history_seed_total_weight': '0',
          'history_seed_includes_first_visible_bar': 'true',
        };
      }
      return const <String, String>{
        'history_seed_status': 'none',
        'history_seed_level': 'none',
        'history_seed_baseline_source_level': 'none',
        'history_seed_listing_date': 'none',
        'history_seed_calc_start': 'none',
        'history_seed_visible_start': 'none',
        'history_seed_baseline_history_end': 'none',
        'history_seed_baseline_bar_count': '0',
        'history_seed_history_bar_count': '0',
        'history_seed_total_weight': '0',
        'history_seed_includes_first_visible_bar': 'false',
      };
    }
    final meta = Map<String, dynamic>.from(rawMeta);
    final sourceLabel = seed is Map
        ? 'level_meta'
        : 'chip_history_baseline_levels_fallback';
    return <String, String>{
      'history_seed_status': _chipMetaText(meta, 'status'),
      'history_seed_level': _chipMetaText(meta, 'level'),
      'history_seed_baseline_source_level':
          _chipMetaText(meta, 'baseline_source_level'),
      'history_seed_listing_date': _chipMetaText(meta, 'listing_date'),
      'history_seed_calc_start': _chipMetaText(meta, 'chip_calc_start'),
      'history_seed_visible_start': _chipMetaText(meta, 'visible_start'),
      'history_seed_baseline_history_end':
          _chipMetaText(meta, 'baseline_history_end'),
      'history_seed_baseline_bar_count':
          _chipMetaText(meta, 'baseline_bar_count'),
      'history_seed_history_bar_count':
          _chipMetaText(meta, 'history_bar_count'),
      'history_seed_total_weight': _chipMetaText(meta, 'seed_total_weight'),
      'history_seed_includes_first_visible_bar':
          _chipMetaText(meta, 'seed_includes_first_visible_bar'),
      'history_seed_meta_source': sourceLabel,
    };
  }
"""
    text = replace_once(text, old, new, 'replace seed evidence fallback function')

    old = """        'history_seed_includes_first_visible_bar': 'false',
"""
    new = """        'history_seed_includes_first_visible_bar': 'false',
        'history_seed_meta_source': 'none',
"""
    text = replace_once(text, old, new, 'empty meta source map')

    old = """      ..writeln("chip_history_seed_includes_first_visible_bar=${chipEvidence['history_seed_includes_first_visible_bar']}")
      ..writeln()
"""
    new = """      ..writeln("chip_history_seed_includes_first_visible_bar=${chipEvidence['history_seed_includes_first_visible_bar']}")
      ..writeln("chip_history_seed_meta_source=${chipEvidence['history_seed_meta_source']}")
      ..writeln()
"""
    text = replace_once(text, old, new, 'output meta source line')

    TARGET.write_text(text, encoding='utf-8')
    print('OK patched S13 chip history evidence fallback')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
