from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHART = ROOT / 'lib' / 'ui' / 'widgets' / 'origin_kline_chart.dart'

def replace_exact(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'[abort] {label}: got {count}')
    return text.replace(old, new, 1)

def main():
    text = CHART.read_text(encoding='utf-8')
    original = text
    text = replace_exact(text, '    const bspLabelAdapter = BspChartLabelAdapter();\n', '', 'remove bsp local')
    text = replace_exact(
        text,
        '    if (showBiBsp || showSegBsp)\n      _drawBsp(canvas, rect, start, end, rawToX, priceToY, chartLabels,\n          bspLabelAdapter);\n',
        '    // Near-candle BSP triangles and text are hidden; use bottom BSP band.\n',
        'hide near bsp')
    if text == original:
        raise SystemExit('[abort] no changes')
    CHART.write_text(text, encoding='utf-8')
    print('Near-candle BSP marker/text patch applied.')

if __name__ == '__main__':
    main()
