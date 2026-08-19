# MCP server

FireRacoon includes a [Model Context Protocol](https://modelcontextprotocol.io/) server that exposes the shared `fireracoon_engine` to LLM clients (Cursor, Claude Desktop, custom agents).

Package: `packages/mcp` · Binary: `fireracoon_mcp`

## Credentials

Agents authenticate with a **FireRacoon agent key**, not a Firefly III token. Issue one in Settings under MCP. Its owner can read it back later, so a mislaid key does not force a reissue, and it can be revoked at any time.

Keys live where the Firefly PAT already does: the platform keychain on desktop, the sealed `DATA_DIR` on a server. Both already hold a secret granting strictly more than any agent key, so keeping the key readable there adds no exposure that was not already present. Key material never leaves through a settings export.

A key acts as the person who created it. Its role decides what the agent can do:

| Role | Tools |
|------|-------|
| `admin` | all |
| `user` | all |
| `viewer` | read-only |

The tool table below marks each write tool, and `get_capabilities` returns the same list as `write_tools`. A viewer's key sees them in `tools/list` and is refused on `tools/call`.

Tools take no credential arguments at all. Where Firefly traffic goes is fixed when the server starts, so an agent cannot redirect a call through its arguments.

## Install / run

```bash
cd packages/mcp
dart pub get

export FIRERACOON_URL=https://fireracoon.example
export FIRERACOON_API_KEY=frcn_...

# Stdio transport (default — MCP clients spawn this process)
dart run fireracoon_mcp

# TCP transport on localhost:8787
dart run fireracoon_mcp --tcp --port 8787

# Export machine-readable tool catalog (agent discovery)
dart run fireracoon_mcp schema
```

The standalone binary runs against a **server-mode** FireRacoon. It exchanges the key at `/api/me`, then sends every Firefly call through the BFF proxy at `/api/firefly`, so the Firefly PAT never enters the MCP process. On `--tcp`, each connection's own key becomes its Firefly bearer, leaving the backend as the authority on what that key may do.

The desktop app runs its own MCP server on TCP and does not use this binary. There, all agents share the app's saved Firefly connection and the key decides only which tools they may call.

See also [`openapi.yaml`](../openapi.yaml) and [`AGENTS.md`](../AGENTS.md) at the repo root.

## Cursor / Claude Desktop configuration

A ready-to-copy config lives at [`docs/mcp-client-config.json`](mcp-client-config.json). Set `FIRERACOON_URL` and `FIRERACOON_API_KEY`, then merge into your client's MCP settings.

**From the repository root** (recommended — paths work out of the box):

```json
{
  "mcpServers": {
    "fireracoon": {
      "command": "dart",
      "args": ["run", "packages/mcp/bin/fireracoon_mcp.dart"],
      "env": {
        "FIRERACOON_URL": "https://fireracoon.example",
        "FIRERACOON_API_KEY": "frcn_your_agent_key"
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
        "FIRERACOON_URL": "https://fireracoon.example",
        "FIRERACOON_API_KEY": "frcn_your_agent_key"
      }
    }
  }
}
```

Adjust paths to your clone location.

## Connecting to the desktop app

The desktop app binds the first free port in 8787–8796 and shows it in Settings under MCP. Clients present their key on `initialize`:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "apiKey": "frcn_your_agent_key"
  }
}
```

`params.api_key` and `params.authentication.token` are accepted as well. Every other method is refused until a key resolves. The `initialize` result carries a `fireracoon` block naming the account the key resolved to and whether it has write access.

## Available tools

| Tool | Description | Writes |
|------|-------------|--------|
| `get_capabilities` | Server version, tool catalog, the write-gated list, and the person behind the presented key |  |
| `check_connection` | Ping Firefly III (`/api/v1/about`) |  |
| `get_current_user` | Authenticated Firefly user profile |  |
| `get_primary_currency` | Instance default currency |  |
| `set_primary_currency` | Change the default currency | yes |
| `get_accounts` | List accounts with balances |  |
| `get_transactions` | Transactions, filterable by account, date window, and reconciled state |  |
| `get_transaction` | One transaction by group ID |  |
| `set_transaction_reconciled` | Mark reconciled or unreconciled | yes |
| `store_reconciliation` | Store an account reconciliation with optional correction | yes |
| `create_transaction` | Create a transaction | yes |
| `update_transaction` | Update a transaction; omitted fields keep their value | yes |
| `duplicate_transaction` | Copy a transaction, with optional overrides | yes |
| `delete_transaction` | Delete a transaction group and its splits | yes |
| `search_transactions` | Full-text search, for matching statement lines |  |
| `get_budgets` | List budgets with spent amounts |  |
| `get_budget_transactions` | Transactions for a budget |  |
| `update_account` | Rename an account | yes |
| `update_budget` | Update a budget; omitted fields keep their value | yes |
| `delete_budget` | Delete a budget | yes |
| `get_account` | One account, optionally as of a date |  |
| `get_account_balance_at_date` | Balance on a date, for checking a statement close |  |
| `get_account_balance_history` | Balance at each of a series of dates |  |
| `create_account` | Create an asset, expense, revenue, or liability account | yes |
| `create_liability` | Create a liability with its direction, interest, and opening balance | yes |
| `delete_account` | Delete an account **and its transactions** | yes |
| `create_budget` | Create a budget, optionally with an auto-budget | yes |
| `get_budget_limits` | Per-period amounts on a budget |  |
| `create_budget_limit` | Set a budget amount for one period | yes |
| `update_budget_limit` | Change a budget limit | yes |
| `get_categories` | List categories |  |
| `create_category` | Create a category | yes |
| `update_category` | Rename a category | yes |
| `delete_category` | Delete a category | yes |
| `get_tags` | List tags |  |
| `create_tag` | Create a tag | yes |
| `update_tag` | Rename a tag | yes |
| `delete_tag` | Delete a tag | yes |
| `get_bills` | List bills with amount ranges |  |
| `create_bill` | Create a bill | yes |
| `update_bill` | Update a bill; omitted fields keep their value | yes |
| `delete_bill` | Delete a bill | yes |
| `get_bill_transactions` | Transactions paid against a bill |  |
| `get_piggy_banks` | List piggy banks and progress |  |
| `create_piggy_bank` | Create a piggy bank | yes |
| `update_piggy_bank` | Update a piggy bank | yes |
| `delete_piggy_bank` | Delete a piggy bank | yes |
| `get_recurrences` | List recurring transaction rules |  |
| `get_recurrence_transactions` | Transactions a recurring rule has created |  |
| `create_recurrence` | Create a recurring rule | yes |
| `update_recurrence` | Update a recurring rule; omitted fields keep their value | yes |
| `delete_recurrence` | Delete a recurring rule; created transactions are kept | yes |
| `get_currencies` | List currencies and which are enabled |  |
| `run_projection` | On-device balance forecast |  |
| `get_dashboard_kpis` | Income, spending, and savings KPIs for a period |  |

Call `get_capabilities` after connecting to discover the live tool list and
schema versions. Its `identity` block names the person the presented key belongs
to, so an agent that has been running a while does not have to have kept the
`initialize` response. It is null when the server was started without a key,
which is only the case for an unauthenticated stdio run.

## Managing keys

Server mode exposes the same operations over HTTP, authenticated with a normal session:

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/agent-keys` | List keys (admins see everyone's, others see their own) |
| `POST` | `/api/agent-keys` | Issue a key; the response is the only time the secret is readable |
| `GET` | `/api/agent-keys/{keyId}/secret` | Read a key back; owner only |
| `DELETE` | `/api/agent-keys/{keyId}` | Revoke a key |
| `DELETE` | `/api/agent-keys/{keyId}/record` | Forget a revoked key's record |

An agent key cannot mint another agent key, nor read any secret including its own: either would turn one leaked secret into access no revocation could reach. Deleting a person drops their keys.

Reading a secret is owner-only, deliberately narrower than listing. An admin can see that someone else holds a key and revoke it, but administering a person does not extend to reading their credentials. A listing never carries secrets or digests, so no single response can spray every credential at once.

Revoking and forgetting are separate steps. Revoking stops a key working and keeps the record visible, showing when it died. Forgetting deletes that record and is only allowed once revoked, so clearing a row can never be what takes access away. Revoked keys sort below active ones in Settings.

### Usage stamps

Each key records when it was last used, so Settings can answer "did this client ever connect" and "is this key still live". Every message from an authenticated agent counts, not just the initial handshake, since a connection is opened once and worked for hours.

Stamps are throttled to one write per minute per key: they exist to show whether a key is in use, not to trace individual calls, and an agent polling every few seconds would otherwise rewrite the whole encrypted store on every request. In server mode the backend stamps in middleware, which covers proxied Firefly traffic too. On desktop the MCP isolate throttles and reports back to the app, which owns the key store. A rejected key leaves no trace.

## Protocol

- JSON-RPC 2.0 over stdio (newline-delimited) or TCP
- Implements `initialize`, `tools/list`, `tools/call`, `ping`
- Protocol version: `2025-06-18`

## Architecture

```
LLM client ──stdio/TCP──► McpServer ──► buildTools() ──► FireflyApiService
                 │                            └──► ProjectionService
                 │                            └──► DashboardStats
                 └──► McpAuthenticator ──► agent key → person → role
```

The MCP layer is a thin adapter — all business logic lives in `packages/engine`.

## Security

- Treat an agent key like a password. It grants whatever its person can do.
- Revoking a key drops the connections it had open: the desktop app restarts its MCP isolate on any key change.
- Prefer stdio transport so the key stays in the parent process environment.
- Only digests are persisted, so neither a stolen `DATA_DIR` nor a stolen keychain entry yields a working key.
- Check a key's last-used stamp in Settings before assuming an unused key is safe to keep.
- Do not expose port 8787 to untrusted networks.
