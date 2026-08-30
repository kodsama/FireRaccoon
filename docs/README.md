# FireRaccoon documentation

Welcome to the FireRaccoon docs. Start here if you are setting up, deploying, or contributing to the project.

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
| [cosmos-compose.fireraccoon-only.json](examples/cosmos-compose.fireraccoon-only.json) | Cosmos: FireRaccoon only |
| [cosmos-compose.fireraccoon-with-firefly.json](examples/cosmos-compose.fireraccoon-with-firefly.json) | Cosmos: FireRaccoon next to existing Firefly |
| [cosmos-compose.fireraccoon-firefly-stack.json](examples/cosmos-compose.fireraccoon-firefly-stack.json) | Cosmos: FireRaccoon + Firefly + MariaDB |
| [compose.fireraccoon-only.yml](examples/compose.fireraccoon-only.yml) | Docker Compose: FireRaccoon only |
| [compose.fireraccoon-firefly.yml](examples/compose.fireraccoon-firefly.yml) | Docker Compose: FireRaccoon + Firefly + MariaDB |

## Quick links

- [Main README](../README.md)
- [Firefly III](https://docs.firefly-iii.org/)
- [Flutter documentation](https://docs.flutter.dev/)
