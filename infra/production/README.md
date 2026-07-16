# Production single-node deployment

This directory deploys the Sprint 9 Ubuntu shape without exposing Redis, the
API container, the realtime agent, or Kokoro to the public Internet.

It uses LiveKit's embedded TURN server, not a separate coturn container. This
is deliberate: LiveKit mints and supplies TURN credentials to the Flutter SDK
over the authenticated signaling connection. The server exposes TURN/UDP on
`3478`, TURN/TLS on `5349`, LiveKit TCP fallback on `7881`, and media UDP on
`50000-50100`.

## Required input

`DEPLOY_DOMAIN` must be a real DNS name pointing to the VM before certificate
issuance. The host cannot securely serve the mobile app from a bare IP address.
The initial deployment starts with EmbeddingGemma disabled until a user who has
accepted its Hugging Face terms provides a read-only `HF_TOKEN` and the model
artifact has been prepared and checked through `/readiness`.

## Host command order

Run these commands from `/opt/companion/app` after copying the repository:

```bash
sudo install -d -o itachi -g itachi -m 0750 /opt/companion/runtime
cp infra/production/.env.example /opt/companion/runtime/production.env
chmod 600 /opt/companion/runtime/production.env
# Edit production.env with the real domain/email; generate secrets on-host.
infra/production/scripts/render-config.sh /opt/companion/runtime/production.env /opt/companion/runtime
infra/production/scripts/bootstrap-cert.sh /opt/companion/runtime/production.env /opt/companion/runtime
docker compose --env-file /opt/companion/runtime/production.env -f infra/production/docker-compose.yml up -d --build
```

The provisioning command creates the runtime layout and a 4 GiB swap file,
uploads the Vosk model, installs firewall rules, and installs the renewal timer.
It does **not** mint a TLS certificate before DNS has been configured.
