import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('S13 段中枢可见性链路诊断', () {
    test('页面层：段中枢开关目前接到原生 ZS，2段/N段接到递归中枢层', () {
      final page = _read('lib/ui/pages/s13_single_stock_replay_page.dart');

      expect(
        page,
        contains('showZs: _showNativeZs'),
        reason: '页面里的“段中枢”开关现在实际传给 RecursiveSegOriginKlineChart.showZs。',
      );
      expect(
        page,
        contains('visibleRecursiveSegZsLayers'),
        reason: '2段/N段中枢应通过 visibleRecursiveSegZsLayers 控制递归层中枢。',
      );
      expect(
        page,
        contains('if (_showSeg2Zs) 2'),
        reason: '2段中枢开关应显式打开 layer=2。',
      );
      expect(
        page,
        contains('if (_showSegNZs)'),
        reason: 'N段中枢开关应显式打开 layer>=3。',
      );
    });

    test('模型层：ChanSnapshot 已预留 segZss 字段', () {
      final model = _read('lib/core/models/chan_snapshot.dart');

      expect(model, contains('final List<ZS> segZss;'));
      expect(model, contains('this.segZss = const []'));
    });

    test('解析层：后端段中枢必须写入 ChanSnapshot.segZss', () {
      final parser = _read('lib/data/chan_snapshot_json_parser.dart');

      expect(
        parser,
        contains('segZss:'),
        reason: '当前问题定位点：ChanSnapshot 有 segZss 字段，但解析器没有把后端段中枢写入 segZss。'
            '这会导致前端即使有“段中枢”开关，也没有段中枢数据可画。'
            '修复方向：解析 seg_zs/segZs/seg_zss/segZss 等后端字段，并在 ChanSnapshot(...) 中传入 segZss。',
      );
    });

    test('适配层：原生段中枢使用 segZss 生成 DrawingObject', () {
      final recursiveChart =
          _read('lib/ui/widgets/recursive_seg_origin_kline_chart.dart');

      expect(recursiveChart, contains('_nativeSegZsDrawingObjects'));
      expect(recursiveChart, contains('snapshot.segZss'));
      expect(recursiveChart, contains("text: '段中枢'"));
    });

    test('递归层：2段/N段中枢链路存在，用于对照', () {
      final recursiveChart =
          _read('lib/ui/widgets/recursive_seg_origin_kline_chart.dart');

      expect(recursiveChart, contains('_recursiveSegZsDrawingObjects'));
      expect(recursiveChart, contains('snapshot.recursiveSegZss.entries'));
      expect(recursiveChart, contains('visibleRecursiveSegZsLayers'));
      expect(recursiveChart, contains("text: '\$layer段中枢'"));
    });
  });
}
