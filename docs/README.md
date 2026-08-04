# FireRacoon documentation

Welcome to the FireRacoon docs. Start here if you are setting up, deploying, or contributing to the project.

## Guides

| Document | Description |
|----------|-------------|
| [Getting started](getting-started.md) | Prerequisites, first run, and connecting to Firefly III |
| [Firefly connection](firefly-connection.md) | Personal access tokens, OAuth 2, CORS, and troubleshooting |
| [Deployment](deployment.md) | Docker Compose (local and server), GHCR, TLS, reverse proxy |
| [Cosmos Cloud](cosmos-cloud.md) | Cosmos-Compose ServApp next to Firefly III |
| [Architecture](architecture.md) | Project layout, state management, routing, and packages |
| [Development](development.md) | Tests, linting, localization, and CI |
| [MCP server](mcp-server.md) | Model Context Protocol tools for LLM clients |
| [Design specification](design-spec.md) | UI tokens, screens, and visual fidelity reference |

## Config files

| File | Description |
|------|-------------|
| [mcp-client-config.json](mcp-client-config.json) | Ready-to-copy MCP server entry for Cursor / Claude Desktop |
| [../LICENSE](../LICENSE) | GPL-3.0 license |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | How to contribute |
| [../SECURITY.md](../SECURITY.md) | Vulnerability reporting |
| [../.env.example](../.env.example) | Environment variable template for Firefly credentials |
| [cosmos-compose.fireracoon-only.json](examples/cosmos-compose.fireracoon-only.json) | Cosmos: FireRacoon only |
| [cosmos-compose.fireracoon-with-firefly.json](examples/cosmos-compose.fireracoon-with-firefly.json) | Cosmos: FireRacoon next to existing Firefly |
| [cosmos-compose.fireracoon-firefly-stack.json](examples/cosmos-compose.fireracoon-firefly-stack.json) | Cosmos: FireRacoon + Firefly + MariaDB |
| [compose.fireracoon-only.yml](examples/compose.fireracoon-only.yml) | Docker Compose: FireRacoon only |
| [compose.fireracoon-firefly.yml](examples/compose.fireracoon-firefly.yml) | Docker Compose: FireRacoon + Firefly + MariaDB |

## Quick links

- [Main README](../README.md)
- [Firefly III](https://docs.firefly-iii.org/)
- [Flutter documentation](https://docs.flutter.dev/)
