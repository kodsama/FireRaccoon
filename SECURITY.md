# Security policy

## Supported versions

| Version | Supported |
|---------|-----------|
| latest `main` | yes |
| tagged releases | yes, latest patch only |

## Reporting a vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Email **kodsama@protonmail.com** with:

- Description of the issue and potential impact
- Steps to reproduce (proof-of-concept if available)
- FireRaccoon version or commit hash
- Your environment (platform, Firefly III version if relevant)

We aim to acknowledge reports within 72 hours and will coordinate disclosure
once a fix is available.

## Scope

In scope:

- FireRaccoon app, MCP server, and bundled tooling in this repository
- Credential handling, transport security, and auth flows

Out of scope:

- Vulnerabilities in your self-hosted Firefly III instance
- Issues requiring physical access to an unlocked device with stored credentials
- Social engineering against Firefly III administrators

## Safe defaults

- `.env` is gitignored — never commit Firefly tokens
- Web builds must not embed credentials; users connect via Settings
- The Docker Compose stack ships **demo-only** passwords — change them before any network exposure (see [Deployment](docs/deployment.md))
