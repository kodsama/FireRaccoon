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

68 tools, 36 of which write. The two that carry a bank import lead the table and
are described under [Importing a statement](#importing-a-statement).

| Tool | Description | Writes |
|------|-------------|--------|
| `find_account` | Resolve raw bank text to an account, one string or a batch, ranked with the reason each candidate matched |  |
| `match_statement` | Pair statement rows against recorded split legs, with the arithmetic behind every verdict |  |
| `get_capabilities` | App and server version, tool catalog, the write-gated list, the person behind the presented key, and live backend status |  |
| `check_connection` | Whether Firefly III is connected, which server, which version, and how many users |  |
| `get_current_user` | Authenticated Firefly user profile |  |
| `get_primary_currency` | Instance default currency |  |
| `set_primary_currency` | Change the default currency | yes |
| `get_accounts` | List accounts with balances; pass types to reach payees, or `reconciliation` to see what Firefly keeps for a correction |  |
| `get_transactions` | Transactions, filterable by account, date window, and reconciled state |  |
| `get_transaction` | One transaction by group ID, with the legs of a split group |  |
| `get_card_settlements` | What the paybacks on a credit card settle, read from their link notes, and the purchases and refunds no payback links |  |
| `set_transaction_reconciled` | Mark reconciled or unreconciled | yes |
| `store_reconciliation` | Reconcile an account against a statement: mark the rows, write the correction the balances call for against the account Firefly keeps for it, and on a credit card the payback transfer too | yes |
| `create_transaction` | Create a transaction, one leg or several | yes |
| `update_transaction` | Update a transaction; omitted fields keep their value, the bookkeeping reaches every leg of a split group, `splits` reaches one leg by its journal id, and `keep_reconciled` releases and re-reconciles a row around a change | yes |
| `duplicate_transaction` | Copy a transaction and every leg of it, with optional overrides | yes |
| `delete_transaction` | Delete a transaction group and its splits | yes |
| `export_firefly_data` | Snapshot of every entity the API exposes, for taking before a bulk change |  |
| `create_backup` | Take a backup: the snapshot a restore reads plus Firefly's own CSV export, named by the moment it was taken, sealed when given a password; `complete` says the snapshot was written and `failed_exports` names any CSV Firefly could not produce, the piggy-bank CSV Firefly 6.6.6 refuses being written from the API instead and marked `source: fireraccoon` on its entry | yes |
| `list_backups` | Backups this FireRaccoon holds, newest first, each stamped in the zone it was taken in |  |
| `get_backup` | One manifest, or a file inside a backup, truncated at `max_bytes` |  |
| `delete_backup` | Remove one backup and everything in it | yes |
| `verify_backup` | Check a backup's own files, then how far the ledger has moved from it; an export that was never written is listed under `never_written`, not counted as damage |  |
| `restore_backup` | Plan or apply putting a backup back, taking a fresh one first | yes |
| `find_incomplete_transactions` | Transactions missing a description, category, budget, tags, payee, notes or piggy bank |  |
| `search_transactions` | Full-text search, for matching statement lines |  |
| `get_budgets` | List budgets with what was spent against them over a window |  |
| `get_budget_transactions` | Transactions for a budget |  |
| `update_account` | Name, identifiers, notes, role, currency, liability terms, or balances; omitted fields keep their value | yes |
| `update_budget` | Update a budget; omitted fields keep their value, and a period limit that did not follow the amount is reported | yes |
| `delete_budget` | Delete a budget | yes |
| `get_account` | One account with its identifiers and, on a liability, its own terms; optionally as of a date |  |
| `get_account_balance_at_date` | Balance on a date, for checking a statement close |  |
| `get_account_balance_history` | Balance at each of a series of dates |  |
| `create_account` | Create an asset, expense, revenue, liability, or reconciliation account | yes |
| `create_liability` | Create a liability with its direction, interest, and opening balance | yes |
| `delete_account` | Delete an account **and its transactions** | yes |
| `create_budget` | Create a budget, optionally with an auto-budget | yes |
| `get_budget_limits` | Per-period amounts on a budget |  |
| `create_budget_limit` | Set a budget amount for one period | yes |
| `update_budget_limit` | Change a budget limit | yes |
| `delete_budget_limit` | Remove one budget limit, permanently | yes |
| `get_categories` | List categories |  |
| `create_category` | Create a category | yes |
| `update_category` | Rename a category | yes |
| `delete_category` | Delete a category | yes |
| `get_tags` | List tags |  |
| `create_tag` | Create a tag | yes |
| `update_tag` | Rename a tag, or refuse and point at `merge_tags` when another tag has the name | yes |
| `delete_tag` | Delete a tag | yes |
| `merge_tags` | Move every transaction from one tag onto another and remove the tag left empty; reports the rows and writes nothing unless `dry_run` is false | yes |
| `get_bills` | List bills with amount ranges |  |
| `create_bill` | Create a bill | yes |
| `update_bill` | Update a bill; omitted fields keep their value | yes |
| `delete_bill` | Delete a bill | yes |
| `get_bill_transactions` | Transactions paid against a bill |  |
| `get_piggy_banks` | List piggy banks and progress |  |
| `create_piggy_bank` | Create a piggy bank, with a target date if it has one | yes |
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

Its `backend` block is read live, so it also answers whether Firefly III is
reachable, at which URL, on which version, and how many users it holds. That
last count needs an owner's token; a viewer gets `user_count: null` and the rest
of the status stands.

## When Firefly III is not connected

Having no server connected is a state, not a failure, and every tool reports it
as one rather than throwing. A tool that needed Firefly and had nowhere to ask
answers `ok: false` with a `code` and a `remedy`:

| `code` | What happened |
|--------|---------------|
| `not_connected` | No server is configured. Nobody has finished setting up. |
| `backend_unreachable` | A server is configured and did not answer. |
| `backend_unauthorized` | Firefly III answered and refused the token. |

The distinction is worth keeping: an agent told a socket failed retries or
concludes the ledger is broken, when the real answer is that there is no ledger
yet. `check_connection` and `get_capabilities` return the same codes, and both
keep answering while the backend is down.

## When a Cosmos Cloud route stands in front of Firefly III

A protected Cosmos route is gated on one cookie, `jwttoken`, which only its own
`/cosmos/oauth2/detect-callback` mints at the end of an interactive login. The
proxy strips that cookie before forwarding, and leaves `Authorization` alone, so
the Firefly token still does its own job behind it.

MCP carries whatever session the app holds. It does not sign in: the login needs
a person, and it happens once in the app under **Settings → Cosmos SSO**.
`get_capabilities` reports `app.proxy_session` so an agent can see whether this
server has one, and a probe that meets the sign-in page comes back
`connected: true, authorized: false, proxy: cosmos` rather than as an unreachable
server, because the server is running fine and the missing thing is a session.

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

A correction names both sides: the account being reconciled, and the account
Firefly keeps for it. That second one is read rather than guessed, with
`GET /api/v1/accounts?type=reconciliation`, and matched by the names Firefly
gives them: `<account> reconciliation (<currency>)` on 6.6.6, and the bare
`<account> reconciliation` an older version wrote, since an account keeps the
name it was made with. `get_accounts` takes `reconciliation` among its types,
which is how to read the same list.

Neither shortcut works. Guessing the name misses the currency, and a name
Firefly cannot resolve is a refusal. Leaving the far side empty is what
Firefly's own interface does, and its journal factory fills the account in,
but the REST layer turns an absent name into an empty string before the
validator sees it: the side never reads as unstated, so Firefly searches for an
account called nothing and answers `Created zero transaction journals`.

Firefly makes these only from its own interface and its API refuses to create
the type, so an account it has never reconciled has nothing for a correction to
name. Reconcile that account once in Firefly and the correction can be written.
Until then, and for any account Firefly will not reconcile at all, the rows are
still marked: the call answers `ok` with the reconciliation done and names the
unwritten correction under `warning`.

A credit card gets the same gap and correction as any other account, computed
over the statement window from `start_balance`, `end_balance` and the rows
selected; the payback is dated after the close and is no part of it. The card
path used to take the payback alone and report no gap however far the balances
sat from the rows, which left a card whose ledger had been a fixed amount off
the bank's since before the imported history with no way to be put right.
`payment_account_id` and `payback_date` go together, and both can be left out
to reconcile and correct a card whose purchases were already paid back, which
is how such an offset gets one correction at the first statement that proves
it. A second payback for those purchases would be wrong, and the tool used to
insist on one.

### What a card payback settles

Every leg of a payback the app writes carries a link note,
`fireraccoon:linked_journal:<id>`, naming the purchase it settles, and a netted
payback names every row it settles, refunds included. Nothing read those notes
back until now, which is how a year of paybacks written by hand as single
untitled legs went unnoticed: the app never compared purchases against
paybacks.

`get_card_settlements` reads them. Given a card, an account with role
`ccAsset`, it lists every payback oldest first with the rows its notes settle,
and under `unsettled` the purchases and refunds dated before the last payback
that no payback links. A payback carrying no links comes back with
`linked: false`, which is what a hand-written one looks like. A linked row from
before the window that was read is named under `settles_outside_window` rather
than fetched. Rows written before the raccoon rename spell the note
`fireracoon:` with one `c`, and both spellings are read. `get_transaction`
lists the same ids under `settles` on any transaction whose legs carry a link.

The reconciliation panel in the app shows the same gap while a payback is being
prepared: when older paybacks on the card link to nothing, it says how many.

### A split group is edited whole or a leg at a time

Firefly identifies one leg of a group by `transaction_journal_id`, and treats a
leg that carries none as a new split, deleting the journals the update did not
name. Every leg of an update carries its id now, so a group can be edited at
all: it used to be destroyed and rebuilt with the same values under new ids,
which is why a category move reported success and changed nothing, and why
marking a group reconciled never held.

A group-level call spreads the bookkeeping over every leg: `category_id`,
`category_name`, `budget_id`, `notes`, `tags` and `bill_id`. What belongs to
one leg stays with it, so amounts, descriptions and accounts are untouched. A
`description` on a group is its title, since overwriting "Amortisation" and
"Interest" with one string would be worse than the bug being fixed; pass
`group_title` to be explicit about it.

Editing one leg on its own takes `splits`, where each entry names its leg by
the `journal_id` `get_transaction` reports for it and states only what changes.
That is what a loan whose amortisation and interest belong to different
categories needs, and what a split paying for someone else needs: one leg
carrying a budget beside one that must carry none. A group-level field cannot
be passed in the same call, since it would have to mean every leg and one leg
at once; `date`, `type` and `group_title` still belong to the group.

A leg the list leaves out is left exactly as it is. The whole group goes back
out either way, each leg carrying its own id, so the rule that a missing leg is
deleted never comes into play, and legs cannot be added or removed this way.
The readback reports a leg Firefly declined as `splits[0].budget_id`, and a
group that came back without a journal the call named as `splits[0]`.

### A liability's own terms

`get_account` and `get_accounts` carry `liability_type`, `liability_direction`,
`opening_balance` and `opening_balance_date`, so what `update_account` writes
can be read back. They used to be dropped from both, which left every liability
reading as one nobody had configured: the obvious answer was to set the fields,
`update_account` said `ok`, the read still said null, and nothing had changed
because nothing was wrong. Checking how a liability stood took a whole-ledger
`export_firefly_data`.

### Removing a value, not just changing it

An update leaves out a field it was not given, which is what makes a partial
update partial. That meant an empty value and an absent one looked identical on
the wire, so a note or a category could be set and never taken away.

Passing an empty string, or an empty array for `tags`, now removes what is
there: `notes`, `category_name`, `category_id`, `budget_name`, `budget_id`,
`bill_id`, `piggy_bank_id` and `tags`. Omitting the field still leaves it
exactly as it was.

A category is named twice, by `category_name` and `category_id`, and Firefly
resolves whichever half still carries a value. Emptying one of them therefore
clears both: sending the stored other half back was how a removal reported
success and left the category exactly where it was, and getting it off needed
both fields emptied in the same call. Either one alone is enough. A removal the
ledger did not take comes back the way any unapplied field does, as
`code: not_applied` naming the field the caller emptied, with the row as it now
stands.

### A name replaces the id beside it

Firefly resolves an id in preference to a name. An update that named a
category while the stored id rode along changed nothing and answered 200, and
so did one that moved a payee by name: the description and category in the
same call landed, the payer stayed, and nothing in the answer said so. A name
stated without its id now drops the stored id for that side, on the group and
on a leg named in `splits` alike, and a leg of a create that names its own
account no longer inherits the group's id. An account Firefly kept regardless
comes back as `not_applied`, naming `source_name`, `destination_name` or the id
that did not land, the way every other declined field is reported.

### Reconciliation survives an edit

`update_transaction` keeps whatever `reconciled` the transaction already had
when the call does not mention it. Leaving it out used to send false, so any
edit silently discarded a reconciliation and a refresh was the first anyone
heard of it.

Firefly will not move the money on a reconciled transaction, and the payload
drops those fields rather than arguing, so a correction reported success and
changed nothing. Changing `amount`, `foreign_amount`, `currency_code` or either
account on a reconciled transaction is now refused; pass `reconciled: false` in
the same call to release it and make the change together. On a split group that
release reaches every leg, which is what makes it work there at all: the flag
used to stop at the group while each leg stayed reconciled, and the amounts it
was meant to free were dropped from the payload anyway. A leg names its own
`reconciled` inside `splits`.

Releasing a row to move its money and then reconciling it again took two
calls, and between them the row sat unreconciled, so a run that died there
left it that way. `keep_reconciled: true` does both from one call: the release
goes out with the change, and once Firefly has stored it a second write puts
back the flag each leg had, so a partly reconciled group comes back partly
reconciled rather than whole. The answer lists the steps under `steps`. A
second write Firefly refused comes back as `left_unreconciled` with the
transaction as it now stands, so the caller knows exactly which row to finish
with `set_transaction_reconciled`. It cannot be passed beside `reconciled`,
since one says what the flag should become and the other says to keep it.

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

### Two tags that mean the same thing

Firefly has no merge endpoint, and it refuses a rename onto a name already in
use with a 422 saying so, which leaves a duplicate tag with nowhere to go:
`Vacances` sits beside `Holidays` and neither can absorb the other.
`update_tag` now refuses that rename itself, before the write, and names the
tag already holding the name.

`merge_tags` moves the rows instead. Every leg carrying `from_tag` is rewritten
to carry `into_tag`, and the tag it emptied is deleted. A tag belongs to a
journal rather than to the group around it, so the legs of a split that do not
carry it keep their own tags, and a leg already carrying both ends up with one.
Either tag can be named by name or by id, since Firefly's own tag route takes
either.

It writes once per transaction group and reports nothing but counts while
`dry_run` is true, which is the default. It is not atomic: a failure part way
leaves the groups already written carrying the new tag, keeps the old tag in
place, and says how many moved, because running it again moves what is left.
Merging into a name nothing carries yet is refused rather than guessed at,
because that is a rename, and `update_tag` does a rename in one write.

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
