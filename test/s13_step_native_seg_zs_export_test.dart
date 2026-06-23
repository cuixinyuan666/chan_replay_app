import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('step compact exporter includes native segment ZS', () {
    final source = _read('backend/app/a_multilevel_native_timed_engine.py');

    expect(source, contains('_export_seg_zs'));
    expect(source, contains('backend_structure_export_seg_zs_ms'));
    expect(source, contains("'seg_zs': seg_zs"));
    expect(source, contains("'seg_zs': structures.get('seg_zs', [])"));
  });

  test('step transport contracts know seg_zs as structure payload', () {
    final main = _read('backend/app/main.py');
    final contract = _read('backend/app/a_replay_contract_hardening.py');

    expect(main, contains("'seg_zs'"));
    expect(contract, contains("'seg_zs'"));
    expect(contract, contains("'segment_zs': 'seg_zs'"));
  });
}
