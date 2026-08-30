# ADR-0001: Projection vs prognosis

## Status

Accepted

## Context

FireRaccoon has two on-device forecasting stacks:

1. **`ProjectionService`** — lightweight cashflow bands used by MCP
   `run_projection` and legacy projection params.
2. **`AccountPrognosisService`** — detailed per-account forecast driven by
   recurrences, bills, scheduled transactions, and inclusion flags. This powers
   the `/projection` UI (`PrognosisScreen`).

Agents and docs previously treated them as one feature, which caused routing
confusion (`/prognosis` → `/projection`) and an incomplete MCP surface.

## Decision

- **UI product name:** Prognosis (route `/projection`, settings in
  `prognosisSettingsProvider`).
- **MCP coarse forecast:** keep `run_projection` on `ProjectionService`.
- **Account prognosis** stays UI-only until a dedicated MCP tool is designed
  (large input surface: horizons, inclusion, margins).
- Do not map legacy `ProjectionRoute` query params into prognosis prefs; bare
  `/projection` is the navigation target.

## Consequences

- Docs and ADRs must say “prognosis” for the screen and “projection” for the
  MCP/coarse engine.
- Expanding agent forecasting means adding an explicit prognosis tool, not
  overloading `run_projection`.
