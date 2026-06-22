from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ORIGIN = ROOT / 'lib' / 'ui' / 'widgets' / 'origin_kline_chart.dart'
RECURSIVE = ROOT / 'lib' / 'ui' / 'widgets' / 'recursive_seg_origin_kline_chart.dart'
RESEARCH = ROOT / 'lib' / 'ui' / 'pages' / 'research_backtest_page.dart'
TEST = ROOT / 'test' / 'recursive_seg_label_test.dart'


def replace_exact(text, old, new, label, expected=1):
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'[abort] {label}: expected {expected}, got {count}')
    return text.replace(old, new, expected)


def patch_origin():
    text = ORIGIN.read_text(encoding='utf-8')
    original = text
    text = replace_exact(
        text,
        '    const bspLabelAdapter = BspChartLabelAdapter();\n',
        '',
        'remove near BSP label adapter local',
    )
    text = replace_exact(
        text,
        '    if (showBiBsp || showSegBsp)\n      _drawBsp(canvas, rect, start, end, rawToX, priceToY, chartLabels,\n          bspLabelAdapter);\n',
        '    // Near-candle BSP triangles and text are hidden; use the bottom BSP band.\n',
        'hide near BSP triangles and text',
    )
    if text == original:
        raise SystemExit('[abort] origin chart no changes')
    ORIGIN.write_text(text, encoding='utf-8')


def patch_recursive():
    text = RECURSIVE.read_text(encoding='utf-8')
    original = text
    text = replace_exact(
        text,
        "import '../../core/settings/level_promoter_settings.dart';\n",
        '',
        'remove level promoter import',
    )
    text = replace_exact(
        text,
        """  int get _effectiveMaxRecursiveSegLayer {
    final explicit = maxRecursiveSegLayer;
    if (explicit != null && explicit >= 2) return explicit;
    return LevelPromoterSettings.currentMaxLayer;
  }
""",
        """  int get _effectiveMaxRecursiveSegLayer {
    final explicit = maxRecursiveSegLayer;
    if (explicit != null && explicit >= 2) return explicit;
    var discovered = 1;
    for (final layer in <int>[
      ...snapshot.recursiveSegLayers.keys,
      ...snapshot.recursiveSegBsps.keys,
      ...snapshot.recursiveSegBspCandidates.keys,
      ...snapshot.recursiveSegZss.keys,
    ]) {
      if (layer > discovered) discovered = layer;
    }
    return discovered >= 2 ? discovered : 2;
  }
""",
        'auto discover recursive max layer',
    )
    if text == original:
        raise SystemExit('[abort] recursive chart no changes')
    RECURSIVE.write_text(text, encoding='utf-8')


def patch_research():
    text = RESEARCH.read_text(encoding='utf-8')
    original = text
    text = replace_exact(
        text,
        """  static const _levels = ['MIN1', 'MIN5', 'MIN15', 'MIN30', 'MIN60', 'DAILY'];
  static const _types = ['1', '1p', '2', '2s', '3a', '3b'];
""",
        """  static const _levels = ['MIN1', 'MIN5', 'MIN15', 'MIN30', 'MIN60', 'DAILY'];
  static const _types = ['1', '1p', '2', '2s', '3a', '3b'];
  static const _otherLayerValue = -1;
""",
        'add other layer sentinel',
    )
    text = replace_exact(
        text,
        """    return Row(
      children: [
        SizedBox(
          width: 105,
          child: DropdownButtonFormField<int>(
            initialValue: row.layer,
            decoration: const InputDecoration(labelText: '结构层'),
            items: [
              for (var layer = 2; layer <= 6; layer++)
                DropdownMenuItem(value: layer, child: Text('$layer段')),
            ],
            onChanged: (value) {
              if (value != null) {
                row.layer = value;
                onChanged();
              }
            },
          ),
        ),
""",
        """    return Row(
      children: [
        SizedBox(
          width: row.layer > 6 ? 190 : 105,
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue:
                      row.layer >= 2 && row.layer <= 6 ? row.layer : _otherLayerValue,
                  decoration: const InputDecoration(labelText: '结构层'),
                  items: [
                    for (var layer = 2; layer <= 6; layer++)
                      DropdownMenuItem(value: layer, child: Text('$layer段')),
                    const DropdownMenuItem(value: _otherLayerValue, child: Text('other')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      row.layer = value == _otherLayerValue
                          ? (row.layer > 6 ? row.layer : 7)
                          : value;
                      onChanged();
                    }
                  },
                ),
              ),
              if (row.layer > 6) const SizedBox(width: 8),
              if (row.layer > 6)
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    key: ValueKey('seg-layer-${row.hashCode}-${row.layer}'),
                    initialValue: '${row.layer}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'N段'),
                    onChanged: (value) {
                      final next = int.tryParse(value.trim());
                      if (next != null && next >= 2) {
                        row.layer = next;
                        onChanged();
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
""",
        'add other/manual layer editor',
    )
    if text == original:
        raise SystemExit('[abort] research page no changes')
    RESEARCH.write_text(text, encoding='utf-8')


def patch_test():
    text = TEST.read_text(encoding='utf-8')
    original = text
    text = replace_exact(
        text,
        "import 'package:chan_replay_app/ui/widgets/recursive_seg_origin_kline_chart.dart';\n",
        "import 'package:chan_replay_app/ui/widgets/recursive_seg_origin_kline_chart.dart';\nimport 'package:chan_replay_app/ui/widgets/bsp_chart_label_adapter.dart';\n",
        'add label adapter test import',
    )
    text = replace_exact(
        text,
        """    expect(recursiveSegBspLabel(2, 'B3a'), '2段3a');
    expect(recursiveSegBspLabel(3, 'S3B'), '3段3b');
    expect(recursiveSegBspLabel(4, 'buy1p'), '4段1p');
""",
        """    expect(recursiveSegBspLabel(2, 'B3a'), '2段B3a');
    expect(recursiveSegBspLabel(3, 'S3B'), '3段S3B');
    expect(recursiveSegBspLabel(4, 'buy1p'), '4段B1p');
""",
        'update recursive label expectations',
    )
    text = replace_exact(
        text,
        """  test('real recursive BSP supersedes endpoint candidate on same bar', () {
""",
        """  test('near-candle and bottom BSP labels share type body formatter', () {
    const buy = BspPoint(
      index: 0,
      rawIndex: 10,
      price: 1,
      type: 'buy3a',
      buy: true,
    );
    const sell = BspPoint(
      index: 1,
      rawIndex: 11,
      price: 1,
      type: '卖2',
      buy: false,
    );
    expect(BspChartLabelAdapter.displayTypeFor(buy), 'B3a');
    expect(BspChartLabelAdapter.labelTextFor(levelPrefix: '笔', bsp: buy), '笔B3a');
    expect(BspChartLabelAdapter.labelTextFor(levelPrefix: '2段', bsp: buy), '2段B3a');
    expect(BspChartLabelAdapter.displayTypeFor(sell), 'S2');
    expect(BspChartLabelAdapter.labelTextFor(levelPrefix: '段', bsp: sell), '段S2');
  });

  test('real recursive BSP supersedes endpoint candidate on same bar', () {
""",
        'add shared type formatter test',
    )
    if text == original:
        raise SystemExit('[abort] test no changes')
    TEST.write_text(text, encoding='utf-8')


def main():
    patch_origin()
    patch_recursive()
    patch_research()
    patch_test()
    print('BSP display policy patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
