# Companion AI Command Guide

Run commands from the repository root unless a command says otherwise. Do not
put keys in source files or commit any `.env` / `production.env` file.

## 1. Local development: macOS or Ubuntu

Required tools: Docker Desktop on macOS, or Docker Engine with the Compose
plugin on Ubuntu; Flutter; `uv`; and Python 3.12. Confirm them first:

```bash
docker --version
docker compose version
flutter --version
uv --version
```

Create the local Compose configuration, install dependencies, and start the
stack:

```bash
cp -n .env.example .env
make setup
docker compose --env-file .env -f infra/docker-compose.yml up -d --build
```

For real local Hindi Vosk STT, download the model once:

```bash
mkdir -p models
curl --fail --location --output /tmp/vosk-model-small-hi-0.22.zip \
  'https://huggingface.co/rhasspy/vosk-models/resolve/main/hi/vosk-model-small-hi-0.22.zip?download=true'
unzip -q /tmp/vosk-model-small-hi-0.22.zip -d models
test -f models/vosk-model-small-hi-0.22/am/final.mdl
```

Check and debug the local stack:

```bash
docker compose --env-file .env -f infra/docker-compose.yml ps
docker compose --env-file .env -f infra/docker-compose.yml logs -f api
docker compose --env-file .env -f infra/docker-compose.yml logs -f realtime-agent
curl --fail http://localhost:8000/health
curl --fail http://localhost:8000/readiness
curl --fail http://localhost:8001/readiness
make check
```

Stop local services without deleting persistent local Docker volumes:

```bash
docker compose --env-file .env -f infra/docker-compose.yml down
```

Do not use `down -v` unless you deliberately want to remove local Redis, API,
and model-cache data.

## 2. Run the Flutter app

```bash
cd apps/mobile

# Android emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS simulator or a host-local desktop target
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

For a physical phone on the same Wi-Fi, substitute the development computer's
LAN IPv4 address:

```bash
cd /path/to/companion-ai
API_LIVEKIT_URL=ws://<host-lan-ip>:7880 LIVEKIT_NODE_IP=<host-lan-ip> \
  docker compose --env-file .env -f infra/docker-compose.yml up -d --build

cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://<host-lan-ip>:8000
```

Enable bounded phone-side memory extraction only after the API has a real
`API_MEMORY_EXTRACTION_API_KEY`:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://<reachable-api-host>:8000 \
  --dart-define=ENABLE_MEMORY_EXTRACTION=true
```

## 3. Fresh production deployment: Ubuntu 22.04/24.04

Before running the deploy command, point DNS at the server public IP and open
these cloud-firewall/security-group ports:

```text
TCP: 80, 443, 7881, 5349
UDP: 3478, 40000-40100, 50000-50100
```

From the Ubuntu server, clone with read-only Git access and deploy. The script
installs Docker Engine/Compose if absent, prompts for the domain/email/public
IP, obtains TLS, downloads Vosk, and starts every backend service.

```bash
git clone git@github.com:Divish1032/companion-ai.git /opt/companion/app
cd /opt/companion/app
git checkout main
./infra/production/scripts/deploy.sh
```

The runtime file is created here and must remain private:

```text
/opt/companion/runtime/production.env
```

## 4. Fresh production deployment: macOS

Install and start Docker Desktop and install Homebrew before this step. For a
public Mac, DNS must point to the router's public IP and the same TCP/UDP ports
must be forwarded to the Mac. Keep the Mac awake. Ubuntu is the preferred
Internet-facing host.

```bash
git clone git@github.com:Divish1032/companion-ai.git ~/companion-ai
cd ~/companion-ai
git checkout main
./infra/production/scripts/deploy.sh
```

The macOS runtime file is:

```text
~/.local/share/companion-ai/production.env
```

## 5. Operate an existing production host

Set the directory and runtime path for the host you are operating:

```bash
# Ubuntu: run these two lines
cd /opt/companion/app
environment_file=/opt/companion/runtime/production.env

# macOS: run these two lines instead
cd ~/companion-ai
environment_file="$HOME/.local/share/companion-ai/production.env"
```

Then define the Compose helper:

```bash
compose() {
  docker compose --env-file "$environment_file" \
    -f infra/production/docker-compose.yml "$@"
}
```

Status and logs:

```bash
compose ps
compose logs -f api
compose logs -f realtime-agent
compose logs -f livekit
curl --fail https://<domain>/health
curl --fail https://<domain>/readiness
```

Deploy the latest committed `main` code:

```bash
git pull --ff-only origin main
compose up -d --build
```

Edit production configuration without displaying its contents:

```bash
# Ubuntu
sudoedit "$environment_file"

# macOS
"${EDITOR:-vi}" "$environment_file"
```

After adding or changing the API memory-extraction key, restart only API:

```bash
compose up -d api
```

After adding or changing the realtime Sarvam key, restart only the agent:

```bash
compose up -d realtime-agent
```

Prepare and enable the pinned EmbeddingGemma artifact only after `HF_TOKEN` is
set in `production.env` and its Hugging Face terms have been accepted:

```bash
compose --profile model-maintenance run --rm model-prep
sudoedit "$environment_file" # set API_ENABLE_MEMORY_EMBEDDINGS=true
compose up -d --build api
curl --fail https://<domain>/readiness
```

The final readiness response must show `"embedding": {"enabled": true,
"state": "ready"}`. Keep reranker and planner disabled: they require a
separate GPU-capacity validation and are not part of the current CPU host.

Safe stop/start commands:

```bash
compose down
compose up -d
```

Do not add `-v` to the production `down` command: it can remove persistent
service data.

## 6. Production certificates and phone run

On Ubuntu, certificate renewal is installed as a systemd timer:

```bash
systemctl status companion-cert-renew.timer
sudo systemctl start companion-cert-renew.service
```

On macOS, the deployment script installs a per-user `launchd` renewal job. Its
status and an on-demand renewal command are:

```bash
launchctl print "gui/$(id -u)/com.companion-ai.cert-renew"
./infra/production/scripts/renew-cert.sh \
  infra/production/docker-compose.yml "$environment_file"
```

Run the Flutter app against production:

```bash
cd apps/mobile
flutter run \
  --dart-define=API_BASE_URL=https://<domain> \
  --dart-define=ENABLE_MEMORY_EXTRACTION=true
```

`ENABLE_MEMORY_EXTRACTION=true` is meaningful only after
`API_MEMORY_EXTRACTION_API_KEY` is set in the production runtime file and API
has been restarted.

## References

- [Repository overview](README.md)
- [Ubuntu deployment details](docs/deployment/ubuntu.md)
- [macOS deployment details](docs/deployment/macos.md)
- [Production environment reference](infra/production/.env.example)
