# macOS Single-Node Deployment

Use this for local, staging, and compatibility validation on macOS. A personal
Mac is not a recommended public production host: Docker Desktop must remain
running, the Mac must not sleep, and public access requires a static public IP
or stable dynamic-DNS setup plus router port forwarding. Use Ubuntu for the
Internet-facing phone-testing host whenever possible.

## Prerequisites outside the command

- macOS with Docker Desktop installed, started, and allowed to expose ports.
- Homebrew installed. The deployment command installs `gettext` and `unzip`
  through Homebrew if needed.
- A public DNS hostname resolving to the router's public IPv4 - not the Mac's
  private `192.168.x.x` address.
- Router forwarding and any upstream firewall must allow TCP `80`, `443`,
  `7881`, `5349`; UDP `3478`, `40000-40100`, and `50000-50100` to the Mac.
  Do not expose Redis, API, agent, or Kokoro ports.
- The Mac must stay awake while accepting calls. Configure its power settings
  deliberately; a sleeping Mac cannot renew certificates or serve calls.
- Read-only Git access if cloning a private repository.

## One-command deploy

```bash
git clone git@github.com:Divish1032/companion-ai.git ~/companion-ai
cd ~/companion-ai
git checkout main
./infra/production/scripts/deploy.sh
```

The command prompts for the public hostname, Let's Encrypt email, and public
IPv4. It creates the persistent runtime root at
`~/.local/share/companion-ai`, downloads the Hindi Vosk model, generates the
LiveKit and telemetry secrets, obtains the TLS certificate, starts every
backend service, and installs a per-user `launchd` certificate-renewal job.
The default Vosk URL is the public `rhasspy/vosk-models` mirror; pass an
approved artifact URL with `--vosk-url` if required by your environment.

For a repeatable non-interactive invocation:

```bash
./infra/production/scripts/deploy.sh --non-interactive \
  --domain voice.example.com \
  --email ops@example.com \
  --node-ip 203.0.113.10 \
  --vosk-url 'https://your-approved-artifacts.example/vosk-model-small-hi-0.22.zip'
```

`--node-ip` must be the public router IP that phones see, never a private LAN
address. If the public IP changes, update DNS and rerun the command with the
new IP before testing WebRTC.

## Runtime environment file

The command creates `~/.local/share/companion-ai/production.env` with mode
`0600`. Do not put production secrets in the repository or in a project `.env`.
After the first deployment, add only these optional values there:

```dotenv
# Enables the already-configured Sarvam fallback; restart the agent afterwards.
AGENT_SARVAM_API_KEY=

# Required only for an explicit EmbeddingGemma artifact preparation flow.
# Supplying it alone does not enable the optional model features.
HF_TOKEN=
```

Apply an environment-only change with:

```bash
cd ~/companion-ai
docker compose --env-file ~/.local/share/companion-ai/production.env \
  -f infra/production/docker-compose.yml up -d realtime-agent api
```

Check the public entry point after deployment:

```bash
curl --fail https://voice.example.com/health
```
