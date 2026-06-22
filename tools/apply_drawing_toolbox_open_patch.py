from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S13 = ROOT / 'lib' / 'ui' / 'pages' / 's13_single_stock_replay_page.dart'


def replace_exact(text, old, new, label, expected=1):
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'[abort] {label}: expected {expected}, got {count}')
    return text.replace(old, new, expected)


def main():
    text = S13.read_text(encoding='utf-8')
    original = text

    text = replace_exact(
        text,
        """  DateTime _dateOrDefault(DateTime? value, DateTime fallback) =>
      value ?? fallback;
""",
        """  void _openDrawingToolbox({
    TradingViewDrawingTool tool = TradingViewDrawingTool.trendLine,
  }) {
    _toolboxSelectedToolSignal.value = tool;
    _toolboxOpenSignal.value++;
    final label = tool == TradingViewDrawingTool.trendLine ? '趋势线' : tool.name;
    _showMessage('已打开画线工具：$label，请在K线图上点击锚点。');
  }

  DateTime _dateOrDefault(DateTime? value, DateTime fallback) =>
      value ?? fallback;
""",
        'insert drawing toolbox helper',
    )

    text = replace_exact(
        text,
        """                onPressed: () {
                  _toolboxSelectedToolSignal.value =
                      TradingViewDrawingTool.trendLine;
                  _toolboxOpenSignal.value++;
                },
""",
        """                onPressed: _openDrawingToolbox,
""",
        'sidebar drawing button uses helper',
    )

    text = replace_exact(
        text,
        """                    onPressed: () => _toolboxOpenSignal.value++,
""",
        """                    onPressed: _openDrawingToolbox,
""",
        'unified drawing button uses helper',
    )

    text = replace_exact(
        text,
        """              onToolboxQuickToolAdded: (_) {},
""",
        """""",
        'remove empty quick tool callback',
    )

    if text == original:
        raise SystemExit('[abort] no changes produced')
    S13.write_text(text, encoding='utf-8')
    print('Drawing toolbox open patch applied.')
    print('Next: flutter analyze')


if __name__ == '__main__':
    main()
