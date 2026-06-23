import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('S13 exposes TICK as a selectable level', () {
    final source = _read('lib/ui/pages/s13_single_stock_replay_page.dart');

    expect(source, contains("static const _levelOptions"));
    expect(source, contains("'TICK',"));
    expect(source, contains("static const _levelOptionSet"));
  });

  test('backend easy_tdx provider routes TICK to get_transactions', () {
    final source = _read('backend/app/easy_tdx_provider.py');

    expect(source, contains('def _get_transactions('));
    expect(
        source,
        contains(
            "return period_name.upper() in {'TICK', 'TRANSACTION', 'TRANSACTIONS'}"));
    expect(source, contains('c.get_transactions'));
    expect(source, contains("'chip_tick_bins': {"));
    expect(source, contains("'source': 'backend_tick_transaction'"));
    expect(source, contains('TICK transactions must be chronological'));
    expect(
        source,
        contains(
            "bars.sort(key=lambda row: str(row.get('dt') or row.get('time') or ''))"));
    expect(source, contains("row['raw_index'] = raw_index"));
  });

  test('chanpy engine maps TICK to a supported calculation container', () {
    final source = _read('backend/app/chanpy_engine.py');

    expect(source, contains('def _chanpy_freq('));
    expect(
        source,
        contains(
            "return 'MIN1' if str(freq).strip().upper() == 'TICK' else freq"));
    expect(
        source, contains('exporter.pick_kl_type(KL_TYPE, _chanpy_freq(freq))'));
  });

  test('multi-level native engine preserves every TICK transaction', () {
    final source = _read('backend/app/a_multilevel_native_engine.py');

    expect(source, contains('def _is_tick_level('));
    expect(source,
        contains("return text in {'TICK', 'TRANSACTION', 'TRANSACTIONS'}"));
    expect(source, contains('TICK preserves every transaction'));
    expect(source, contains("row['raw_index'] = raw_index"));
    expect(source,
        contains('csv_dt = csv_dt.replace(microsecond=min(i, 999999))'));
  });
}
