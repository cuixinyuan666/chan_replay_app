#!/usr/bin/env bash
# Validate research backend, other-target flow, native chan features, segN presets, and structure-source rules.
# Designed for Git Bash / MINGW64 on Windows and regular bash on Linux/macOS.

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

PYTHON_BIN="${PYTHON_BIN:-python}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-60}"
VALIDATE_TIMEOUT="${VALIDATE_TIMEOUT:-300}"

BACKEND_PID=""
PORT=""
LOG_DIR="$ROOT_DIR/.tmp"
mkdir -p "$LOG_DIR"

cleanup() {
  if [[ -n "${BACKEND_PID:-}" ]]; then
    kill "$BACKEND_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

fail() {
  echo "[FAIL] $*" >&2
  if [[ -n "${PORT:-}" && -f "$LOG_DIR/chan_research_backend_${PORT}.log" ]]; then
    echo "----- backend log: $LOG_DIR/chan_research_backend_${PORT}.log -----" >&2
    cat "$LOG_DIR/chan_research_backend_${PORT}.log" >&2
    echo "----- end backend log -----" >&2
  fi
  exit 1
}

step() {
  echo
  echo "========== $* =========="
}

step "git pull"
git pull origin hichan || fail "git pull failed"

step "python syntax check"
PYTHONPATH=. "$PYTHON_BIN" -m py_compile \
  backend/app/a_bsp_feature_engine.py \
  backend/app/a_ml_bridge.py \
  backend/app/a_seg_composite_strategy.py \
  tools/validate_research_api_routes_contract.py \
  tools/validate_research_other_target_flow.py \
  tools/validate_research_native_feature_columns.py \
  tools/validate_seg_composite_presets.py \
  tools/validate_structure_source_rules.py \
  || fail "python syntax check failed"

step "pick free backend port"
PORT="$(PYTHONPATH=. "$PYTHON_BIN" - <<'PY'
import socket
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind(('127.0.0.1', 0))
    print(s.getsockname()[1])
PY
)"
[[ -n "$PORT" ]] || fail "failed to pick backend port"
export PORT
BASE_URL="http://127.0.0.1:${PORT}"
LOG_FILE="$LOG_DIR/chan_research_backend_${PORT}.log"
echo "Using backend port: $PORT"
echo "Backend log: $LOG_FILE"

step "start backend"
PYTHONPATH=. "$PYTHON_BIN" -m uvicorn backend.app.main:app \
  --host 127.0.0.1 \
  --port "$PORT" \
  > "$LOG_FILE" 2>&1 &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

step "wait backend health"
READY=0
for i in $(seq 1 "$STARTUP_TIMEOUT"); do
  if ! kill -0 "$BACKEND_PID" >/dev/null 2>&1; then
    fail "backend process exited before becoming healthy"
  fi
  if PYTHONPATH=. "$PYTHON_BIN" - "$PORT" <<'PY' >/dev/null 2>&1
import json
import sys
import urllib.request
port = sys.argv[1]
with urllib.request.urlopen(f'http://127.0.0.1:{port}/health', timeout=2) as r:
    data = json.loads(r.read().decode('utf-8'))
assert data.get('ok') is True
assert data.get('research_api') is True
assert data.get('backend') == 'origin_vespa_tdx'
PY
  then
    READY=1
    break
  fi
  sleep 1
done
[[ "$READY" == "1" ]] || fail "backend did not become healthy at $BASE_URL"
echo "Backend healthy: $BASE_URL"

step "validate other-target research flow"
PYTHONPATH=. "$PYTHON_BIN" tools/validate_research_other_target_flow.py \
  --base-url "$BASE_URL" \
  --timeout "$VALIDATE_TIMEOUT" \
  || fail "other-target research flow validation failed"

step "validate native chan feature columns"
PYTHONPATH=. "$PYTHON_BIN" tools/validate_research_native_feature_columns.py \
  --base-url "$BASE_URL" \
  --timeout "$VALIDATE_TIMEOUT" \
  || fail "native chan feature column validation failed"

step "validate segN preset rules"
PYTHONPATH=. "$PYTHON_BIN" tools/validate_seg_composite_presets.py \
  --base-url "$BASE_URL" \
  --timeout "$VALIDATE_TIMEOUT" \
  --require-loose-signal \
  || fail "segN preset validation failed"

step "validate structure source rules"
PYTHONPATH=. "$PYTHON_BIN" tools/validate_structure_source_rules.py \
  --base-url "$BASE_URL" \
  --timeout "$VALIDATE_TIMEOUT" \
  || fail "structure source rule validation failed"

step "done"
echo "[OK] research stack validation passed"
