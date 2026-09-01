# MCP server

FireRaccoon includes a [Model Context Protocol](https://modelcontextprotocol.io/) server that exposes the shared `fireraccoon_engine` to LLM clients (Cursor, Claude Desktop, custom agents).

Package: `packages/mcp` · Binary: `fireraccoon_mcp`

## Credentials

Agents authenticate with a **FireRaccoon agent key**, not a Firefly III token. Issue one in Settings under MCP. Its owner can read it back later, so a mislaid key does not force a reissue, and it can be revoked at any time.

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

export FIRERACCOON_URL=https://fireraccoon.example
export FIRERACCOON_API_KEY=frcn_...

# Stdio transport (the default; MCP clients spawn this process)
dart run fireraccoon_mcp

# TCP transport on localhost:8787
dart run fireraccoon_mcp --tcp --port 8787

# Export machine-readable tool catalog (agent discovery)
dart run fireraccoon_mcp schema
```

The standalone binary runs against a **server-mode** FireRaccoon. It exchanges the key at `/api/me`, then sends every Firefly call through the BFF proxy at `/api/firefly`, so the Firefly PAT never enters the MCP process. On `--tcp`, each connection's own key becomes its Firefly bearer, leaving the backend as the authority on what that key may do.

The desktop app runs its own MCP server on TCP and does not use this binary. There, all agents share the app's saved Firefly connection and the key decides only which tools they may call.

See also [`openapi.yaml`](../openapi.yaml) and [`AGENTS.md`](../AGENTS.md) at the repo root.

## Cursor / Claude Desktop configuration

A ready-to-copy config lives at [`docs/mcp-client-config.json`](mcp-client-config.json). Set `FIRERACCOON_URL` and `FIRERACCOON_API_KEY`, then merge into your client's MCP settings.

**From the repository root** (recommended, since paths work out of the box):

```json
{
  "mcpServers": {
    "fireraccoon": {
      "command": "dart",
      "args": ["run", "packages/mcp/bin/fireraccoon_mcp.dart"],
      "env": {
        "FIRERACCOON_URL": "https://fireraccoon.example",
        "FIRERACCOON_API_KEY": "frcn_your_agent_key"
      }
    }
  }
}
```

**From `packages/mcp`** (alternative):

```json
{
  "mcpServers": {
    "fireraccoon": {
      "command": "dart",
      "args": ["run", "fireraccoon_mcp"],
      "cwd": "/absolute/path/to/FireRaccoon/packages/mcp",
      "env": {
        "FIRERACCOON_URL": "https://fireraccoon.example",
        "FIRERACCOON_API_KEY": "frcn_your_agent_key"
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

`params.api_key` and `params.authentication.token` are accepted as well. Every other method is refused until a key resolves. The `initialize` result carries a `fireraccoon` block naming the account the key resolved to and whether it has write access.

## Available tools

65 tools, 34 of which write. The two that carry a bank import lead the table and
are described under [Importing a statement](#importing-a-statement).

| Tool | Description | Writes |
|------|-------------|--------|
| `find_account` | Resolve raw bank text to an account, one string or a batch, ranked with the reason each candidate matched |  |
| `match_statement` | Pair statement rows against recorded split legs, with the arithmetic behind every verdict |  |
| `get_capabilities` | Server version, tool catalog, the write-gated list, and the person behind the presented key |  |
| `check_connection` | Ping Firefly III (`/api/v1/about`) |  |
| `get_current_user` | Authenticated Firefly user profile |  |
| `get_primary_currency` | Instance default currency |  |
| `set_primary_currency` | Change the default currency | yes |
| `get_accounts` | List accounts with balances |  |
| `get_transactions` | Transactions, filterable by account, date window, and reconciled state |  |
| `get_transaction` | One transaction by group ID, with the legs of a split group |  |
| `set_transaction_reconciled` | Mark reconciled or unreconciled | yes |
| `store_reconciliation` | Store an account reconciliation with optional correction | yes |
| `create_transaction` | Create a transaction, one leg or several | yes |
| `update_transaction` | Update a transaction; omitted fields keep their value | yes |
| `duplicate_transaction` | Copy a transaction and every leg of it, with optional overrides | yes |
| `delete_transaction` | Delete a transaction group and its splits | yes |
| `export_firefly_data` | Snapshot of every entity the API exposes, for taking before a bulk change |  |
| `create_backup` | Take a backup: the snapshot a restore reads plus Firefly's own CSV export, named by the moment it was taken, sealed when given a password | yes |
| `list_backups` | Backups this FireRaccoon holds, newest first |  |
| `get_backup` | One manifest, or a file inside a backup, truncated at `max_bytes` |  |
| `delete_backup` | Remove one backup and everything in it | yes |
| `verify_backup` | Check a backup's own files, then how far the ledger has moved from it |  |
| `restore_backup` | Plan or apply putting a backup back, taking a fresh one first | yes |
| `find_incomplete_transactions` | Transactions missing a description, category, budget, tags, payee, notes or piggy bank |  |
| `search_transactions` | Full-text search, for matching statement lines |  |
| `get_budgets` | List budgets with spent amounts |  |
| `get_budget_transactions` | Transactions for a budget |  |
| `update_account` | Name, identifiers, notes, role, currency, liability terms, or balances; omitted fields keep their value | yes |
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
| `get_recurrences` | List recurring rules, each with the amount, accounts, category, budget and tags of the lines it creates |  |
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

## Importing a statement

Two tools carry a bank import, and neither writes. They report what they found
and the arithmetic behind it; every change to the ledger stays a separate,
deliberate call.

### Resolving a name to an account

`find_account` turns raw bank text into candidates. It matches on the account
number and the IBAN before it looks at any name, so a payee that carries an
identifier is resolved by the ledger rather than by a string that reads alike.
The tiers run in a fixed order with fixed scores: account number (1.0), IBAN
(1.0), the IBAN's BBAN against the digits in the query (0.9), then folded name
equality (0.8), a bidirectional prefix (0.6), and a folded substring (0.4, never
better than weak). An identifier hit ends the search, so a name coincidence is
never appended below one and cannot dilute an answer the ledger already gave.

A bank writes an account line as a label and then a number, and those digits
fold into the name, so on a ledger carrying no identifiers the line as printed
matched nothing at all: passing the account number, the strongest signal the
tool has, made the answer strictly worse than passing the label alone. When
every tier has missed, the name tiers now run once more against the label with
the trailing number set aside, and each reason says so. Nothing that pass finds
comes back exact, so it always asks rather than answers.

Every candidate carries `matched_on`, the `reasons` it matched, a `score`, a
`confidence` of exact, probable, or weak, and `requires_confirmation`, set for
anything short of exact. The tool ranks; it never picks. `ambiguous` is true when
the top two scores are less than 0.05 apart, or when more than one account
answered to the same key, and it is read off the full ranking rather than the
truncated one, so a `limit` of 1 cannot hide the runner-up that made the leader
doubtful.

Exact is a uniqueness claim as much as a score claim, and nothing here promises
uniqueness Firefly does not enforce. Two accounts can carry the same account
number, and when they do both come back probable and listed under `collisions`
rather than either one coming back exact. That applies to every tier, not only
identifiers: two accounts whose folded names share a prefix collide the same
way, keyed by the tier that matched, so a caller reading `collisions` must not
assume a duplicate account number. An `iban` argument shaped like an IBAN
that fails its mod-97 check skips the identifier tiers altogether and says so
under `warnings`: matching on a number the caller mistyped is worse than falling
through to the name. A clearing number or a bare account number is not a corrupt
IBAN, so the check only speaks for a string shaped like one.

The identifier it matched on does not come back. A candidate reports `has_iban`,
`has_account_number`, and an `identifier_hint` naming the last four digits, which
is enough for a person to confirm the right account without the number itself
entering the transcript.

### Matching rows against the ledger

`match_statement` pairs the rows of an export against the split legs recorded on
one account. The unit is a leg, not a journal: a statement line pays one leg, so
a split group offers as many units as it has legs touching the account and each
is spent at most once. Exact pairs are consumed first, then the near pass runs
over what is left on both sides, which is what stops two rows of the same amount
on the same day from collapsing onto one transaction.

Near matches are the interesting half. A recurring charge written ahead of time
from an estimate sits in the ledger at the estimated amount, and then the bank
takes the real one. That row is neither missing nor a clean match, so it comes
back under `near_matches` with `amount_delta`, `amount_delta_pct`,
`date_delta_days`, and the reasons it fell short, for a person to correct rather
than for the tool to overwrite. A near match whose journal is a split group
carries `blocked_reason: split_group`: correcting that leg would move a journal
whose other legs the statement says nothing about.

The fetch reaches five days past both ends of the window, because that is the
widest gap the near pass will pair across. Reaching forward only meant a
transaction the ledger dated the day before the statement's first row was never
fetched, so it came back as missing and writing it would have duplicated what
was already there. Legs outside the period stay matchable and are counted under
`excluded.fetched_outside_period`.

One call takes up to 10,000 rows. Past that, split the statement at dates where
the two balances already agree, so no pair is cut in half: cutting at an
arbitrary date severs a transaction the two sides date on opposite sides of the
line, and it then reads as missing on one side and unmatched on the other.

Tolerances are fixed constants, not arguments, and every response echoes them
under `window` so a caller can read the rule that produced its verdicts.

| Field | Value | Governs |
|-------|-------|---------|
| `date_tolerance_days` | 3 | how far a recorded leg may sit from a row and still be claimed as the same event |
| `near_date_tolerance_days` | 5 | the wider window the near pass reports over |
| `near_amount_tolerance_pct` | 0.10 | how far a near candidate's amount may differ from the row |
| `amount_equality_tolerance` | 0.005 | below which two amounts are the same amount |

The `arithmetic` block is the proof: the statement rows sum, the recorded sum,
their difference, the gap the opening and closing balances imply, the sum of the
missing rows, and whether writing those rows would move the ledger by exactly
that gap (`gap_closed_by_plan`). `agrees` is null when no balances were supplied,
since there is then nothing to agree with. `statement_self_check` answers the
narrower question of whether the statement's own numbers add up, before the
ledger is consulted at all.

A row whose amount will not read under the settled decimal grammar is not
guessed at. It comes back under `needs_input` with what it would be worth under
each grammar, and its presence alone is enough to refuse to say the arithmetic
agrees.

### Closing the loop

Acting on a plan is separate: `update_transaction` corrects a near match,
`create_transaction` or `duplicate_transaction` writes a missing row. Setting
`account_number` or `iban` on a payee with `update_account` is what upgrades the
next import from a name guess to an identifier lookup.

### Writing a split

One bank line often pays a journal with several legs: a loan payment divided
into amortisation and interest, or a card bill that settles a month of
purchases. `get_transaction` returns those legs under `splits`, so a caller can
read one and write the same shape back. A listing reports only `split_count`,
since a 26-leg bill would otherwise be most of the page.

`duplicate_transaction` carries every leg. It refuses an `amount` on a group,
because one figure does not say how to divide it across legs and a loan's fixed
amortisation must not be scaled along with its interest; pass `splits` to
restate them. A copy is never reconciled, whatever the original was.

`create_transaction` takes the same `splits`, where each leg inherits anything
it omits from the top-level arguments, so the account and currency are given
once and only the amount, description and category vary. Reconciling a
credit card is not one of these: `store_reconciliation` builds that payback from
the purchases it settles, which is what keeps the group title and the per-leg
links identical to what the app writes.

### Removing a value, not just changing it

An update leaves out a field it was not given, which is what makes a partial
update partial. That meant an empty value and an absent one looked identical on
the wire, so a note or a category could be set and never taken away.

Passing an empty string, or an empty array for `tags`, now removes what is
there: `notes`, `category_name`, `category_id`, `budget_name`, `budget_id`,
`bill_id`, `piggy_bank_id` and `tags`. Omitting the field still leaves it
exactly as it was.

### Reconciliation survives an edit

`update_transaction` keeps whatever `reconciled` the transaction already had
when the call does not mention it. Leaving it out used to send false, so any
edit silently discarded a reconciliation and a refresh was the first anyone
heard of it.

Firefly will not move the money on a reconciled transaction, and the payload
drops those fields rather than arguing, so a correction reported success and
changed nothing. Changing `amount`, `foreign_amount`, `currency_code` or either
account on a reconciled transaction is now refused; pass `reconciled: false` in
the same call to release it and make the change together.

A copy is still never reconciled, whatever the original was.

### Writing across two currencies

A transfer between accounts holding different currencies needs both figures, and
Firefly refuses the write with a 422 on `foreign_amount` when only one is given.
Pass `foreign_amount`, and `foreign_currency_code` when it is not the receiving
account's own.

`duplicate_transaction` carries both sides of the original. It refuses an
`amount` override on a transaction that has a foreign amount unless
`foreign_amount` comes with it: the rate cannot be read off the local figure,
carrying the old one over would pair this month's amount with last month's rate,
and scaling it would invent a rate and record it as fact.

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

The MCP layer is a thin adapter; all business logic lives in `packages/engine`.

## Security

- Treat an agent key like a password. It grants whatever its person can do.
- Revoking a key drops the connections it had open: the desktop app restarts its MCP isolate on any key change.
- Prefer stdio transport so the key stays in the parent process environment.
- The secret is stored alongside its digest so its owner can read the key back instead of reissuing it, which means a stolen `DATA_DIR` or keychain entry does yield working keys. That is the same exposure the Firefly PAT already carries in the same store, and an agent key grants strictly less than the PAT does. Revoke the keys if either is lost.
- Check a key's last-used stamp in Settings before assuming an unused key is safe to keep.
- Do not expose port 8787 to untrusted networks.
