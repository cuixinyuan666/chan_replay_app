import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('backend exports native segment ZS through chan.py path', () {
    final engine = _read('backend/app/chanpy_engine.py');
    final nativeEngine = _read('backend/app/a_multilevel_native_engine.py');

    expect(engine, contains('def _export_seg_zs('));
    expect(engine, contains('build_level_zs'));
    expect(engine, contains('build_hidden_seg_layer'));
    expect(engine, contains("'seg_zs': _export_seg_zs(level)"));
    expect(engine, contains("'seg_zs': structures.get('seg_zs', [])"));
    expect(nativeEngine, contains("'seg_zs': structures.get('seg_zs', [])"));
  });

  test('transport contracts preserve native segment ZS', () {
    final main = _read('backend/app/main.py');
    final contract = _read('backend/app/a_replay_contract_hardening.py');

    expect(main, contains("'seg_zs'"));
    expect(contract, contains("'seg_zs'"));
    expect(contract, contains("'segment_zs': 'seg_zs'"));
    expect(contract, contains("if 'seg_zs' in transport:"));
  });
}
