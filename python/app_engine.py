from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def _bootstrap() -> None:
    root = Path(__file__).resolve().parents[1]
    backend = root / 'backend'
    if str(backend) not in sys.path:
        sys.path.insert(0, str(backend))


def _with_display_indicators(result: dict[str, Any], config: dict[str, Any] | None) -> dict[str, Any]:
    from app.a_indicator_export import build_display_indicators, indicator_source_meta

    bars = result.get('bars')
    if not isinstance(bars, list):
        return result
    patched = dict(result)
    patched['indicators'] = build_display_indicators(bars, config)
    meta = dict(patched.get('meta')) if isinstance(patched.get('meta'), dict) else {}
    sources = dict(meta.get('indicator_sources')) if isinstance(meta.get('indicator_sources'), dict) else {}
    sources.update(indicator_source_meta())
    meta['indicator_sources'] = sources
    patched['meta'] = meta
    frames = patched.get('frames')
    if isinstance(frames, list):
        patched_frames: list[Any] = []
        for frame in frames:
            if not isinstance(frame, dict):
                patched_frames.append(frame)
                continue
            next_frame = dict(frame)
            frame_bars = next_frame.get('bars')
            if isinstance(frame_bars, list):
                next_frame['indicators'] = build_display_indicators(frame_bars, config)
            patched_frames.append(next_frame)
        patched['frames'] = patched_frames
    return patched


def _run_json_request() -> int:
    _bootstrap()
    from app.chanpy_engine import analyze_once, analyze_step

    payload = json.load(sys.stdin)
    mode = str(payload.get('mode') or 'once').lower()
    config = payload.get('config') if isinstance(payload.get('config'), dict) else {}
    kwargs = {
        'symbol': str(payload.get('symbol') or '000001'),
        'market': payload.get('market'),
        'freq': str(payload.get('freq') or 'DAILY'),
        'adjust': str(payload.get('adjust') or 'QFQ'),
        'start': payload.get('start'),
        'end': payload.get('end'),
        'count': int(payload.get('count') or 5000),
        'config': config,
    }
    result = analyze_step(**kwargs) if mode == 'step' else analyze_once(**kwargs)
    json.dump(_with_display_indicators(result, config), sys.stdout, ensure_ascii=False)
    sys.stdout.write('\n')
    return 0


def _run_http(host: str, port: int) -> int:
    _bootstrap()
    import uvicorn

    uvicorn.run('app.main:app', host=host, port=port)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description='origin_vespa_tdx Python chan.py engine')
    parser.add_argument('--json-request', action='store_true', help='read one JSON request from stdin and output one JSON result')
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8000)
    args = parser.parse_args()
    if args.json_request:
        return _run_json_request()
    return _run_http(args.host, args.port)


if __name__ == '__main__':
    raise SystemExit(main())
