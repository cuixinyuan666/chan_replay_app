#!/usr/bin/env python3
"""Offline checks for A-share symbol/market normalization."""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from backend.app.easy_tdx_provider import infer_market, normalize_market, normalize_symbol  # noqa: E402


def assert_eq(left: object, right: object, message: str) -> None:
    if left != right:
        raise AssertionError(f'{message}: {left!r} != {right!r}')


def main() -> int:
    assert_eq(normalize_symbol('600340.SH'), '600340', 'normalize SH suffix')
    assert_eq(normalize_symbol('000001.SZ'), '000001', 'normalize SZ suffix')
    assert_eq(infer_market('600340'), 'SH', '600xxx should infer SH')
    assert_eq(infer_market('000001'), 'SZ', '000xxx should infer SZ')
    assert_eq(normalize_market('600340', 'SZ'), 'SH', '600340 + stale SZ should correct to SH')
    assert_eq(normalize_market('000001', 'SH'), 'SZ', '000001 + stale SH should correct to SZ')
    assert_eq(normalize_market('600340.SH', None), 'SH', 'suffix SH should infer SH')
    assert_eq(normalize_market('000001.SZ', None), 'SZ', 'suffix SZ should infer SZ')
    print('PASS: market normalization contract')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
