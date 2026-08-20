# Deployment

FireRacoon ships as a Flutter **web** build served by nginx in Docker. Tagged
releases also build Android, iOS, macOS, Windows, and Linux installers via
`.github/workflows/release.yml`.

## GitHub Releases (`0.1`, `1.0.0`, …)

Releases ship only from `main`. Integration work lands on `dev` and reaches
`main` through a pull request — never by pushing a version tag from `dev`
alone.

1. Land changes on `dev`.
2. Open a PR `dev` → `main` and merge it.
3. On `main`, bump `version:` in root `pubspec.yaml` (for example `0.1.1+1`)
   if that bump was not already in the PR. The part before `+` is the release
   name; the part after is the build number shown in Settings.
4. Tag and push from `main` only, using the bare version name (never a `v`
   prefix):

```bash
git checkout main
git pull
# After pubspec version: 0.1.1+1
git tag 0.1.1
git push origin 0.1.1
```

The release workflow fails early if:

- the tagged commit is not on `main`, or
- the tag does not match the pubspec version name

Do not tag `0.1.1+1`; GitHub / GHCR use the name only (`0.1.1`).

GitHub immutable releases permanently reserve a tag name once a release for it
has been published. Deleting that release does not free the name; bump the
version instead. Do not invent a `v`-prefixed twin of a burned tag.

Pushing a version tag that points at `main` builds every platform in parallel
and attaches artifacts to a GitHub Release for that tag:
| Platform | Artifacts |
|----------|-----------|
| Android | `*.apk`, `*.aab`, Linux MCP binary |
| iOS | unsigned `*.ipa` |
| macOS | `FireRacoon-macos.dmg`, macOS MCP binary |
| Windows | Inno `*.exe` installer, WiX `*.msi`, raw Release `.zip`, Windows MCP binary |
| Linux | `*.AppImage`, `*.deb`, `*.rpm`, bundle `.tar.gz`, Linux MCP binary |
| Web | `FireRacoon-web.tar.gz` |
| Docker | `ghcr.io/<owner>/fireracoon:<tag>` (and `:latest`), `linux/amd64` + `linux/arm64` |

Every `flutter build` uses `--obfuscate --split-debug-info=build/symbols/<platform>`.
Keep the uploaded `*-symbols` artifacts to de-obfuscate crash traces.

All GUI installers are **unsigned**. Store / notarized distribution needs secrets
(Android keystore, Apple certs, Windows code-signing). Without them: Gatekeeper
blocks the macOS DMG on other machines, unsigned IPAs cannot install on devices,
Windows SmartScreen warns, and Android packages stay debug-key signed.

Packaging configs: `distribute_options.yaml`, `windows/packaging/exe/`,
`linux/packaging/{appimage,deb,rpm}/`, `packaging/windows/product.wxs`,
`packaging/linux/`.

## Docker (web only)

The Dockerfile is a multi-stage build: Flutter compiles arch-independent
`build/web` on the host (`BUILDPLATFORM`), then `fireracoon_server` is AOT-compiled
on the image's target arch (`TARGETPLATFORM`, via QEMU when cross-building
arm64). The runtime image runs that binary on port 8080 with `DATA_DIR=/data`.
Release CI pushes a multi-arch manifest (`linux/amd64`, `linux/arm64`). Nothing
from the host `./build/web` directory is mounted at runtime; app state belongs
on the `fireracoon_data` volume.

Tagged releases publish that image to GHCR (anonymous pull; package is public):

```bash
docker pull ghcr.io/kodsama/fireracoon:latest
docker run -p 8082:8080 ghcr.io/kodsama/fireracoon:latest
```

Pin a version with the release tag, e.g. `ghcr.io/kodsama/fireracoon:0.1`.
Inspect platforms with `docker buildx imagetools inspect ghcr.io/kodsama/fireracoon:latest`.

### Build and run one container

```bash
docker build -t fireracoon .
docker run -p 8082:80 fireracoon
```

Open http://localhost:8082.

### Docker Compose

Two ready-made files under [`examples/`](examples/). Run them from the **repo
root**. Both publish on loopback only; put a reverse proxy in front for TLS.

#### App only

When Firefly already runs somewhere else:

```bash
docker compose -f docs/examples/compose.fireracoon-only.yml up -d
# FireRacoon → http://127.0.0.1:8082
```

```yaml
services:
  fireracoon:
    image: ghcr.io/kodsama/fireracoon:latest
    ports:
      - "127.0.0.1:8082:80"
    restart: unless-stopped
```

Open FireRacoon, set Server URL to your existing Firefly HTTPS (or HTTP)
endpoint, paste a token. Full file:
[`examples/compose.fireracoon-only.yml`](examples/compose.fireracoon-only.yml).

#### App + Firefly III + MariaDB

```bash
# Edit CHANGE_ME_* in the file first (APP_KEY must be 32 characters).
docker compose -f docs/examples/compose.fireracoon-firefly.yml up -d
# FireRacoon → http://127.0.0.1:8082
# Firefly III → http://127.0.0.1:8081
```

```yaml
services:
  fireracoon:
    image: ghcr.io/kodsama/fireracoon:latest
    ports:
      - "127.0.0.1:8082:80"
    restart: unless-stopped

  firefly-app:
    image: fireflyiii/core:latest
    ports:
      - "127.0.0.1:8081:8080"
    depends_on: [firefly-db]
    environment:
      APP_KEY: "CHANGE_ME_32_CHARS_OF_RANDOM_KEY"
      DB_CONNECTION: mysql
      DB_HOST: firefly-db
      DB_DATABASE: firefly
      DB_USERNAME: firefly
      DB_PASSWORD: "CHANGE_ME_DB_PASSWORD"
      TRUSTED_PROXIES: "**"
    volumes:
      - firefly_upload:/var/www/html/storage/upload

  firefly-db:
    image: mariadb:10.11
    environment:
      MYSQL_USER: firefly
      MYSQL_PASSWORD: "CHANGE_ME_DB_PASSWORD"
      MYSQL_DATABASE: firefly
      MYSQL_RANDOM_ROOT_PASSWORD: "yes"
    volumes:
      - firefly_db:/var/lib/mysql

volumes:
  firefly_upload:
  firefly_db:
```

Full file:
[`examples/compose.fireracoon-firefly.yml`](examples/compose.fireracoon-firefly.yml).

1. Open Firefly, finish the installer, create a personal access token.
2. Open FireRacoon → Settings → URL `http://127.0.0.1:8081` (or your public
   HTTPS URL behind a proxy) → paste the token. Enable “allow insecure HTTP”
   for local `http://`.

Volumes `firefly_upload` and `firefly_db` persist Firefly data.

#### Local demo from repo root

Root [`compose.yml`](../compose.yml) builds FireRacoon from source and starts
the same three services with **demo** passwords (localhost only):

```bash
docker compose up --build
```

| Service | Published port | URL |
|---------|----------------|-----|
| FireRacoon (`fireracoon`) | `127.0.0.1:8082` → 80 | http://127.0.0.1:8082 |
| Firefly III (`firefly-app`) | `8081` → 8080 | http://localhost:8081 |
| MariaDB (`firefly-db`) | none | internal only |

After editing app source, rebuild and recreate the web service:

```bash
docker compose up -d --build --force-recreate fireracoon
```

Hard-refresh the browser if an old `main.dart.js` is cached.

### Deploy on a server with Docker Compose

Use the example files above (or root `compose.yml`) when the host should serve
FireRacoon beyond a laptop. Do not leave demo passwords or open Firefly ports
on the public internet.

**1. Prepare the host**

- Docker Engine and Compose v2
- A reverse proxy that terminates TLS (Caddy, nginx, Traefik, or a cloud LB)
- DNS for the hostname you will use (e.g. `finance.example.com`)

**2. Choose a layout**

| Goal | Command |
|------|---------|
| App only (Firefly elsewhere) | `docker compose -f docs/examples/compose.fireracoon-only.yml up -d` |
| App + Firefly + DB | Edit secrets, then `docker compose -f docs/examples/compose.fireracoon-firefly.yml up -d` |
| Build UI from this git checkout | Uncomment `build.context` in the example, or use root `compose.yml` |

**3. Harden before first `up`**

| Change | Why |
|--------|-----|
| New random `APP_KEY` (32 chars) | Firefly encryption key; keep a backup |
| New matching DB passwords | Placeholders / demo passwords are not secrets |
| Ports | Keep `127.0.0.1:…` and terminate TLS on the host, or attach services only to the proxy Docker network |

Then proxy `https://finance.example.com` → `127.0.0.1:8082` and
`https://finance.example.com/api/` → `127.0.0.1:8081/api/` (see nginx example
below). Same-origin `/api` avoids browser CORS.

**4. First boot**

1. Open Firefly over HTTPS, finish the installer, create a personal access token.
2. Open FireRacoon, set the Firefly URL to the **public** HTTPS origin users will
   call (same origin as the app if you proxy `/api`), paste the token, test connection.
3. Confirm volumes exist: `docker volume ls | grep firefly`.

**5. Updates**

```bash
# GHCR image (examples/)
docker compose -f docs/examples/compose.fireracoon-only.yml pull
docker compose -f docs/examples/compose.fireracoon-only.yml up -d

# Built from this repo
git pull
docker compose up -d --build --force-recreate fireracoon
```

Firefly / MariaDB keep data in named volumes across image updates. Still run
backups before major upgrades.

### Cosmos Cloud

App only, app next to Firefly, or full Firefly stack on
[Cosmos Cloud](https://cosmos-cloud.io/): see [Cosmos Cloud](cosmos-cloud.md)
and the JSON files under [`examples/`](examples/).

### What backs up what

Three separate things, and only the first can rebuild a working instance:

| | Covers | Leaves out | Taken from |
|---|---|---|---|
| `tool/firefly_backup.sh` | Firefly database, uploaded attachments, `compose.yml` | nothing needed to restore, given `APP_KEY` | the server shell |
| **Back up Firefly data** (Settings) | accounts, transactions with every split, budgets, categories, tags, bills, piggy banks, recurring rules, currencies | database, attachments, `APP_KEY`, budget limits, rules, webhooks | the app, or `export_firefly_data` over MCP |
| **Export settings** (Settings) | people, roles, account assignments and classifications, layout, preferences, the Firefly URL | agent keys, your Firefly data, profile photos, biometrics | the app |

The data export is a portable, readable snapshot, useful for taking before a
bulk change so there is something to compare against, and reachable over MCP so
an agent can take one first. It is not a substitute for the volume archive: an
API client cannot reach the database, the attachments or the instance key.

### Backup and restore (Docker)

Firefly III has no built-in backup. For this Compose stack, use
[`tool/firefly_backup.sh`](../tool/firefly_backup.sh), which follows the
[Firefly Docker backup guide](https://docs.firefly-iii.org/how-to/firefly-iii/advanced/backup/):
it archives the `firefly_db` and `firefly_upload` volumes plus a copy of
`compose.yml`.

```bash
# Show volume names this project will use
bash tool/firefly_backup.sh volumes

# Write backups/firefly-backup-YYYY-MM-DD.tar.gz
bash tool/firefly_backup.sh backup

# Restore (stop the stack first)
docker compose down
bash tool/firefly_backup.sh restore backups/firefly-backup-2026-07-29.tar.gz
docker compose up -d
```

Store `APP_KEY` and database passwords with the archive. Volumes alone cannot
rebuild a working Firefly instance. After any restore, run a trial restore on
a throwaway machine before you need it.

Cron example (daily at 01:01):

```cron
1 1 * * * cd /path/to/FireRacoon && bash tool/firefly_backup.sh backup /var/backups/firefly
```

### Demo credentials (local only)

The bundled `compose.yml` uses **fixed, non-production** values so you can
spin up a stack quickly:

| Setting | Default | Notes |
|---------|---------|-------|
| `APP_KEY` | 32-char placeholder | Change before any shared/network use |
| `DB_PASSWORD` / `MYSQL_PASSWORD` | `secret_firefly_password` | Demo only |

These passwords are intentional for local development and are **not secrets**.
Never expose this Compose stack to the internet without replacing every default
credential and enabling TLS.

### Credentials

#### Local mode (`FIRERACOON_MODE=local`)

Credentials are never embedded in builds or images. Users connect once via
**Settings → Firefly III connection**; values stay in platform secure storage.

#### Server mode (Docker, `FIRERACOON_MODE=server`)

- Set `DATA_PASSWORD` in Compose / secrets. On every boot the server uses
  it to **create** (empty `DATA_DIR`) or **unlock** the encrypted store.
  End users then only enter their **account** password at `/login`.
- If the store already exists and `DATA_PASSWORD` is missing, the UI
  tells the operator to set the env var (optional emergency unlock only).
- If `DATA_DIR` is empty and the env var is unset, a one-time create form
  appears; after that, put the same password in `DATA_PASSWORD` so
  restarts unlock automatically.
- Mount durable state on volume `fireracoon_data` (default) or a bind path:
  `./data/fireracoon:/data`.
- Do not put the storage password inside `DATA_DIR`. Back up the volume and
  keep `DATA_PASSWORD` safe separately.
- After unlock, first visit runs admin setup (URL + token + admin user) unless
  you bootstrap `FIREFLY_URL` / `FIREFLY_TOKEN`.

## Manual web build

```bash
flutter pub get
flutter build web --release
```

Serve `build/web/` with any static file server (nginx, Caddy, `dart pub global run dhttpd`, etc.).

## Production checklist

- [ ] Use HTTPS for both FireRacoon and Firefly III
- [ ] Put a reverse proxy in front (nginx, Traefik, Caddy)
- [ ] Same-origin proxy for `/api` to avoid CORS (see [Firefly connection](firefly-connection.md))
- [ ] Change `APP_KEY` and database passwords in `compose.yml`
- [ ] Bind Compose ports to `127.0.0.1` (or omit host publishes) so only the proxy is public
- [ ] Do not bake production tokens into images
- [ ] Deploy via image rebuild or GHCR pull; do not bind-mount host `build/web`
- [ ] Enable HTTP caching headers for static assets (`main.dart.js`, fonts)

## Example nginx reverse proxy

Host nginx in front of Compose services published on loopback:

```nginx
server {
    listen 443 ssl;
    server_name finance.example.com;

    # FireRacoon static web app (Compose → 127.0.0.1:8082)
    location / {
        proxy_pass http://127.0.0.1:8082;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # Firefly III API (same origin — no CORS)
    location /api/ {
        proxy_pass http://127.0.0.1:8081/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

If nginx runs in Docker on the same Compose network, replace the upstreams with
service names (`http://fireracoon:80`, `http://firefly-app:8080/api/`) and do not
publish those container ports on the host.

## Desktop and mobile

CI builds **unsigned** release artifacts for macOS, Windows, Linux, Android APK,
and iOS. Android release builds in this repo still use the debug keystore so
`flutter build apk --release` works out of the box — store distribution requires
your own signing config (see `.github/workflows/release.yml` comments).

Distribution is platform-specific:

| Platform | Command |
|----------|---------|
| macOS | `flutter build macos --release` |
| Windows | `flutter build windows --release` |
| Linux | `flutter build linux --release` |
| Android | `flutter build apk --release` |
| iOS | `flutter build ios --release` (requires Xcode signing for devices) |

Code signing, notarization, and store submission are outside this guide.

## CI builds

GitHub Actions (`.github/workflows/ci.yml`) runs on every push and pull request:

1. Format check, `flutter analyze`, and `flutter test`
2. Parallel release builds for all supported platforms

Set `FLUTTER_VERSION` in the workflow to match your local SDK when upgrading.
