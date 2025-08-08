# MCP MariaDB — Getting Started

This guide shows how to use the MariaDB MCP server with Cursor against your local DB.

## One-time setup (already done)

- **Repo**: `/home/diae/mcp/mariadb-mcp-server`
- **Virtualenv**: `.venv` (Python 3.11)
- **Config**: `.env` points to `127.0.0.1:3308` with your credentials
- **Runner scripts**:
  - `run_server.sh` (stdio)
  - `run_sse.sh` (SSE)
- **Cursor config (SSE)**:
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

## Daily workflow (SSE mode)

1. **Ensure DB is running in Docker (port 3308)**:

   - From project root: `docker compose -f /home/diae/projects/hrsuite-cloud/docker-compose.yaml up -d db`

2. **Start the MCP server (recommended self-healing launcher)**:

   Use the new auto-fix launcher. It will fix CRLF/permissions, load `.env`, check DB reachability, pick a free port, and start SSE.

   ```bash
   /home/diae/mcp/mariadb-mcp-server/run_auto.sh
   ```

   - Optional: force stdio mode (Cursor-managed):
     ```bash
     /home/diae/mcp/mariadb-mcp-server/run_auto.sh stdio
     ```
   - Optional: request a specific port (auto-fallbacks to next free):
     ```bash
     /home/diae/mcp/mariadb-mcp-server/run_auto.sh sse --port 9101
     ```

3. **In Cursor**:

   - Reload MCP servers or restart Cursor
   - You should see tools like `list_databases`, `list_tables`, `execute_sql`

4. **Optional checks**:
   - Verify port: `ss -ltnp | grep ":9101"`
   - Tail logs: `tail -f /home/diae/mcp/mariadb-mcp-server/logs/mcp_server.log`

## Stopping the SSE server

To stop the SSE server:

- `pkill -f "/home/diae/mcp/mariadb-mcp-server/src/server.py"`

- If it doesn't work, try:

  - Get the PID:
    ```bash
    ss -ltnp | grep ":9101"
    ```
  - Note the python PID, then:
    ```bash
    kill -TERM <pid>
    ```
  - Verify it's stopped:
    ```bash
    ss -ltnp | grep ":9101"
    ```
    (no output means it's down)

- If running in stdio mode (Cursor-managed), disable/remove it from `mcpServers` and reload Cursor; Cursor will stop it automatically.

## Alternative: stdio mode (Cursor launches it)

- Use this entry under `mcpServers` in `C:\Users\diae\.cursor\mcp.json`:
  ```json
  "MariaDB_Server": {
    "command": "C:\\Windows\\System32\\wsl.exe",
    "args": [
      "bash",
      "-lc",
      "/home/diae/mcp/mariadb-mcp-server/run_auto.sh stdio"
    ],
    "timeout": 600
  }
  ```
- In stdio mode, Cursor starts/stops the server automatically. No manual start needed.

## Changing port (SSE)

- Prefer using the launcher with an explicit port (it will auto-fallback to the next free one):
  ```bash
  /home/diae/mcp/mariadb-mcp-server/run_auto.sh sse --port 9201
  ```
  Then update Cursor `servers` URL to match (e.g., `http://localhost:9201/sse`).

## Enabling embeddings (optional)

Add to `.env` and restart the server:

- **OpenAI**: `EMBEDDING_PROVIDER=openai`, `OPENAI_API_KEY=...`
- **Gemini**: `EMBEDDING_PROVIDER=gemini`, `GEMINI_API_KEY=...`
- **HuggingFace**: `EMBEDDING_PROVIDER=huggingface`, `HF_MODEL=BAAI/bge-m3` (or other)

## Quick commands

- **Start DB only**:
  ```bash
  docker compose -f /home/diae/projects/hrsuite-cloud/docker-compose.yaml up -d db
  ```
- **Start MCP (SSE)**:
  ```bash
  /home/diae/mcp/mariadb-mcp-server/run_sse.sh
  ```
- **Check listening port**:
  ```bash
  ss -ltnp | grep ":9101"
  ```
- **Stop MCP**:
  ```bash
  pkill -f "/home/diae/mcp/mariadb-mcp-server/src/server.py"
  ```

## Troubleshooting

- **Port in use on 9001/9101**: pick another port and update Cursor URL
- **DB not reachable**: ensure Docker `db` service is running and port `3308` is published
- **Windows ENOENT for WSL (stdio mode)**: use `C:\Windows\System32\wsl.exe` in Cursor config
- **View logs**: `/home/diae/mcp/mariadb-mcp-server/logs/mcp_server.log`
- **SSE server isn't running** if Cursor tries to connect to `http://localhost:9101/sse`, and you get ECONNREFUSED. Check:
  - The server is running (port `9101` is listening)
  - The server is configured correctly in Cursor (check `servers` in `C:\\Users\\diae\\.cursor\\mcp.json`)
  - The server is using the correct port (check `run_sse.sh` and `run_server.sh`)
  - The server is using the correct environment variables (check `.env`)
- **Race on checks**: Early port checks right after starting the process can be too fast; the server needs ~1s to bind.

## Common problems and fixes (if auto launcher fails)

- **Scripts not executable or CRLF line endings**

  - Symptoms: `permission denied`, or scripts behave oddly on WSL
  - Fix:
    ```bash
    chmod +x /home/diae/mcp/mariadb-mcp-server/run_*.sh
    sed -i 's/\r$//' /home/diae/mcp/mariadb-mcp-server/run_*.sh
    ```

- **Virtualenv missing or wrong Python version**

  - Symptoms: `source .venv/bin/activate: No such file or directory`, module import errors
  - Fix (Python 3.11):
    ```bash
    cd /home/diae/mcp/mariadb-mcp-server
    python3.11 -m venv .venv
    source .venv/bin/activate
    pip install -e .
    ```
    Or using uv:
    ```bash
    uv venv
    uv pip install -e .
    ```

- **DB not reachable**

  - Symptoms: startup fails with pool init error, or logs contain `DB_UNREACHABLE`/`ECONNREFUSED`
  - Fix:
    ```bash
    docker compose -f /home/diae/projects/hrsuite-cloud/docker-compose.yaml up -d db
    ss -ltnp | grep ":3308\\b" | cat   # ensure port 3308 is published
    ```
    Verify `.env` points to `127.0.0.1:3308` with correct `DB_USER`/`DB_PASSWORD`.

- **SSE port busy (9001/9101)**

  - Symptoms: server fails to bind, logs mention `Address already in use`
  - Fix: request a different port (launcher will auto-fallback if busy)
    ```bash
    /home/diae/mcp/mariadb-mcp-server/run_auto.sh sse --port 9201
    ```
    Update Cursor URL accordingly.

- **Cursor cannot connect (ECONNREFUSED)**

  - Checks:
    - Server listening: `ss -ltnp | grep ":<port>\\b" | cat`
    - Cursor config matches port: check `servers` in `C:\\Users\\diae\\.cursor\\mcp.json`
    - Correct `.env` loaded; restart server after changes
    - Give it ~1s after start before checking

- **Stdio mode fails on Windows (ENOENT for WSL)**

  - Fix: use explicit `wsl.exe` in `mcpServers` and call stdio via the launcher:
    ```json
    "MariaDB_Server": {
      "command": "C:\\Windows\\System32\\wsl.exe",
      "args": ["bash","-lc","/home/diae/mcp/mariadb-mcp-server/run_auto.sh stdio"],
      "timeout": 600
    }
    ```

- **Embedding provider errors**

  - Symptoms: startup raises missing API key/model
  - Fix: set the corresponding variables in `.env` or remove `EMBEDDING_PROVIDER` to disable embeddings

- **Where to see errors**

  - View logs:
    - Launcher: `/home/diae/mcp/mariadb-mcp-server/logs/mcp_server_auto.log`
    - Server: `/home/diae/mcp/mariadb-mcp-server/logs/mcp_server.log`
  - Tail last lines:
    ```bash
    tail -n 200 /home/diae/mcp/mariadb-mcp-server/logs/mcp_server_auto.log | cat
    tail -n 200 /home/diae/mcp/mariadb-mcp-server/logs/mcp_server.log | cat
    ```

- **Stop a stuck/old server**
  - Fix:
    ```bash
    pkill -f "/home/diae/mcp/mariadb-mcp-server/src/server.py"
    ```
