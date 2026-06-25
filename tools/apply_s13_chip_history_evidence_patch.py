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

    if 'chip_history_seed_status=' in text:
        print('OK S13 chip history evidence patch already applied')
        return 0

    helper_anchor = """  String _chipTargetSource(ChanSnapshot snapshot, int targetIndex) {
    if (_hasStepFrames) {
      final maxAllowed =
          _safeFrameIndex.clamp(0, snapshot.rawBars.length - 1).toInt();
      if (_crosshairIndex != null && _crosshairIndex! <= maxAllowed) {
        return 'step_crosshair';
      }
      if (_crosshairIndex != null && _crosshairIndex! > maxAllowed) {
        return 'step_clamped';
      }
      return 'step_frame';
    }
    if (_crosshairIndex != null) return 'crosshair';
    if (_viewEndIndex != null) return 'view_end';
    return 'last_bar';
  }

"""
    helper_block = helper_anchor + """  String _chipMetaText(Map<String, dynamic>? meta, String key) {
    if (meta == null) return 'none';
    final value = meta[key];
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? 'none' : text;
  }

  Map<String, String> _chipHistorySeedEvidence(ChanSnapshot snapshot) {
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
      'history_seed_history_bar_count': _chipMetaText(meta, 'history_bar_count'),
      'history_seed_total_weight': _chipMetaText(meta, 'seed_total_weight'),
      'history_seed_includes_first_visible_bar':
          _chipMetaText(meta, 'seed_includes_first_visible_bar'),
    };
  }

"""
    text = replace_once(text, helper_anchor, helper_block, 'insert chip history helper')

    empty_anchor = """        'step_no_future': 'true',
"""
    empty_block = """        'step_no_future': 'true',
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
"""
    text = replace_once(text, empty_anchor, empty_block, 'empty chip history evidence defaults')

    target_anchor = """    final targetBar = snapshot.rawBars[targetIndex];
"""
    target_block = """    final targetBar = snapshot.rawBars[targetIndex];
    final seedEvidence = _chipHistorySeedEvidence(snapshot);
"""
    text = replace_once(text, target_anchor, target_block, 'seed evidence local variable')

    return_anchor = """      'step_no_future': '$stepNoFuture',
"""
    return_block = """      'step_no_future': '$stepNoFuture',
      ...seedEvidence,
"""
    text = replace_once(text, return_anchor, return_block, 'return seed evidence map')

    output_anchor = """      ..writeln("chip_step_no_future=${chipEvidence['step_no_future']}")
      ..writeln()
"""
    output_block = """      ..writeln("chip_step_no_future=${chipEvidence['step_no_future']}")
      ..writeln("chip_history_seed_status=${chipEvidence['history_seed_status']}")
      ..writeln("chip_history_seed_level=${chipEvidence['history_seed_level']}")
      ..writeln("chip_history_seed_baseline_source_level=${chipEvidence['history_seed_baseline_source_level']}")
      ..writeln("chip_history_seed_listing_date=${chipEvidence['history_seed_listing_date']}")
      ..writeln("chip_history_seed_calc_start=${chipEvidence['history_seed_calc_start']}")
      ..writeln("chip_history_seed_visible_start=${chipEvidence['history_seed_visible_start']}")
      ..writeln("chip_history_seed_baseline_history_end=${chipEvidence['history_seed_baseline_history_end']}")
      ..writeln("chip_history_seed_baseline_bar_count=${chipEvidence['history_seed_baseline_bar_count']}")
      ..writeln("chip_history_seed_history_bar_count=${chipEvidence['history_seed_history_bar_count']}")
      ..writeln("chip_history_seed_total_weight=${chipEvidence['history_seed_total_weight']}")
      ..writeln("chip_history_seed_includes_first_visible_bar=${chipEvidence['history_seed_includes_first_visible_bar']}")
      ..writeln()
"""
    text = replace_once(text, output_anchor, output_block, 'output seed evidence lines')

    TARGET.write_text(text, encoding='utf-8')
    print('OK patched S13 chip history evidence fields')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
