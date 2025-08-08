#!/usr/bin/env bash
set -euo pipefail
cd /home/diae/mcp/mariadb-mcp-server
source .venv/bin/activate
exec python src/server.py --transport sse --host 127.0.0.1 --port 9101
