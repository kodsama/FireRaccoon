<p align="center">
  <img src="assets/fireracoon_logo.png" alt="FireRacoon logo" width="96" />
</p>

<h1 align="center">FireRacoon</h1>

<p align="center">
  <strong>The brightest bandit for your budget.</strong><br/>
</p>

<p align="center">
  A cross-platform Flutter client for
  <a href="https://www.firefly-iii.org/">Firefly III</a>.
  Dashboards, budgets, expenses, and on-device forecasts, with an optional MCP server for LLM tools.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44+-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Firefly%20III-API%20v1-FF6B35" alt="Firefly III">
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License">
  <img src="https://img.shields.io/badge/MCP-server-7A5AD6" alt="MCP">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-web-lightgrey" alt="Web">
  <img src="https://img.shields.io/badge/platform-macOS-lightgrey" alt="macOS">
  <img src="https://img.shields.io/badge/platform-Windows-lightgrey" alt="Windows">
  <img src="https://img.shields.io/badge/platform-Linux-lightgrey" alt="Linux">
  <img src="https://img.shields.io/badge/platform-iOS-lightgrey" alt="iOS">
  <img src="https://img.shields.io/badge/platform-Android-lightgrey" alt="Android">
</p>

---

FireRacoon talks to your existing Firefly III instance over the REST API.
Financial data stays on your Firefly server.

**Local installs** (desktop, mobile, standalone web) keep FireRacoon
credentials and preferences in platform secure storage.

**Docker** runs **server mode** (`FIRERACOON_MODE=server`): FireRacoon state
lives in an encrypted volume (`fireracoon_data`). Set `DATA_PASSWORD` so
restarts unlock automatically; users only enter their account password.

## What it does

- **Dashboard** with Insights, Accounts, and Focus layouts (KPIs, cash flow,
  category breakdowns)
- **Accounts and transactions** browse, filter, create, and reconcile against
  Firefly III
- **Budgets** with pacing and month-to-date progress
- **Expenses, income, and transfers** analytics
- **Subscriptions, piggy banks, and liabilities**
- **Prognosis** rich on-device account forecasts (recurrences, bills, scheduled
  transactions); a coarser **projection** engine is also available to agents via
  MCP
- **Theming** light/dark, Classic / Spectrum / Raccoon palettes (six accents
  each), Comfortaa + Roboto Slab
- **Locales** English, French, Swedish, Portuguese, Japanese, Chinese
- **MCP server** accounts, transactions, budgets, projections, and dashboard
  KPIs for LLM clients (desktop embeds it; mobile and web do not)

## Quick start

```bash
git clone https://github.com/kodsama/FireRacoon.git
cd FireRacoon
flutter pub get
flutter run -d chrome
```

Then open **Settings**, enter your Firefly III URL and a personal access token.
Details: [Getting started](docs/getting-started.md) and
[Firefly connection](docs/firefly-connection.md) (tokens, OAuth, CORS).

### Docker

```bash
# App only (Firefly already running elsewhere)
docker compose -f docs/examples/compose.fireracoon-only.yml up -d

# App + Firefly III + MariaDB (replace CHANGE_ME_* first)
docker compose -f docs/examples/compose.fireracoon-firefly.yml up -d

# Local demo: build the web UI from source + Firefly (demo passwords)
docker compose up --build
```

Set `DATA_PASSWORD` so the container unlocks encrypted storage on every
boot; users then only sign in with their account password. Default volume:
`fireracoon_data` → `/data`. Bind-mount alternative: `- ./data/fireracoon:/data`.

| Service | URL |
|---------|-----|
| FireRacoon | http://127.0.0.1:8082 |
| Firefly III (full stack) | http://127.0.0.1:8081 |

First visit: admin setup (Firefly URL + token). Later users sign in on `/login`.

Server and TLS: [Deployment](docs/deployment.md).

### Cosmos Cloud

Import a Cosmos-Compose file under **ServApps → Import Docker Compose** (or
paste into Create ServApp):

| Scenario | File |
|----------|------|
| App only | [cosmos-compose.fireracoon-only.json](docs/examples/cosmos-compose.fireracoon-only.json) |
| App next to existing Firefly | [cosmos-compose.fireracoon-with-firefly.json](docs/examples/cosmos-compose.fireracoon-with-firefly.json) |
| App + Firefly III + MariaDB | [cosmos-compose.fireracoon-firefly-stack.json](docs/examples/cosmos-compose.fireracoon-firefly-stack.json) |

Replace `CHANGE_ME_*` secrets on full stacks. Guide:
[Cosmos Cloud](docs/cosmos-cloud.md).

## MCP

Agents should use the MCP server rather than scraping the UI. Stdio for
Cursor/CLI; TCP when the desktop app is running (see Settings for the bound
port and token).

```bash
FIREFLY_URL=http://localhost:8082/firefly-local FIREFLY_TOKEN=... \
  dart run packages/mcp/bin/fireracoon_mcp.dart
```

Schema discovery: `dart run packages/mcp/bin/fireracoon_mcp.dart schema`.
Sample client config: [docs/mcp-client-config.json](docs/mcp-client-config.json).
Full tool list: [MCP server](docs/mcp-server.md) and [AGENTS.md](AGENTS.md).

## Repository layout

```
lib/                 Flutter app (screens, providers, theme, l10n)
packages/engine/     Models, Firefly client, projection / prognosis
packages/mcp/        Model Context Protocol server (stdio / TCP)
test/                Unit and widget tests
docs/                Guides and ADRs
Dockerfile           Flutter web + fireracoon_server (encrypted DATA_DIR)
compose.yml          Local demo: FireRacoon server mode + Firefly III + MariaDB
openapi.yaml         Firefly REST subset + MCP tool mirrors
```

Stack: Flutter 3.44+ (CI pins 3.44.3), Riverpod, go_router, fl_chart, Firefly
III API v1.

## Development

```bash
flutter test
flutter analyze
dart format lib test
```

CI runs format, analyze, tests, and multi-platform builds on every push.
See [Development](docs/development.md).

## Documentation

| Guide | Topics |
|-------|--------|
| [Docs index](docs/README.md) | All documentation |
| [Getting started](docs/getting-started.md) | Install, configure, first run |
| [Firefly connection](docs/firefly-connection.md) | Tokens, OAuth, CORS |
| [Deployment](docs/deployment.md) | Docker Compose, GHCR, nginx |
| [Cosmos Cloud](docs/cosmos-cloud.md) | ServApp / cosmos-compose |
| [Architecture](docs/architecture.md) | Packages, Riverpod, routing |
| [Development](docs/development.md) | Tests, lint, CI |
| [MCP server](docs/mcp-server.md) | LLM tool integration |
| [Design spec](docs/design-spec.md) | UI tokens and screen reference |
| [AGENTS.md](AGENTS.md) | Agent-oriented MCP workflow |

## License

GPL-3.0 ([LICENSE](LICENSE)). Bundled fonts:
[NOTICE](NOTICE), [assets/fonts/README.md](assets/fonts/README.md).

## Acknowledgements

- [Firefly III](https://www.firefly-iii.org/) self-hosted personal finance
- [Firefly-Pico](https://github.com/firefly-iii/pico) lightweight client inspiration
- [Skrooge](https://skrooge.kde.org/) practical accounting UX inspiration
