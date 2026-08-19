# FireRacoon for agents

> **Recommended:** drive FireRacoon through the **MCP server** (`fireracoon_mcp`).
> For REST discovery, read `openapi.yaml` at the repo root.

FireRacoon is a Flutter client for [Firefly III](https://www.firefly-iii.org/) with
an on-device projection engine. Agents can query accounts, transactions, budgets,
run projections, and compute dashboard KPIs without touching the GUI.

## Discovery flow

1. **Read the schema.** Run `dart run packages/mcp/bin/fireracoon_mcp.dart schema`
   (or `fireracoon_mcp schema` when compiled). It prints JSON describing every
   MCP tool, auth requirements, and transport options.
2. **Read OpenAPI.** `openapi.yaml` documents the Firefly III REST subset and
   mirrors MCP tools under `x-mcp.tools`.
3. **Get an agent key.** Issue one in Settings under MCP. It is shown once and
   acts as the person who created it, so a viewer's key gets read-only tools.
   Set `FIRERACOON_URL` and `FIRERACOON_API_KEY`. Firefly III credentials are
   never accepted here, and tools take no credential arguments.
4. **Connect via MCP.** Stdio for Cursor/CLI clients; TCP `127.0.0.1:8787+` when
   the desktop app is running (embedded server in Settings). Both require the
   key; TCP takes it as `initialize.params.apiKey`.

## MCP session

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","apiKey":"frcn_... (TCP)"}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/list"}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"get_accounts","arguments":{}}}
```

Protocol version: `2025-06-18`. TCP clients must include `apiKey` on
`initialize`; stdio reads it from the environment instead. The `initialize`
result carries a `fireracoon` block naming the account the key resolved to and
whether it has write access.

## Deployment modes

- `FIRERACOON_MODE=local` (default): device secure storage; browser/desktop PAT
- `FIRERACOON_MODE=server` (Docker): encrypted `DATA_DIR`; set
  `DATA_PASSWORD` to unlock on boot; users only enter account passwords;
  volume `fireracoon_data`

See `docs/adr/0002-local-vs-server-mode.md` and `docs/deployment.md`.

## Tools

Intentional agent subset of `FireflyService` (not the full Firefly API). See
`CONTEXT.md` and `docs/adr/0001-projection-vs-prognosis.md`.

| Tool | Purpose |
|------|---------|
| `get_capabilities` | Server version and tool catalog |
| `check_connection` | Probe `/api/v1/about` |
| `get_current_user` | Authenticated Firefly user |
| `get_primary_currency` | Primary currency |
| `set_primary_currency` | Set primary currency |
| `get_accounts` | List accounts + balances |
| `get_transactions` | Transactions (optional account, pagination, reconciled filter) |
| `get_transaction` | Single transaction by journal ID |
| `set_transaction_reconciled` | Mark transaction reconciled/unreconciled |
| `store_reconciliation` | Mark reconciled; optional correction; for `ccAsset`, optional payback transfer |
| `get_budgets` | List budgets |
| `get_budget_transactions` | Budget-linked transactions |
| `update_account` | Rename account |
| `update_budget` | Update budget name/amount |
| `delete_budget` | Delete budget |
| `run_projection` | Savings/compound/portfolio/cashflow projection |
| `get_dashboard_kpis` | Net worth, income, spending for a period |

## Result shape

Tool results return JSON-RPC `result` with:

- `content`: pretty-printed text for the model
- `structuredContent`: `{ ok, ... }` map — branch on `ok`
- `isError`: `true` when `ok == false` or the tool threw

Validation errors use `ok: false`, `code: bad_input`, `error: "..."`.

## Standalone server

```bash
# Stdio (MCP clients spawn this)
FIRERACOON_URL=https://fireracoon.example FIRERACOON_API_KEY=frcn_... \
  dart run packages/mcp/bin/fireracoon_mcp.dart

# TCP
dart run packages/mcp/bin/fireracoon_mcp.dart --tcp --port 8787

# Schema export
dart run packages/mcp/bin/fireracoon_mcp.dart schema
```

Sample Cursor config: `docs/mcp-client-config.json`.

## Desktop embedding

On macOS, Windows, and Linux the Flutter app starts MCP once a Firefly
connection and at least one agent key exist. Check **Settings → MCP server** for
the bound port and to issue or revoke keys. Revoking restarts the server, so the
connections that key had open drop with it.

Mobile and web do not embed MCP. Server-mode deployments manage keys through the
same Settings section and run `fireracoon_mcp` separately.
