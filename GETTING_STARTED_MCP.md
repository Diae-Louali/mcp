## MCP MariaDB — Getting Started

This guide shows how to use the MariaDB MCP server with Cursor against your local DB.

### One-time setup (already done)

- Repo: `/home/diae/mcp/mariadb-mcp-server`
- Virtualenv: `.venv` (Python 3.11)
- Config: `.env` points to `127.0.0.1:3308` with your credentials
- Runner scripts:
  - `run_server.sh` (stdio)
  - `run_sse.sh` (SSE)
- Cursor config (SSE):
  - Add under top-level `servers`:
    ```json
    {
      "servers": {
        "mariadb-mcp-server": {
          "url": "http://localhost:9101/sse",
          "type": "sse"
        }
      }
    }
    ```

### Daily workflow (SSE mode)

1. Ensure DB is running in Docker (port 3308):
   - From project root: `docker compose -f /home/diae/projects/hrsuite-cloud/docker-compose.yaml up -d db`
2. Start the MCP server (SSE) in WSL:
   - `/home/diae/mcp/mariadb-mcp-server/run_sse.sh`
3. In Cursor:
   - Reload MCP servers or restart Cursor
   - You should see tools like `list_databases`, `list_tables`, `execute_sql`
4. Optional checks:
   - Verify port: `ss -ltnp | grep ":9101"`
   - Tail logs: `tail -f /home/diae/mcp/mariadb-mcp-server/logs/mcp_server.log`

To stop the SSE server:

- `pkill -f "/home/diae/mcp/mariadb-mcp-server/src/server.py"`

### Alternative: stdio mode (Cursor launches it)

- Use this entry under `mcpServers` in `C:\\Users\\diae\\.cursor\\mcp.json`:
  ```json
  "MariaDB_Server": {
    "command": "C:\\Windows\\System32\\wsl.exe",
    "args": [
      "bash",
      "-lc",
      "/home/diae/mcp/mariadb-mcp-server/run_server.sh"
    ],
    "timeout": 600
  }
  ```
- In stdio mode, Cursor starts/stops the server automatically. No manual start needed.

### Changing port (SSE)

- Edit `/home/diae/mcp/mariadb-mcp-server/run_sse.sh` and change `--port 9101` to another free port
- Update Cursor `servers` URL to match (e.g., `http://localhost:9201/sse`)

### Enabling embeddings (optional)

Add to `.env` and restart the server:

- OpenAI: `EMBEDDING_PROVIDER=openai`, `OPENAI_API_KEY=...`
- Gemini: `EMBEDDING_PROVIDER=gemini`, `GEMINI_API_KEY=...`
- HuggingFace: `EMBEDDING_PROVIDER=huggingface`, `HF_MODEL=BAAI/bge-m3` (or other)

### Troubleshooting

- Port in use on 9001/9101: pick another port and update Cursor URL
- DB not reachable: ensure Docker `db` service is running and port `3308` is published
- Windows ENOENT for WSL (stdio mode): use `C:\\Windows\\System32\\wsl.exe` in Cursor config
- View logs: `/home/diae/mcp/mariadb-mcp-server/logs/mcp_server.log`

### Quick commands

- Start DB only:
  - `docker compose -f /home/diae/projects/hrsuite-cloud/docker-compose.yaml up -d db`
- Start MCP (SSE):
  - `/home/diae/mcp/mariadb-mcp-server/run_sse.sh`
- Check listening port:
  - `ss -ltnp | grep ":9101"`
- Stop MCP:
  - `pkill -f "/home/diae/mcp/mariadb-mcp-server/src/server.py"`

### Errors I had but solved

- **SSE server wasn’t running** when Cursor tried to connect to `http://localhost:9101/sse`, so you got ECONNREFUSED.
- Your logs showed earlier runs in **stdio** mode (“Starting MCP server via stdio…”), not SSE.
- After we started SSE properly, port `9101` began listening and Cursor connected.

### Contributing factors we fixed

- **Runner script**: Updated `run_sse.sh` to `cd` into the project, activate the venv, and `exec` the server so `.env` is reliably loaded and the process stays attached.
- **Permissions**: Ensured the scripts are executable.
- **Race on checks**: Early port checks right after starting the process can be too fast; the server needs ~1s to bind.

### How to avoid it next time

- Start DB, then run `/home/diae/mcp/mariadb-mcp-server/run_sse.sh`.
- Don’t run stdio and SSE for the same server at the same time.
- If Cursor is using SSE, make sure the SSE process is up before reloading servers.

- SSE now listens on `127.0.0.1:9101`; logs at `/home/diae/mcp/mariadb-mcp-server/logs/mcp_server.log`.

### Gneral troubleshooting

- If you get `ECONNREFUSED` when trying to connect to the SSE server, check:
  - The server is running (port `9101` is listening)
  - The server is configured correctly in Cursor (check `servers` in `C:\\Users\\diae\\.cursor\\mcp.json`)
  - The server is using the correct port (check `run_sse.sh` and `run_server.sh`)
  - The server is using the correct environment variables (check `.env`)
