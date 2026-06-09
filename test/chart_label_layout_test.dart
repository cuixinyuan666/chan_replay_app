import 'package:chan_replay_app/ui/widgets/chart_label_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('places high priority labels without overlap', () {
    final layout = ChartLabelLayout(
      chartRect: const Rect.fromLTWH(0, 0, 240, 160),
      visibleCount: 100,
    );

    final labels = <ChartLabel>[
      const ChartLabel(
        text: '笔1',
        anchor: Offset(100, 80),
        side: ChartLabelSide.bottom,
        priority: ChartLabelPriority.bsp,
        rawIndex: 10,
        color: Colors.green,
      ),
      const ChartLabel(
        text: '段1',
        anchor: Offset(100, 80),
        side: ChartLabelSide.bottom,
        priority: ChartLabelPriority.bsp,
        rawIndex: 11,
        color: Colors.green,
      ),
    ];

    final laidOut = layout.layout(labels);

    expect(laidOut, hasLength(2));
    expect(laidOut[0].rect.overlaps(laidOut[1].rect), isFalse);
  });

  test('keeps labels inside chart bounds', () {
    final chartRect = const Rect.fromLTWH(10, 20, 120, 80);
    final layout = ChartLabelLayout(chartRect: chartRect, visibleCount: 60);

    final laidOut = layout.layout(<ChartLabel>[
      const ChartLabel(
        text: '边界标签',
        anchor: Offset(8, 18),
        side: ChartLabelSide.top,
        priority: ChartLabelPriority.bsp,
        rawIndex: 1,
        color: Colors.red,
      ),
    ]);

    expect(laidOut, hasLength(1));
    final rect = laidOut.single.rect;
    expect(rect.left >= chartRect.left, isTrue);
    expect(rect.top >= chartRect.top, isTrue);
    expect(rect.right <= chartRect.right, isTrue);
    expect(rect.bottom <= chartRect.bottom, isTrue);
  });

  test('filters low priority labels in dense windows', () {
    final layout = ChartLabelLayout(
      chartRect: const Rect.fromLTWH(0, 0, 300, 200),
      visibleCount: 1000,
    );

    final laidOut = layout.layout(<ChartLabel>[
      const ChartLabel(
        text: 'FX',
        anchor: Offset(50, 50),
        side: ChartLabelSide.top,
        priority: ChartLabelPriority.fx,
        rawIndex: 5,
        color: Colors.orange,
      ),
      const ChartLabel(
        text: 'BSP',
        anchor: Offset(100, 100),
        side: ChartLabelSide.bottom,
        priority: ChartLabelPriority.bsp,
        rawIndex: 8,
        color: Colors.green,
      ),
    ]);

    expect(laidOut.map((item) => item.label.text), contains('BSP'));
    expect(laidOut.map((item) => item.label.text), isNot(contains('FX')));
  });
}
