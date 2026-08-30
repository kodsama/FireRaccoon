# Development

## Setup

```bash
flutter pub get
```

Engine and MCP packages resolve via path dependencies — no separate `pub get` is required unless you edit them in isolation:

```bash
cd packages/engine && dart pub get
cd packages/mcp && dart pub get
```

## Running tests

```bash
# All Flutter app tests (120)
flutter test

# Engine package (44)
cd packages/engine && dart test

# MCP server package (12)
cd packages/mcp && dart test
```

Tests run fully offline against mocks — no live Firefly instance is needed.

## Static analysis and formatting

```bash
flutter analyze
dart format lib test
```

Lint rules: `flutter_lints` via `analysis_options.yaml`. CI also runs `dart format --set-exit-if-changed`.

## Code generation

Localization files are generated automatically on `flutter pub get` / build when `flutter: generate: true` is set in `pubspec.yaml`.

If you add Mockito mocks:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Adding translations

1. Edit `lib/l10n/app_en.arb` (template).
2. Mirror keys in `app_fr.arb`, `app_sv.arb`, `app_pt.arb`, `app_ja.arb`, and `app_zh.arb`.
3. Run `flutter gen-l10n` or `flutter pub get`.
4. Register the locale in `lib/providers/locale_provider.dart` if adding a new language.

## Project conventions

- **Providers** for state; keep widgets mostly declarative
- **Pure logic** in `packages/engine` or `lib/utils/` — test without Flutter bindings
- **Public APIs** use `///` doc comments
- Match existing naming and file layout when adding screens

## Branching

| Branch | Role |
|--------|------|
| `dev` | Integration branch for ongoing work |
| `main` | Stable line; release tags must point here |

Open a pull request from `dev` to `main` when ready to ship. Do not release
from `dev` tip alone — see [Deployment](deployment.md#github-releases-01-100-).

## CI pipeline

`.github/workflows/ci.yml`:

| Job | What it does |
|-----|----------------|
| `lint-and-test` | Format, analyze, `flutter test` |
| `build-desktop` | macOS, Windows, Linux release builds |
| `build-mobile` | Android APK, iOS (no codesign) |
| `build-web` | `flutter build web --release` |

Flutter version is pinned with `FLUTTER_VERSION: 3.44.3` in the workflow env block.

## Useful commands

```bash
flutter devices                    # List run targets
flutter run -d chrome              # Web dev
flutter run -d macos               # Desktop dev
flutter build web --release        # Production web (static assets only)
docker compose up --build          # Full local stack
docker compose up -d --build --force-recreate fireraccoon
# ^ Rebuild after lib/ changes. Compose serves the baked image, not ./build/web.
```

## Test coverage areas

| Area | Test location |
|------|----------------|
| Projection algorithm | `test/services/projection_service_test.dart` |
| Dashboard stats / periods | `test/utils/` |
| Theme & colors | `test/theme/` |
| Routing & query params | `test/router/` |
| Screens (widget) | `test/screens/` |
| Firefly models | `test/models/firefly_api_models_test.dart` |

## Troubleshooting dev issues

| Issue | Fix |
|-------|-----|
| `.env` not found at runtime | Ensure `.env` exists at project root (see `.env.example`) |
| Secure storage on Linux | Install libsecret / use a supported keyring |
| Web OAuth redirect fails | OAuth is primarily for desktop/mobile; use token auth on web |
| `flutter analyze` errors in `packages/mcp` | Run `dart pub get` inside `packages/mcp` |
