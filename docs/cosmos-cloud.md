# Cosmos Cloud

[Cosmos Cloud](https://cosmos-cloud.io/) is a security-first self-hosting
platform with an app store, reverse proxy, HTTPS, and SSO. FireRaccoon’s web
image runs there as a ServApp: import a
[Cosmos-Compose](https://cosmos-cloud.io/docs/cosmos-compose/) file (JSON or
YAML), or paste the JSON into **Create ServApp**.

Cosmos-Compose is Docker Compose plus Cosmos extensions (`routes`, labels such
as `cosmos-icon`). Unsupported Compose features are ignored on import. Official
docs: [ServApps](https://cosmos-cloud.io/docs/servapps/),
[Cosmos-Compose](https://cosmos-cloud.io/docs/cosmos-compose/).

FireRaccoon runs its own Dart backend (`ghcr.io/kodsama/fireraccoon`), which
serves the web build and proxies the Firefly API through `/api/firefly`. Each
browser user connects under **Settings → Firefly III connection**.

An internal Docker hostname is the right target here, and the shortest path:
the browser only ever talks to FireRaccoon's own origin, and the server makes
the Firefly call over the container network. `http://firefly-app:8080` needs no
CORS configuration and does not leave the host. A public HTTPS URL works too,
and sends every request out to the internet and back.

**Allow HTTP connections** is not needed for an internal address in this mode,
because nothing in the browser dials it.

| Scenario | Import file |
|----------|-------------|
| App only | [`examples/cosmos-compose.fireraccoon-only.json`](examples/cosmos-compose.fireraccoon-only.json) |
| App next to existing Firefly | [`examples/cosmos-compose.fireraccoon-with-firefly.json`](examples/cosmos-compose.fireraccoon-with-firefly.json) |
| App + Firefly III + MariaDB | [`examples/cosmos-compose.fireraccoon-firefly-stack.json`](examples/cosmos-compose.fireraccoon-firefly-stack.json) |

In Cosmos: **ServApps → Import Docker Compose** (or Create ServApp and paste
JSON). Set `TZ`, replace `CHANGE_ME_*` secrets on full stacks, and fix the
Firefly network name if yours differs from `cosmos-Firefly-III-default`.

## App only

Use this when Firefly already runs elsewhere (another host, another Cosmos app,
or the market **Firefly-III** install you will point at by URL). Cosmos isolates
the container and publishes an HTTPS route.

```json
{
  "services": {
    "FireRaccoon": {
      "container_name": "FireRaccoon",
      "image": "ghcr.io/kodsama/fireraccoon:latest",
      "environment": [
        "TZ=Europe/Stockholm"
      ],
      "labels": {
        "cosmos-auto-update": "true",
        "cosmos-force-network-secured": "true",
        "cosmos-icon": "https://raw.githubusercontent.com/kodsama/fireraccoon/main/assets/fireraccoon_logo.png"
      },
      "ports": [],
      "volumes": [],
      "routes": [
        {
          "name": "FireRaccoon",
          "description": "FireRaccoon web UI",
          "useHost": true,
          "target": "http://FireRaccoon:80",
          "mode": "SERVAPP",
          "Timeout": 14400000,
          "ThrottlePerMinute": 12000,
          "BlockCommonBots": true,
          "SmartShield": {
            "Enabled": true
          }
        }
      ],
      "restart": "unless-stopped",
      "mem_limit": "536870912"
    }
  }
}
```

After create: open the FireRaccoon URL → Settings → paste your existing Firefly
HTTPS URL and a personal access token.

## App next to an existing Firefly III

Same pattern as Firefly-Pico: join the Firefly stack network, empty ports, repo
logo, auto-update. Replace `cosmos-Firefly-III-default` with the network shown
on your Firefly container (Cosmos → container → Networks).

```json
{
  "services": {
    "FireRaccoon": {
      "container_name": "FireRaccoon",
      "image": "ghcr.io/kodsama/fireraccoon:latest",
      "environment": [
        "TZ=Europe/Stockholm"
      ],
      "labels": {
        "cosmos-auto-update": "true",
        "cosmos-force-network-mode": "cosmos-Firefly-III-default",
        "cosmos-icon": "https://raw.githubusercontent.com/kodsama/fireraccoon/main/assets/fireraccoon_logo.png",
        "cosmos.stack": "Firefly-III"
      },
      "ports": [],
      "volumes": [],
      "networks": {
        "cosmos-Firefly-III-default": {}
      },
      "routes": [
        {
          "name": "FireRaccoon",
          "description": "FireRaccoon web UI",
          "useHost": true,
          "target": "http://FireRaccoon:80",
          "mode": "SERVAPP",
          "Timeout": 14400000,
          "ThrottlePerMinute": 12000,
          "BlockCommonBots": true,
          "SmartShield": {
            "Enabled": true
          }
        }
      ],
      "restart": "unless-stopped",
      "network_mode": "cosmos-Firefly-III-default",
      "mem_limit": "536870912"
    }
  }
}
```

In Settings, still use Firefly’s **public** Cosmos URL, not
`http://Firefly-III:8080`.

## App + Firefly III + MariaDB (full stack)

Import
[`examples/cosmos-compose.fireraccoon-firefly-stack.json`](examples/cosmos-compose.fireraccoon-firefly-stack.json)
when you want one stack with Firefly, MariaDB, and FireRaccoon.

Before apply:

1. Set `APP_KEY` to a random 32-character string (keep a backup).
2. Set matching `DB_PASSWORD` / `MARIADB_PASSWORD` and a root password.
3. After Firefly’s first-run wizard, create a token and enter Firefly’s public
   URL in FireRaccoon Settings.

Prefer the official Cosmos market **Firefly-III** app plus the “app next to
Firefly” snippet above if you already use market installs and Whiskers
passwords; the full-stack file is for a self-contained import.

## Labels and routes

| Field | Role |
|-------|------|
| `image` | Baked Flutter web plus the Dart backend that serves and proxies it |
| `ports` | Empty: Cosmos `routes` terminate HTTPS |
| `volumes` | None on FireRaccoon (static UI) |
| `cosmos-icon` | [`assets/fireraccoon_logo.png`](../assets/fireraccoon_logo.png) |
| `cosmos-force-network-secured` | Isolated Cosmos network (app only) |
| `cosmos-force-network-mode` / `cosmos.stack` | Join an existing Firefly stack |
| `routes` → `target` | Proxy to container port **80** (`SERVAPP`) |

## CORS

If the browser blocks API calls, enable CORS on Firefly for the FireRaccoon
origin (see [Firefly connection](firefly-connection.md)) or put both under one
hostname with an `/api` path proxy ([Deployment](deployment.md)).

## Putting Firefly III behind a Cosmos login

A Cosmos route with authentication on gates every request on its own `jwttoken`
cookie, so a client that only holds a Firefly token reaches the sign-in page
instead of the API. FireRaccoon signs in to that route under **Settings → Cosmos
SSO**: it opens the route in a web view, Cosmos runs its own authorization-code
exchange with the `__route_<name>` client it provisions per route, and the
cookie it sets at the end is kept in the same keychain item as the Firefly
credentials.

Nothing needs configuring in Cosmos. The route client already accepts the
callback it uses, and Cosmos strips `jwttoken` before forwarding, so Firefly
never sees it and the personal access token keeps working unchanged.

The session is sent only to the host it was minted for, and dropped the moment
Cosmos turns a request away. The embedded MCP server carries the same session,
so an agent reaches the ledger through the same gate; it never signs in itself,
because that needs a person.

Testing a connection to such a route reports it as a sign-in rather than a wrong
address, and offers the sign-in from there.

## Updates

With `cosmos-auto-update: "true"`, Cosmos can refresh when a new image tag is
available. Manual: pull `ghcr.io/kodsama/fireraccoon:latest` (or a release tag)
and recreate the ServApp. Do not bind-mount host `build/web`.

## Plain Docker Compose

For VPS / Docker Engine without Cosmos, see [Deployment](deployment.md) and the
Compose examples under [`examples/`](examples/).
