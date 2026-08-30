# Getting started

FireRaccoon is a cross-platform Flutter client for [Firefly III](https://www.firefly-iii.org/). It runs on the web, desktop (macOS, Windows, Linux), and mobile (iOS, Android).

## Prerequisites

| Tool | Version |
|------|---------|
| [Flutter](https://docs.flutter.dev/get-started/install) | 3.44+ (stable channel; CI pins 3.44.3) |
| [Dart](https://dart.dev/get-dart) | 3.12+ (bundled with Flutter) |
| Firefly III | Any recent instance with API v1 enabled |

Optional for containerized setup:

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2

## 1. Clone and install

```bash
git clone https://github.com/kodsama/fireraccoon.git
cd fireraccoon
flutter pub get
```

## 2. Configure Firefly III credentials

Configure credentials in the app under **Settings → Firefly III connection** after launch. Values saved in the UI are stored in platform secure storage (Keychain on desktop, encrypted browser storage on web) and persist across app updates and redeployments. No credentials are ever baked into a build.

See [Firefly connection](firefly-connection.md) for token creation, OAuth, and CORS.

## 3. Run the app

**Web (recommended for development):**

```bash
flutter run -d chrome
```

**macOS:**

```bash
flutter run -d macos
```

**Other platforms:** use `flutter devices` to list available targets, then `flutter run -d <device-id>`.

## 4. Full stack with Docker Compose

**App only** (Firefly already elsewhere):

```bash
docker compose -f docs/examples/compose.fireraccoon-only.yml up -d
```

**App + Firefly III + MariaDB** (edit `CHANGE_ME_*` secrets first):

```bash
docker compose -f docs/examples/compose.fireraccoon-firefly.yml up -d
```

**Local demo from source** (root `compose.yml`, demo passwords, loopback UI):

```bash
docker compose up --build
```

1. Open Firefly III at http://127.0.0.1:8082/firefly-local (full stack) and complete the setup wizard.
2. Create a personal access token in Firefly III.
3. Open FireRaccoon at http://127.0.0.1:8082 and enter `http://127.0.0.1:8082/firefly-local` plus your token in Settings. Enable “allow insecure HTTP” for local `http://` URLs.

After changing app source with the root compose file:

```bash
docker compose up -d --build --force-recreate fireraccoon
```

Server, TLS, and [Cosmos Cloud](https://cosmos-cloud.io/) imports: [Deployment](deployment.md), [Cosmos Cloud](cosmos-cloud.md).

## What you should see

After a successful connection:

- The sidebar shows **Firefly III · connected**.
- Dashboard KPIs, accounts, transactions, budgets, and expenses load from your instance.
- The **Projection** screen runs balance forecasts on-device using your transaction history.

## Next steps

- [Deployment](deployment.md) — production web builds and reverse-proxy patterns
- [Cosmos Cloud](cosmos-cloud.md) — ServApp next to Firefly on Cosmos
- [Architecture](architecture.md) — how the app is structured
- [Development](development.md) — running tests and contributing
