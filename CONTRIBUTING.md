# Contributing to FireRacoon

Thank you for your interest in FireRacoon! This document explains how to get
set up and submit changes.

## Before you start

1. Read [Getting started](docs/getting-started.md) and [Development](docs/development.md).
2. Search existing [issues](https://github.com/kodsama/fireracoon/issues) to avoid duplicate work.
3. For large features, open an issue first to discuss approach.

## Development setup

```bash
git clone https://github.com/kodsama/fireracoon.git
cd fireracoon
flutter pub get
cp .env.example .env   # optional: local Firefly credentials for desktop debug
flutter run -d chrome
```

Tests run offline against mocks — no live Firefly instance required:

```bash
flutter test
cd packages/engine && dart test
dart test packages/mcp
```

Enable the local pre-commit hook (mirrors CI):

```bash
bash tool/setup-hooks.sh
```

## Branching and releases

- Day-to-day work lands on `dev`.
- Merge `dev` → `main` with a pull request (do not push straight to `main`).
- Version tags and GitHub Releases come only from commits already on `main`.
  See [Deployment](docs/deployment.md#github-releases-01-100-).

## Pull request checklist

- [ ] `dart format` applied to changed Dart paths
- [ ] `flutter analyze` and package tests pass
- [ ] New behavior has tests when practical
- [ ] User-facing changes update `docs/` or `README.md`
- [ ] MCP tool changes update `openapi.yaml`, `docs/mcp-server.md`, and `AGENTS.md`
- [ ] No secrets, tokens, or personal data in commits

## Code conventions

- Keep business logic in `packages/engine`; Flutter UI in `lib/`
- Use Riverpod providers for state
- Match existing naming and file layout
- Prefer `///` doc comments on public APIs

## Translations

Edit `lib/l10n/app_en.arb` (template) and mirror keys in other locale files.
Run `flutter gen-l10n` after changes.

## License

By contributing, you agree that your contributions will be licensed under the
[GPL-3.0 License](LICENSE).
