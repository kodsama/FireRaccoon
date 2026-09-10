# Firefly III connection

FireRaccoon talks to your Firefly III instance over the **REST API v1**. All data stays on your server; the client only reads and writes through authenticated HTTP requests.

## Authentication methods

### Personal access token (recommended)

1. Log in to Firefly III.
2. Go to **Options → OAuth / Personal access tokens** (exact menu label may vary by version).
3. Create a token with the scopes you need.
4. Paste the token into FireRaccoon **Settings → Firefly III connection**. It is stored in platform secure storage (Keychain on desktop, encrypted browser storage on web).

The app sends:

```http
Authorization: Bearer <token>
Accept: application/vnd.api+json
```

### OAuth 2 (desktop / mobile)

On platforms that support `flutter_web_auth_2`, Settings offers OAuth sign-in:

1. Register an OAuth client in Firefly III with redirect URI `fireraccoon://oauth-callback`.
2. Enter your instance URL and client ID in the connection dialog.
3. Complete the browser authorization flow.

Tokens from OAuth are stored in secure storage the same way as personal access tokens.

## Connection settings

| Setting | Description |
|---------|-------------|
| **Server URL** | Base URL of Firefly III, e.g. `https://firefly.example.com` |
| **Allow insecure HTTP** | Permits `http://` URLs. Refused everywhere unless this is on, and the connection is badged as unencrypted for as long as it is one. Not needed in a server deployment on the web, where the server does the dialling and this app only ever talks to its own origin |
| **Test connection** | Calls `GET /api/v1/about` before saving, without following redirects, so a reverse proxy's sign-in page is told apart from a wrong address |
| **Cosmos SSO** | Signs in to a Cosmos Cloud route standing in front of Firefly III. See [Cosmos Cloud](cosmos-cloud.md) |

The connection carries a lock wherever it is reported: closed and green over
https, open and red over http.

## A server behind a reverse-proxy login

A proxy that requires its own login answers every path with a sign-in page, so
the connection test reports that rather than a wrong address, and offers to sign
in from where it says so. Cosmos Cloud is supported directly; see
[Cosmos Cloud](cosmos-cloud.md).

## Environment variables

## CORS (web deployments)

In **server mode** there is nothing to configure. The page is served by the
process that holds the credentials, so the browser asks its own origin and the
server makes the Firefly call through `/api/firefly`. That is also the only way
to reach a backend on the server's own network: a container name does not
resolve in a browser, and a plain-http address is blocked as mixed content on
an https page. `http://firefly-app:8080` is a perfectly good Server URL here.

In **local mode** on the web, requests go from the user's origin to your
Firefly III host, and browsers block cross-origin API calls unless Firefly
allows them.

**Recommended:** serve FireRaccoon and Firefly III under the same domain via a reverse proxy, e.g.:

- `https://finance.example.com` → FireRaccoon static files
- `https://finance.example.com/api` → Firefly III backend

**Alternative:** enable CORS on Firefly III for your FireRaccoon origin. Consult the [Firefly III documentation](https://docs.firefly-iii.org/) for your version.

Desktop and mobile apps are not subject to browser CORS.

## API endpoints used

| Feature | Endpoint |
|---------|----------|
| Connection test | `GET /api/v1/about` |
| Accounts | `GET /api/v1/accounts` |
| Transactions | `GET /api/v1/transactions` (paginated) |
| Create transaction | `POST /api/v1/transactions` |
| Budgets | `GET /api/v1/budgets` |
| Categories | `GET /api/v1/categories` |
| User / currency | `GET /api/v1/about/user`, currencies endpoints |

Pagination is handled automatically; large datasets are fetched in pages of up to 500 items.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| **Disconnected** after save | Wrong URL or token | Re-test connection; check trailing slashes |
| **401** errors | Expired or revoked token | Generate a new token in Firefly III |
| **CORS error** in browser console | Cross-origin web request | Use a reverse proxy or enable CORS |
| **Insecure HTTP disabled** | `http://` URL with secure mode on | Enable “allow insecure” for local dev, or use HTTPS |
| Empty data | New Firefly instance | Add accounts and transactions in Firefly first |

## Security notes

- Prefer HTTPS in production.
- Personal access tokens are as sensitive as passwords — rotate them if exposed.
