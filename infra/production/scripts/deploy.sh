#!/usr/bin/env bash
# Interactive, repeatable single-node deployment for Ubuntu and macOS.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
platform=$(uname -s)
runtime_root=${COMPANION_RUNTIME_ROOT:-}
deploy_domain=${DEPLOY_DOMAIN:-}
acme_email=${ACME_EMAIL:-}
node_ip=${LIVEKIT_NODE_IP:-}
# The Vosk origin's TLS certificate has intermittently been unavailable. This
# public mirror contains the same named upstream model; deployments can point
# to an organisation-approved artifact source with --vosk-url instead.
vosk_url=${VOSK_MODEL_URL:-https://huggingface.co/rhasspy/vosk-models/resolve/main/hi/vosk-model-small-hi-0.22.zip?download=true}
non_interactive=false
use_sudo_docker=false
host_user=${SUDO_USER:-$USER}

usage() {
  cat <<'EOF'
Usage: infra/production/scripts/deploy.sh [options]

Options:
  --domain <hostname>       Public DNS name for HTTPS and LiveKit.
  --email <address>         Let's Encrypt renewal contact.
  --node-ip <IPv4>          Public IPv4 advertised by LiveKit.
  --runtime-root <path>     Persistent data root.
  --vosk-url <https-url>    Hindi Vosk model ZIP source.
  --non-interactive         Fail rather than prompt for missing input.
EOF
}

while (($#)); do
  case $1 in
    --domain) deploy_domain=${2:?missing hostname}; shift 2 ;;
    --email) acme_email=${2:?missing email}; shift 2 ;;
    --node-ip) node_ip=${2:?missing IPv4}; shift 2 ;;
    --runtime-root) runtime_root=${2:?missing path}; shift 2 ;;
    --vosk-url) vosk_url=${2:?missing URL}; shift 2 ;;
    --non-interactive) non_interactive=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

fail() { echo "deploy: $*" >&2; exit 1; }
note() { echo "deploy: $*"; }

ask_required() {
  local variable=$1 prompt=$2 value=${!variable:-}
  if [[ -z $value && $non_interactive == true ]]; then
    fail "missing required option: $prompt"
  fi
  while [[ -z $value ]]; do
    read -r -p "$prompt: " value
  done
  printf -v "$variable" '%s' "$value"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

confirm_external_prerequisites() {
  note "Before certificate issuance, $deploy_domain must resolve to $node_ip."
  note "Its cloud firewall/router must allow TCP 80, 443, 7881, 5349 and UDP 3478, 40000-40100, 50000-50100."
  if [[ $non_interactive == false ]]; then
    local reply
    read -r -p "Confirm those external prerequisites are complete [y/N]: " reply
    [[ $reply =~ ^[Yy]([Ee][Ss])?$ ]] || fail "complete DNS and external firewall/router configuration, then rerun"
  fi
}

valid_ipv4() {
  local candidate=$1 octet
  [[ $candidate =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a octets <<< "$candidate"
  for octet in "${octets[@]}"; do
    ((10#$octet <= 255)) || return 1
  done
}

docker_exec() {
  if [[ $use_sudo_docker == true ]]; then
    sudo docker "$@"
  else
    command docker "$@"
  fi
}

if [[ $platform == Linux ]]; then
  [[ -r /etc/os-release ]] || fail "unsupported Linux distribution"
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ ${ID:-} == ubuntu ]] || fail "only Ubuntu is supported on Linux"
  runtime_root=${runtime_root:-/opt/companion/runtime}
elif [[ $platform == Darwin ]]; then
  runtime_root=${runtime_root:-$HOME/.local/share/companion-ai}
else
  fail "supported platforms are Ubuntu and macOS"
fi

ask_required deploy_domain "Public DNS hostname"
ask_required acme_email "Let's Encrypt contact email"
ask_required node_ip "Public IPv4 for LiveKit"
[[ $deploy_domain != *://* && $deploy_domain != */* && $deploy_domain != *:* ]] || fail "DEPLOY_DOMAIN must be a hostname without a scheme, path, or port"
valid_ipv4 "$node_ip" || fail "LIVEKIT_NODE_IP must be a valid public IPv4 address"
confirm_external_prerequisites

install_ubuntu_dependencies() {
  if ! command_exists docker; then
    note "installing Docker Engine and Compose plugin"
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg gettext-base unzip
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu %s stable\n' \
      "$(dpkg --print-architecture)" "$VERSION_CODENAME" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$host_user"
  else
    sudo apt-get update
    sudo apt-get install -y gettext-base unzip
    docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin is missing; install Docker Engine with the Compose plugin, then rerun"
  fi
}

install_macos_dependencies() {
  command_exists docker || fail "install and start Docker Desktop, then rerun this command"
  command_exists brew || fail "install Homebrew (for gettext and unzip), then rerun this command"
  if ! command_exists envsubst; then
    brew install gettext
    export PATH="$(brew --prefix gettext)/bin:$PATH"
  fi
  command_exists unzip || brew install unzip
}

if [[ $platform == Linux ]]; then
  install_ubuntu_dependencies
else
  install_macos_dependencies
fi

command_exists docker || fail "Docker installation did not complete"
command_exists openssl || fail "openssl is required"
if docker info >/dev/null 2>&1; then
  :
elif [[ $platform == Linux ]] && sudo docker info >/dev/null 2>&1; then
  # A newly installed Docker Engine has not yet refreshed this shell's docker
  # group membership. Use sudo for this run; later runs use the normal socket.
  use_sudo_docker=true
  export COMPANION_DOCKER_SUDO=true
else
  fail "Docker daemon is not running or is not accessible"
fi
command_exists envsubst || fail "envsubst is required"
command_exists unzip || fail "unzip is required"

if [[ $platform == Linux ]]; then
  sudo install -d -o "$host_user" -g "$(id -gn "$host_user")" -m 0750 "$runtime_root"
else
  install -d -m 0750 "$runtime_root"
fi
install -d -m 0750 "$runtime_root"/{acme-webroot,certs,config,data/api,data/redis,evidence,models/huggingface,models}

environment_file="$runtime_root/production.env"
set_env() {
  local key=$1 value=$2 temporary
  temporary=$(mktemp "${environment_file}.XXXXXX")
  if [[ -f $environment_file ]]; then
    awk -v key="$key" -v value="$value" '
      $0 ~ "^" key "=" { print key "=" value; found=1; next }
      { print }
      END { if (!found) print key "=" value }
    ' "$environment_file" > "$temporary"
  else
    printf '%s=%s\n' "$key" "$value" > "$temporary"
  fi
  chmod 600 "$temporary"
  mv "$temporary" "$environment_file"
}

get_env() {
  [[ -f $environment_file ]] || return 0
  sed -n "s/^$1=//p" "$environment_file" | tail -1
}

set_env DEPLOY_DOMAIN "$deploy_domain"
set_env ACME_EMAIL "$acme_email"
set_env RUNTIME_ROOT "$runtime_root"
set_env LIVEKIT_NODE_IP "$node_ip"
set_env LIVEKIT_API_KEY "$(get_env LIVEKIT_API_KEY || true)"
[[ -n $(get_env LIVEKIT_API_KEY || true) ]] || set_env LIVEKIT_API_KEY companion
if [[ -z $(get_env LIVEKIT_API_SECRET || true) ]]; then set_env LIVEKIT_API_SECRET "$(openssl rand -hex 32)"; fi
if [[ -z $(get_env API_TELEMETRY_INGEST_TOKEN || true) ]]; then set_env API_TELEMETRY_INGEST_TOKEN "$(openssl rand -hex 32)"; fi
set_env API_ENABLE_MEMORY_EXTRACTION "$(get_env API_ENABLE_MEMORY_EXTRACTION || true)"
[[ -n $(get_env API_ENABLE_MEMORY_EXTRACTION || true) ]] || set_env API_ENABLE_MEMORY_EXTRACTION true
set_env API_MEMORY_EXTRACTION_BASE_URL "$(get_env API_MEMORY_EXTRACTION_BASE_URL || true)"
[[ -n $(get_env API_MEMORY_EXTRACTION_BASE_URL || true) ]] || set_env API_MEMORY_EXTRACTION_BASE_URL https://api.sarvam.ai/v1
set_env API_MEMORY_EXTRACTION_API_KEY "$(get_env API_MEMORY_EXTRACTION_API_KEY || true)"
set_env API_MEMORY_EXTRACTION_MODEL "$(get_env API_MEMORY_EXTRACTION_MODEL || true)"
[[ -n $(get_env API_MEMORY_EXTRACTION_MODEL || true) ]] || set_env API_MEMORY_EXTRACTION_MODEL sarvam-30b
set_env API_MEMORY_EXTRACTION_TIMEOUT_SECONDS "$(get_env API_MEMORY_EXTRACTION_TIMEOUT_SECONDS || true)"
[[ -n $(get_env API_MEMORY_EXTRACTION_TIMEOUT_SECONDS || true) ]] || set_env API_MEMORY_EXTRACTION_TIMEOUT_SECONDS 20
set_env HF_TOKEN "$(get_env HF_TOKEN || true)"
set_env AGENT_SARVAM_API_KEY "$(get_env AGENT_SARVAM_API_KEY || true)"
chmod 600 "$environment_file"

vosk_dir="$runtime_root/models/vosk-model-small-hi-0.22"
if [[ ! -f $vosk_dir/am/final.mdl ]]; then
  note "downloading the Hindi Vosk model from $vosk_url"
  archive=$(mktemp "${TMPDIR:-/tmp}/vosk-hi.XXXXXX.zip")
  temporary_model=$(mktemp -d "${TMPDIR:-/tmp}/vosk-hi.XXXXXX")
  trap 'rm -f "$archive"; rm -rf "$temporary_model"' EXIT
  curl --fail --location --proto '=https' --tlsv1.2 --output "$archive" "$vosk_url"
  unzip -q "$archive" -d "$temporary_model"
  extracted="$temporary_model/vosk-model-small-hi-0.22"
  [[ -f $extracted/am/final.mdl ]] || fail "downloaded archive does not contain the expected Vosk model"
  rm -rf "$vosk_dir"
  mv "$extracted" "$vosk_dir"
  trap - EXIT
  rm -f "$archive"; rm -rf "$temporary_model"
fi

"$repo_root/infra/production/scripts/render-config.sh" "$environment_file" "$runtime_root"

if [[ $platform == Linux ]]; then
  if command_exists ufw && sudo ufw status | head -1 | grep -q 'Status: active'; then
    for rule in 80/tcp 443/tcp 7881/tcp 5349/tcp 3478/udp 40000:40100/udp 50000:50100/udp; do
      sudo ufw allow "$rule"
    done
  else
    note "UFW is not active; configure host firewall policy separately if you enable one."
  fi
fi

"$repo_root/infra/production/scripts/bootstrap-cert.sh" "$environment_file" "$runtime_root"
docker_exec compose --env-file "$environment_file" -f "$repo_root/infra/production/docker-compose.yml" up -d --build

if [[ $platform == Linux ]]; then
  sed -e "s|__REPO_ROOT__|$repo_root|g" -e "s|__RUNTIME_ROOT__|$runtime_root|g" \
    "$repo_root/infra/production/systemd/companion-cert-renew.service" \
    | sudo tee /etc/systemd/system/companion-cert-renew.service >/dev/null
  sudo install -m 0644 "$repo_root/infra/production/systemd/companion-cert-renew.timer" /etc/systemd/system/companion-cert-renew.timer
  sudo systemctl daemon-reload
  sudo systemctl enable --now companion-cert-renew.timer
else
  plist="$HOME/Library/LaunchAgents/com.companion-ai.cert-renew.plist"
  install -d "$HOME/Library/LaunchAgents"
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.companion-ai.cert-renew</string>
  <key>ProgramArguments</key><array><string>$repo_root/infra/production/scripts/renew-cert.sh</string><string>$repo_root/infra/production/docker-compose.yml</string><string>$environment_file</string></array>
  <key>StartInterval</key><integer>43200</integer>
  <key>RunAtLoad</key><true/>
</dict></plist>
EOF
  launchctl bootout "gui/$(id -u)" "$plist" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
fi

for _ in $(seq 1 30); do
  if curl --fail --silent --show-error "https://$deploy_domain/health" >/dev/null; then
    break
  fi
  sleep 2
done
curl --fail --silent --show-error "https://$deploy_domain/health" >/dev/null
note "deployment is healthy: https://$deploy_domain/health"
