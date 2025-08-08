#!/usr/bin/env bash
set -euo pipefail

# Self-healing launcher for MariaDB MCP server
# - Fixes script permissions and CRLF endings
# - Activates virtualenv
# - Loads .env if present
# - Verifies DB TCP reachability (non-fatal)
# - Picks a free SSE port (defaults 9101) and starts server
# - Prints final URL and a ready-to-paste Cursor config snippet

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$PROJECT_ROOT"

# 1) Fix common issues: permissions + CRLF endings
for f in run_sse.sh run_server.sh; do
  if [ -f "$f" ]; then
    sed -i 's/\r$//' "$f" || true
    chmod +x "$f" || true
  fi
done

# 2) Ensure venv exists and activate
if [ ! -f ".venv/bin/activate" ]; then
  echo "Missing virtualenv at .venv. Please create it and install deps first (e.g., 'uv venv && uv pip install -e .')." >&2
  exit 1
fi
source .venv/bin/activate

# 3) Load .env if present (export only valid lines), normalize line endings
set -a
if [ -f .env ]; then
  sed -i 's/\r$//' .env || true
  # shellcheck disable=SC2046,SC2162
  awk 'BEGIN{FS="="} /^[A-Za-z_][A-Za-z0-9_]*=/{print}' .env > .env.export
  # shellcheck disable=SC1091
  source ./.env.export || true
  rm -f .env.export || true
fi
set +a

# 4) Parse args
TRANSPORT="${1:-sse}"  # sse | stdio
if [[ "$TRANSPORT" != "sse" && "$TRANSPORT" != "stdio" ]]; then
  echo "Usage: $0 [sse|stdio] [--port N]" >&2
  exit 1
fi

REQ_PORT=""
if [[ "${2:-}" == "--port" && -n "${3:-}" ]]; then
  REQ_PORT="$3"
fi

HOST="127.0.0.1"

# 5) DB reachability check (non-fatal)
DBH="${DB_HOST:-127.0.0.1}"
DBP="${DB_PORT:-3306}"
python - "$DBH" "$DBP" <<'PY' >/dev/null || true
import socket, sys
host=sys.argv[1]; port=int(sys.argv[2])
s=socket.socket(); s.settimeout(2)
try:
    s.connect((host,port))
    print("DB_OK")
except Exception as e:
    print(f"DB_UNREACHABLE:{e}")
finally:
    try: s.close()
    except Exception: pass
PY

# 6) Start server
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/mcp_server_auto.log"

if [[ "$TRANSPORT" == "sse" ]]; then
  # Find a free port starting from requested or env or default 9101
  START_PORT="${REQ_PORT:-${MCP_SSE_PORT:-9101}}"
  PORT="$START_PORT"
  try_bind() {
    python - "$HOST" "$1" <<'PY'
import socket, sys
host=sys.argv[1]; port=int(sys.argv[2])
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        s.bind((host, port))
    except OSError:
        print("BUSY")
    else:
        print("FREE")
PY
  }

  # Probe up to +50 ports
  limit=50; i=0
  while [[ $i -le $limit ]]; do
    if [[ $(try_bind "$PORT") == "FREE" ]]; then
      break
    fi
    PORT=$((PORT+1)); i=$((i+1))
  done
  if [[ $i -gt $limit ]]; then
    echo "Could not find a free port near $START_PORT" >&2
    exit 1
  fi

  # Launch in background
  nohup python src/server.py --transport sse --host "$HOST" --port "$PORT" >> "$LOG_FILE" 2>&1 &
  pid=$!

  # Wait for port to open (up to ~5s)
  for attempt in {1..10}; do
    if ss -ltnp 2>/dev/null | grep -q ":$PORT\\b"; then
      break
    fi
    sleep 0.5
  done

  if ss -ltnp 2>/dev/null | grep -q ":$PORT\\b"; then
    echo "MCP SSE running on http://localhost:${PORT}/sse (pid $pid)"
    echo "Logs: $LOG_FILE"
    echo "Cursor servers entry:"
    echo '{"servers": {"mariadb-mcp-server": {"url": "http://localhost:'"$PORT"'/sse", "type": "sse"}}}'
    exit 0
  else
    echo "Failed to verify SSE server on port $PORT. See logs: $LOG_FILE" >&2
    exit 1
  fi
else
  # stdio mode: foreground
  exec python src/server.py --transport stdio
fi


