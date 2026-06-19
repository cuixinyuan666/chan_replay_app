import 'package:flutter_test/flutter_test.dart';
import 'package:chan_replay_app/core/models/rhythm.dart';
import 'package:chan_replay_app/ui/pages/s13_rhythm_display_settings.dart';

RhythmLine line(
  String source,
  String parent,
  int layer, {
  int roundRef = 1,
}) =>
    RhythmLine(
      id: '$source-$parent-$layer',
      level: 'DAILY',
      sourceKind: source,
      sourceLabel: source,
      parentLevel: parent,
      calcMode: 'normal',
      dir: 'UP',
      displayLabel: 'line',
      labelLeft: 'A',
      labelRight: 'B',
      x1: 1,
      y1: 10,
      x2: 2,
      y2: 11,
      threshold: 12,
      ratio: 0.5,
      thresholdRatio: 1.382,
      roundCurrent: 1,
      roundRef: roundRef,
      layer: layer,
    );

RhythmHit hit() => const RhythmHit(
      id: 'h1',
      lineId: 'l1',
      level: 'DAILY',
      sourceKind: 'fx',
      rawIndex: 1,
      time: null,
      price: 12,
      threshold: 12,
      dir: 'UP',
      displayLabel: 'hit',
      detail: '',
    );

void main() {
  test('filters rhythm line mappings and max layer', () {
    final settings = const S13RhythmDisplaySettings(
      fractToBiEnabled: false,
      biToSegEnabled: true,
      segToSegsegEnabled: false,
      maxLayer: 2,
    );

    expect(settings.lineVisible(line('fx', 'bi', 1)), isFalse);
    expect(settings.lineVisible(line('bi', 'seg', 2)), isTrue);
    expect(settings.lineVisible(line('seg', 'segseg', 1)), isFalse);
    expect(settings.lineVisible(line('bi', 'seg', 3)), isFalse);
  });

  test('returns group and hit drawing styles', () {
    final settings = const S13RhythmDisplaySettings();
    final style = settings.lineStyle(line('bi', 'seg', 2));
    final hitStyle = settings.hitStyle(hit());

    expect(
        style.colorValue, S13RhythmDisplaySettings.defaultGroups[1].lineColor);
    expect(style.dashed, S13RhythmDisplaySettings.defaultGroups[1].dashed);
    expect(hitStyle.colorValue, settings.hit.color);
    expect(settings.hitText(hit()), '1.382 hit');
  });

  test('uses one color and line style for the same rhythm group', () {
    const settings = S13RhythmDisplaySettings();
    final first = settings.lineStyle(
      line('fx', 'bi', 0, roundRef: 2),
    );
    final laterLayer = settings.lineStyle(
      line('fx', 'bi', 4, roundRef: 2),
    );

    expect(first.colorValue, laterLayer.colorValue);
    expect(first.strokeWidth, laterLayer.strokeWidth);
    expect(first.dashed, laterLayer.dashed);
  });

  test('exports the selected backend calculation mode and enable switch', () {
    const settings = S13RhythmDisplaySettings(
      enabled: false,
      calcMode: 'strict1382',
    );

    expect(settings.backendCalculationConfig, <String, dynamic>{
      'enable_rhythm_1382': false,
      'rhythm_calc_mode': 'strict1382',
    });
  });

  test('max layer zero keeps only current-round lines', () {
    const settings = S13RhythmDisplaySettings(maxLayer: 0);

    expect(settings.lineVisible(line('bi', 'seg', 0)), isTrue);
    expect(settings.lineVisible(line('bi', 'seg', 1)), isFalse);
  });
}
