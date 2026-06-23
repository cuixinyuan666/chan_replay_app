import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('S13 一键复制状态证据包含时间范围字段', () {
    final page = _read('lib/ui/pages/s13_single_stock_replay_page.dart');

    expect(page, contains('_visibleWindowTimeRange'));
    expect(page, contains('visible_window_time_range='));
    expect(page, contains('active_data_time_range='));
    expect(page, contains('active_bi_zs_time_sample='));
    expect(page, contains('active_seg_zs_time_sample='));
    expect(page, contains('recursive_zs_time_sample='));
    expect(page, contains('recursive_real_bsp_time_sample='));
  });
}
