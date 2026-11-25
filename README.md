# CLIProxyAPI

Run Claude Code, Codex, and the account management panel behind one HTTPS endpoint. CLIProxyAPI uses round-robin routing with one-hour session affinity. The `cliproxy-data` volume stores configuration and OAuth credentials.

## Deploy with Coolify

Coolify deploys `compose.yaml` as a Docker Compose application and selects the direct mode by default. It generates the public addresses and stores the initial client key (`SERVICE_PASSWORD_64_CLIPROXYAPI`) and management key (`SERVICE_PASSWORD_64_CLIPROXYMANAGEMENT`) in **Environment Variables**. An HTTPS wildcard domain on the server lets Coolify provision TLS automatically. The app refuses to start on a public HTTP route. [Coolify generated domains](https://coolify.io/docs/core/networking/domains#use-generated-domains)

If Coolify has already assigned an HTTP address, replace it in the application's **Domains** with an HTTPS address targeting `cliproxy` on port `8317`, then redeploy. Existing addresses stay assigned when the server wildcard changes. Use the public address once its certificate validates. [Coolify domain configuration](https://coolify.io/docs/core/networking/domains)

## Optional VPN

All modes use `compose.yaml`. Set `COMPOSE_PROFILES` to `direct`, `bundled`, or `external` for both build and runtime, then redeploy the same Coolify application. The application keeps its `cliproxy-data` volume.

- **Direct.** Use the HTTPS address assigned to `cliproxy`.
- **Bundled Gluetun.** Use the HTTPS address assigned to `gluetun`. Make `/dev/net/tun` available on the host and fill in the VPN fields in [.env.example](.env.example). The defaults use a custom WireGuard profile. [Gluetun providers](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)
- **External Gluetun.** Set `GLUETUN_CONTAINER` to the existing Docker container name and allow port `8317` in its `FIREWALL_INPUT_PORTS`. The existing proxy routes HTTPS to Gluetun on that port. Set `CLIPROXY_PUBLIC_URL` to that HTTPS address in Coolify. Redeploy CLIProxyAPI after recreating Gluetun.

## Run on Linux with Docker Compose

Copy `.env.example` to `.env` and generate the two keys.

```sh
docker compose up --build --wait
```

Once startup succeeds, run the health check for the active `COMPOSE_PROFILES` setting.

| Profile | Health check |
| --- | --- |
| `direct` | `docker compose exec -T cliproxy curl -fsS http://127.0.0.1:8317/healthz` |
| `bundled` | `docker compose exec -T cliproxy-bundled curl -fsS http://127.0.0.1:8317/healthz` |
| `external` | `docker compose exec -T cliproxy-external curl -fsS http://127.0.0.1:8317/healthz` |

For HTTPS, point a reverse proxy at the target service on port `8317`. A proxy running on the host can use the port mapping `127.0.0.1:8317:8317` on the target service. To switch network modes locally, run `docker compose down` with the current profile before changing `COMPOSE_PROFILES`.

## Connect accounts and clients

Open `/management.html` on your HTTPS domain and sign in with the generated management key or your own `CLIPROXY_MANAGEMENT_KEY`. Add accounts under **OAuth**. If sign-in redirects to an unreachable `localhost` page, copy the full URL into the panel's callback form. Replace `https://proxy.example.com` in the examples with your HTTPS address. [CLIProxyAPI web panel](https://help.router-for.me/management/webui)

- **Claude Code.** Set `ANTHROPIC_BASE_URL` to `https://proxy.example.com` and `ANTHROPIC_AUTH_TOKEN` to your client key in `~/.claude/settings.json` under `env`.
- **Codex.** Configure a custom provider in `~/.codex/config.toml` with `base_url = "https://proxy.example.com/v1"`, `wire_api = "responses"`, `requires_openai_auth = false`, `supports_websockets = true`, and your client key as `experimental_bearer_token`. Select the custom provider and a model returned by `/v1/models`. [Codex client setup](https://help.router-for.me/agent-client/codex)

The generated client key or `CLIPROXY_API_KEY` seeds an empty volume. After initialization, the service uses the client keys saved in the panel and the seed can be removed from the deployment environment. Check `/healthz` for service status and send `Authorization: Bearer <client-key>` to `/v1/models` to verify client access.

## Update

Redeploy with a rebuild in Coolify or rerun `docker compose up --build --wait` on Linux. The build checks `CLIPROXY_IMAGE` for v8 configuration support before an image can replace the service. Use an image that supports the configuration stored on `cliproxy-data` for an image-only rollback. Rolling back to v7 requires the matching deployment and a backup of its configuration.
