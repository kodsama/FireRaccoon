# Local mode vs server mode

## Status

Accepted

## Context

FireRacoon began as a thin client: Firefly III holds financial data, and each
device stores Firefly credentials plus FireRacoon preferences in platform
secure storage. Docker originally only served static Flutter web assets, so
every browser still held its own copy of secrets and prefs.

Household Docker deploys need one shared FireRacoon store: first admin sets up
the Firefly connection and users, other people log in, and clearing cookies
must not wipe household configuration or undo history.

## Decision

Ship two deployment modes selected by `FIRERACOON_MODE`:

- `local` (default) — native apps and standalone web; durable state on device
- `server` — Docker / `fireracoon_server`; durable state under `DATA_DIR`

In server mode:

- All FireRacoon state (connection, people, prefs, avatars, undo) lives under
  a mounted `DATA_DIR` (default Compose volume `fireracoon_data`)
- The store is encrypted at rest with envelope encryption. Set
  `DATA_PASSWORD` so every boot unlocks (or creates) the store; end users
  only enter their account password. Empty `DATA_DIR` without the env var may
  use a one-time UI create; an existing locked store without the env var
  prompts the operator to configure `DATA_PASSWORD`.
- Browsers hold only an ephemeral session; the Firefly PAT never ships in
  static assets
- The backend proxies Firefly API calls (`/api/firefly/*`) with the
  server-held PAT and enforces People roles on writes

Financial data remains in Firefly III.

## Consequences

- Docker image runs a Dart backend, not bare nginx
- Operators must set `DATA_PASSWORD` and back up both the volume and the
  password
- Local mode behavior is unchanged for phone/desktop installs
- Native clients talking to a remote FireRacoon server are deferred
