# MCP server

FireRacoon includes a [Model Context Protocol](https://modelcontextprotocol.io/) server that exposes the shared `fireracoon_engine` to LLM clients (Cursor, Claude Desktop, custom agents).

Package: `packages/mcp` · Binary: `fireracoon_mcp`

## Install / run

```bash
cd packages/mcp
dart pub get

# Stdio transport (default — MCP clients spawn this process)
dart run fireracoon_mcp

# TCP transport on localhost:8787
dart run fireracoon_mcp --tcp --port 8787

# Export machine-readable tool catalog (agent discovery)
dart run fireracoon_mcp schema
```

See also [`openapi.yaml`](../openapi.yaml) and [`AGENTS.md`](../AGENTS.md) at the repo root.

## Credentials

Set environment variables:

```bash
export FIREFLY_URL=https://firefly.example.com
export FIREFLY_TOKEN=your_token
dart run fireracoon_mcp
```

Alternatively, pass `firefly_url` and `firefly_token` per tool call (useful when the MCP client manages secrets).

## Cursor / Claude Desktop configuration

A ready-to-copy config lives at [`docs/mcp-client-config.json`](mcp-client-config.json). Set `FIREFLY_URL` and `FIREFLY_TOKEN`, then merge into your client's MCP settings.

**From the repository root** (recommended — paths work out of the box):

```json
{
  "mcpServers": {
    "fireracoon": {
      "command": "dart",
      "args": ["run", "packages/mcp/bin/fireracoon_mcp.dart"],
      "env": {
        "FIREFLY_URL": "https://firefly.example.com",
        "FIREFLY_TOKEN": "your_token"
      }
    }
  }
}
```

**From `packages/mcp`** (alternative):

```json
{
  "mcpServers": {
    "fireracoon": {
      "command": "dart",
      "args": ["run", "fireracoon_mcp"],
      "cwd": "/absolute/path/to/FireRacoon/packages/mcp",
      "env": {
        "FIREFLY_URL": "https://firefly.example.com",
        "FIREFLY_TOKEN": "your_token"
      }
    }
  }
}
```

Adjust paths to your clone location.

## Available tools

| Tool | Description |
|------|-------------|
| `get_capabilities` | Server version and supported features |
| `check_connection` | Ping Firefly III (`/api/v1/about`) |
| `get_current_user` | Authenticated user profile |
| `get_primary_currency` | Default currency |
| `set_primary_currency` | Set default currency |
| `get_accounts` | List accounts with balances |
| `get_transactions` | Transactions (optional account, pagination, reconciled filter) |
| `get_transaction` | Single transaction by journal ID |
| `set_transaction_reconciled` | Mark transaction reconciled/unreconciled |
| `store_reconciliation` | Store account reconciliation with optional correction |
| `get_budgets` | List budgets with spent amounts |
| `get_budget_transactions` | Transactions for a budget |
| `update_account` | Update account metadata |
| `update_budget` | Update budget metadata |
| `delete_budget` | Delete a budget |
| `run_projection` | On-device balance forecast |
| `get_dashboard_kpis` | Income, spending, savings KPIs for a period |

Call `get_capabilities` after connecting to discover the live tool list and schema versions.

## Protocol

- JSON-RPC 2.0 over stdio (newline-delimited) or TCP
- Implements `initialize`, `tools/list`, `tools/call`, `ping`
- Protocol version: `2025-06-18`

## Architecture

```
LLM client ──stdio/TCP──► McpServer ──► buildTools() ──► FireflyApiService
                                              └──► ProjectionService
                                              └──► DashboardStats
```

The MCP layer is a thin adapter — all business logic lives in `packages/engine`.

## Security

- Treat `FIREFLY_TOKEN` like a password.
- Prefer stdio transport so credentials stay in the parent process environment.
- TCP mode binds to localhost and **requires** a shared secret:
  - Set `MCP_TOKEN` (or pass `--mcp-token`), or let the CLI print an ephemeral token.
  - Clients must send it on `initialize` as `params.mcpToken` (or `params.authentication.token`).
  - Desktop Settings → MCP shows the live token while the server is running.
- Do not expose port 8787 to untrusted networks.
