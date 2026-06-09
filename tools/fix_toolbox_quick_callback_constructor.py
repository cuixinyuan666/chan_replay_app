#!/usr/bin/env python3
from pathlib import Path
import argparse

TARGET = Path('lib/ui/drawing/tradingview_toolbox_host.dart')
START = '  const TradingViewToolboxHost({' 
END = '  });'


def patch(src: str):
    start = src.find(START)
    if start < 0:
        raise RuntimeError('TradingViewToolboxHost constructor start not found')
    end = src.find(END, start)
    if end < 0:
        raise RuntimeError('TradingViewToolboxHost constructor end not found')
    end += len(END)
    block = src[start:end]
    if '    this.onQuickToolAdded,' in block:
        return src, False, 'OK constructor already has onQuickToolAdded'
    anchor = '    this.onChanOverlayToggled,\n'
    if anchor not in block:
        raise RuntimeError('constructor anchor not found')
    block = block.replace(anchor, anchor + '    this.onQuickToolAdded,\n', 1)
    return src[:start] + block + src[end:], True, 'APPLY constructor onQuickToolAdded'


def main():
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--check', action='store_true')
    group.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if not TARGET.exists():
        print(f'FAIL missing {TARGET}')
        return 1
    try:
        target, changed, note = patch(TARGET.read_text(encoding='utf-8'))
    except RuntimeError as exc:
        print(f'FAIL {exc}')
        return 1
    print(f'{TARGET}: {note}')
    if args.apply and changed:
        TARGET.write_text(target, encoding='utf-8')
        print('UPDATED')
    elif args.apply:
        print('NOOP already fixed')
    else:
        print('PASS can apply' if changed else 'PASS already fixed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
