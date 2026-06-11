# Windows App-Bundled Python Runtime

The Windows app must use the Python runtime bundled with the app. Normal app
workflows must not start system Python, Conda Python, Windows Store Python,
`python3`, `py -3`, or any other external interpreter.

## Runtime Layout

```text
chan_replay_app/
  python/
    python.exe
    python311.dll
    python311.zip
    Lib/
    Scripts/
    app_engine.py
    requirements-windows.txt
    chan.py/
  backend/
    app/
```

Packaged Windows builds install these directories under:

```text
<app-exe-dir>/data/python/
<app-exe-dir>/data/backend/
```

## Startup Rule

The Flutter app starts:

```text
data/python/python.exe data/python/app_engine.py --host 127.0.0.1 --port <free-port>
```

There is no fallback interpreter. If `data/python/python.exe` or
`data/python/app_engine.py` is missing, the workflow is blocked and the app
should show/copy diagnostics instead of asking the user to start a backend
manually.

## Required Backend Endpoints

The App-managed backend must expose:

```text
/health
/api/chan/analyze
/api/chan/analyze_bars
/api/chan/analyze_multi
/api/scanner/bsp/scan
/api/scanner/bsp/scan_stream
/api/research/bsp/features
/api/research/ml/score
/api/research/backtest
/api/research/pipeline
```

Multi-level replay and Scan Signal require `/api/chan/analyze_multi`. If the
bundled backend cannot expose it, the task is blocked.

## Development Smoke Checks

These commands are for development checks only:

```powershell
.\python\python.exe .\python\app_engine.py --help
.\python\python.exe .\python\app_engine.py --host 127.0.0.1 --port 8000
```

They do not define the accepted user workflow. The accepted workflow is the app
starting and managing bundled Python automatically.
