# FireRacoon for agents

> **Recommended:** drive FireRacoon through the **MCP server** (`fireracoon_mcp`).
> For REST discovery, read `openapi.yaml` at the repo root.

FireRacoon is a Flutter client for [Firefly III](https://www.firefly-iii.org/) with
an on-device projection engine. Agents read and write the whole bookkeeping
surface, accounts through recurrences, and run projections and dashboard KPIs,
without touching the GUI.

## Discovery flow

1. **Read the schema.** Run `dart run packages/mcp/bin/fireracoon_mcp.dart schema`
   (or `fireracoon_mcp schema` when compiled). It prints JSON describing every
   MCP tool, auth requirements, and transport options.
2. **Read OpenAPI.** `openapi.yaml` documents the Firefly III REST subset and
   mirrors MCP tools under `x-mcp.tools`.
3. **Get an agent key.** Issue one in Settings under MCP. Its owner can read it back later from the same panel, and
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

Accounts, transactions, budgets, budget limits, categories, tags, bills, piggy
banks, recurrences, currencies, reconciliation, and the on-device projection:
59 tools, 31 of them write-gated. The rich account prognosis behind the UI is
the one engine capability with no tool
(`docs/adr/0001-projection-vs-prognosis.md`). `get_capabilities` returns the
live catalog and the write-gated names a `viewer` key is refused. Domain terms
live in `CONTEXT.md`.

| Tool | Purpose |
|------|---------|
| `get_capabilities` | Server version, tool catalog, and the write-gated list |
| `check_connection` | Probe `/api/v1/about` |
| `get_current_user` | Authenticated Firefly user |
| `get_primary_currency` | Instance default currency |
| `set_primary_currency` | Change the default currency |
| `get_accounts` | List accounts with balances; pass types to reach payees |
| `get_transactions` | Transactions, filterable by account, date window, and reconciled state |
| `get_transaction` | One transaction by group ID, with the legs of a split group; Firefly answers 401 for a journal ID |
| `set_transaction_reconciled` | Mark reconciled or unreconciled |
| `store_reconciliation` | Reconcile an account; optional correction, and a payback transfer for `ccAsset` |
| `create_transaction` | Create a transaction, one leg or several |
| `update_transaction` | Update a transaction; omitted fields keep their value |
| `duplicate_transaction` | Copy a transaction and every leg of it, with optional overrides |
| `delete_transaction` | Delete a transaction group and every split in it |
| `export_firefly_data` | Snapshot of every entity the API exposes, for taking before a bulk change |
| `find_incomplete_transactions` | Transactions missing a description, category, budget, tags, payee, notes or piggy bank |
| `search_transactions` | Full-text search, for matching statement lines |
| `find_account` | Resolve raw bank text to an account; matches account number and IBAN before any name tier, returns ranked candidates with a reason and a last-four hint, never the identifier |
| `match_statement` | Match statement rows against recorded split legs; reports matched, near-matched and missing rows with the arithmetic that proves it |
| `get_budgets` | List budgets with spent amounts |
| `get_budget_transactions` | Transactions for a budget |
| `update_account` | Change a name, IBAN, BIC, account number, notes, role, currency, liability terms or opening balance; at least one field required |
| `update_budget` | Update a budget name, active flag, notes, and auto-budget |
| `delete_budget` | Delete a budget |
| `get_account` | One account, optionally as it stood on a date |
| `get_account_balance_at_date` | Balance on a date, for checking a statement close |
| `get_account_balance_history` | Balance series across a window |
| `create_account` | Create an asset, expense, revenue, or liability account |
| `create_liability` | Create a loan, debt, or mortgage |
| `delete_account` | Delete an account **and its transactions** |
| `create_budget` | Create a budget, optionally with an auto-budget |
| `get_budget_limits` | Per-period amounts on a budget |
| `create_budget_limit` | Set a budget amount for one period |
| `update_budget_limit` | Change a budget limit |
| `get_categories` | List categories |
| `create_category` | Create a category |
| `update_category` | Rename a category, and optionally replace its notes |
| `delete_category` | Delete a category |
| `get_tags` | List tags |
| `create_tag` | Create a tag |
| `update_tag` | Rename a tag, and optionally replace its description |
| `delete_tag` | Delete a tag |
| `get_bills` | List bills with their amount ranges |
| `create_bill` | Create a bill |
| `update_bill` | Update a bill; omitted fields keep their value |
| `delete_bill` | Delete a bill; linked transactions survive without the link |
| `get_bill_transactions` | Transactions matched to a bill |
| `get_piggy_banks` | List piggy banks and progress toward target |
| `create_piggy_bank` | Create a piggy bank linked to asset accounts |
| `update_piggy_bank` | Update a piggy bank; omitted fields keep their value |
| `delete_piggy_bank` | Delete a piggy bank; linked accounts are untouched |
| `get_recurrences` | List recurring rules, each with the amount, accounts, category, budget and tags of the lines it creates |
| `get_recurrence_transactions` | Transactions a recurring rule has created |
| `create_recurrence` | Create a recurring rule |
| `update_recurrence` | Replace a recurring rule; every field to keep must be passed |
| `delete_recurrence` | Delete a recurring rule; transactions it created are kept |
| `get_currencies` | List currencies and which are enabled |
| `run_projection` | Savings, compound, portfolio, or cashflow projection |
| `get_dashboard_kpis` | Net worth, income, spending, and savings for a period |

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
