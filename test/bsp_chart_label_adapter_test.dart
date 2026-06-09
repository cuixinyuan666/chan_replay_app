import 'package:chan_replay_app/core/models/bsp.dart';
import 'package:chan_replay_app/ui/widgets/bsp_chart_label_adapter.dart';
import 'package:chan_replay_app/ui/widgets/chart_label_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = BspChartLabelAdapter();

  test('builds bi buy label below anchor', () {
    const bsp = BspPoint(
      index: 0,
      rawIndex: 10,
      price: 9.8,
      type: 'buy1',
      level: 'bi',
    );

    final label = adapter.buildLabel(
      bsp: bsp,
      anchor: const Offset(100, 120),
      isSegLevel: false,
      color: adapter.colorOf(bsp),
    );

    expect(label.text, '笔1');
    expect(label.side, ChartLabelSide.bottom);
    expect(label.priority, ChartLabelPriority.bsp);
    expect(label.rawIndex, 10);
    expect(label.fontSize, 9);
    expect(label.forceVisible, isFalse);
  });

  test('builds seg sell label above anchor and forces visibility', () {
    const bsp = BspPoint(
      index: 1,
      rawIndex: 20,
      price: 11.2,
      type: 'sell2s',
      level: 'seg',
      confirmed: false,
    );

    final label = adapter.buildLabel(
      bsp: bsp,
      anchor: const Offset(120, 80),
      isSegLevel: true,
      color: adapter.colorOf(bsp),
    );

    expect(label.text, '段2s?');
    expect(label.side, ChartLabelSide.top);
    expect(label.fontSize, 10.5);
    expect(label.forceVisible, isTrue);
  });

  test('detects bi and seg levels consistently', () {
    const bi = BspPoint(index: 0, rawIndex: 1, price: 1, type: '1', level: '');
    const seg = BspPoint(
      index: 1,
      rawIndex: 2,
      price: 2,
      type: '1',
      level: 'segment',
    );

    expect(adapter.isBiLevel(bi), isTrue);
    expect(adapter.isSegLevel(bi), isFalse);
    expect(adapter.isSegLevel(seg), isTrue);
    expect(adapter.isBiLevel(seg), isFalse);
  });
}
