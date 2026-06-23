import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('S13 exposes TICK and TICK_MIN1 as selectable levels', () {
    final source = _read('lib/ui/pages/s13_single_stock_replay_page.dart');

    expect(source, contains("static const _levelOptions"));
    expect(source, contains("'TICK',"));
    expect(source, contains("'TICK_MIN1',"));
    expect(source, contains("static const _levelOptionSet"));
  });

  test('backend easy_tdx provider routes TICK to get_transactions', () {
    final source = _read('backend/app/easy_tdx_provider.py');

    expect(source, contains('def _get_transactions('));
    expect(
        source,
        contains(
            "return period_name.upper() in {'TICK', 'TRANSACTION', 'TRANSACTIONS'}"));
    expect(source, contains("_client_call('get_transactions'"));
    expect(source, contains("'chip_tick_bins': {"));
    expect(source, contains("'source': 'backend_tick_transaction'"));
    expect(source, contains('TICK transactions must be chronological'));
    expect(
        source,
        contains(
            "bars.sort(key=lambda row: str(row.get('dt') or row.get('time') or ''))"));
    expect(source, contains("row['raw_index'] = raw_index"));
  });

  test('backend easy_tdx provider builds TICK_MIN1 from transactions', () {
    final source = _read('backend/app/easy_tdx_provider.py');

    expect(source, contains('def _is_tick_agg_min1_period('));
    expect(source, contains("'TICK_MIN1'"));
    expect(source, contains('def _aggregate_transaction_bars_to_min1('));
    expect(source, contains("'source': 'backend_tick_agg_min1'"));
    expect(source, contains("'tick_agg_period': 'MIN1'"));
    expect(source, contains('if _is_tick_agg_min1_period(period_name) or _is_tick_period(period_name):'));
  });

  test('backend easy_tdx provider supports BJ market for 920 tick requests', () {
    final source = _read('backend/app/easy_tdx_provider.py');

    expect(source, contains(".replace('.BJ', '')"));
    expect(source, contains("if code.startswith(('920', '8', '4')):"));
    expect(source, contains("return 'BJ'"));
    expect(source, contains("requested not in {'SH', 'SZ', 'BJ'}"));
    expect(source, contains("if text == 'BJ':"));
    expect(source, contains("_enum_value(Market, 'BJ')"));
  });

  test('backend easy_tdx provider fetches tick windows by trading day', () {
    final source = _read('backend/app/easy_tdx_provider.py');

    expect(source, contains('def _transaction_date_hints('));
    expect(source, contains('while cur <= anchor_end.date():'));
    expect(source, contains('if cur.weekday() < 5:'));
    expect(source, contains('for date_hint in _transaction_date_hints(start, end):'));
    expect(source, contains('_filter_bars_by_datetime(transaction_bars, start=start, end=end)'));
  });

  test('chanpy engine maps TICK_MIN1 to MIN1 calculation container', () {
    final source = _read('backend/app/chanpy_engine.py');

    expect(source, contains('def _chanpy_freq('));
    expect(source, contains("'TICK_MIN1'"));
    expect(source, contains("'MIN1'"));
    expect(
        source, contains('exporter.pick_kl_type(KL_TYPE, _chanpy_freq(freq))'));
  });

  test('multi-level native engine preserves every raw TICK transaction', () {
    final source = _read('backend/app/a_multilevel_native_engine.py');

    expect(source, contains('def _is_tick_level('));
    expect(source,
        contains("return text in {'TICK', 'TRANSACTION', 'TRANSACTIONS'}"));
    expect(source, contains('TICK preserves every transaction'));
    expect(source, contains("row['raw_index'] = raw_index"));
    expect(source,
        contains('csv_dt = csv_dt.replace(microsecond=min(i, 999999))'));
  });

  test('multi-level native engine treats TICK_MIN1 as intraday minute bars',
      () {
    final source = _read('backend/app/a_multilevel_native_engine.py');

    expect(source, contains('def _is_tick_agg_min1_level('));
    expect(source, contains("'TICKMIN1'"));
    expect(source, contains('if _is_tick_agg_min1_level(level):'));
    expect(source, contains('return 240'));
  });

  test('TICK analyze_multi bypasses chan.py structure calculation', () {
    final source =
        _read('backend/app/a_multilevel_native_timed_recursive_engine.py');

    expect(source, contains('def _is_tick_only_level_order('));
    expect(source, contains('def _tick_chip_only_response('));
    expect(source, contains('native_tick_chip_only'));
    expect(source, contains('native_tick_chan_calculation_skipped'));
    expect(source, contains('TICK chip-only path is active'));
    expect(source, contains('if _is_tick_only_level_order(level_order):'));
  });
  test('TICK_MIN1 native engine maps public level to MIN1 KL_TYPE', () {
    final source = _read('backend/app/a_multilevel_native_engine.py');

    expect(source, contains('def _chanpy_level_for_native('));
    expect(source,
        contains("return 'MIN1' if _is_tick_agg_min1_level(level) else level"));
    expect(
        source,
        contains(
            'exporter.pick_kl_type(KL_TYPE, _chanpy_level_for_native(level))'));
  });

  test('TICK_MIN1 native export preserves full aggregated bars', () {
    final source = _read('backend/app/a_multilevel_native_engine.py');

    expect(source, contains('def _visible_bars_for_level('));
    expect(source, contains('if _is_tick_agg_min1_level(level_name):'));
    expect(source, contains('return list(bars)'));
    expect(
        source,
        contains(
            '_visible_bars_for_level(level, level_obj, bars_by_level[level])'));
  });
}
