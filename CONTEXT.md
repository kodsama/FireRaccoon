# FireRacoon domain context

Glossary for agents and humans working in this repo. Prefer these terms in
code comments, ADRs, and MCP descriptions.

## Core systems

| Term | Meaning |
|------|---------|
| **Firefly III** | External personal-finance API FireRacoon talks to |
| **Engine** | `packages/engine` — models, Firefly client, projection/prognosis, stats |
| **MCP surface** | Intentional subset of engine capabilities exposed as agent tools |
| **Projection** | Coarse on-device forecast (`ProjectionService` / MCP `run_projection`) |
| **Prognosis** | Rich account forecast in the UI (`AccountPrognosisService`) |
| **Write-ahead** | Materializing upcoming recurrence occurrences as future transactions |
| **Reconciliation** | Marking journals reconciled and optionally posting a correction; for `ccAsset` accounts, also creating a multi-split payback transfer |

## Money objects

| Term | Meaning |
|------|---------|
| **Account** | Firefly asset/expense/revenue/liability account |
| **Transaction / journal** | A Firefly transaction group; may contain **splits** |
| **totalAmount** | Sum of split amounts (use this, not first-split `amount`) |
| **Budget** | Firefly budget with optional auto-budget amount |
| **Bill / subscription** | Recurring payable tracked as a Firefly bill |
| **Recurrence** | Firefly repeating transaction rule |
| **Piggy bank** | Saved-toward goal linked to an account |

## Agent access

MCP tools are the supported agent API. They intentionally omit full CRUD for
bills, recurrences, piggies, search, and prognosis. Expand `buildTools()` when
a workflow needs them; keep OpenAPI `x-mcp.tools` and `docs/mcp-server.md` in
sync.
