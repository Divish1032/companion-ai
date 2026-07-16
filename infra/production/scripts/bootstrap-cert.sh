#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <production.env> <runtime-root>" >&2
  exit 64
fi

environment_file=$1
runtime_root=$2
set -a
# shellcheck disable=SC1090
source "$environment_file"
set +a

for required in DEPLOY_DOMAIN ACME_EMAIL; do
  if [[ -z ${!required:-} ]]; then
    echo "missing required value: $required" >&2
    exit 65
  fi
done

if [[ -e "$runtime_root/certs/live/$DEPLOY_DOMAIN/fullchain.pem" ]]; then
  echo "certificate already exists for $DEPLOY_DOMAIN" >&2
  exit 0
fi

install -d -m 0750 "$runtime_root/certs" "$runtime_root/acme-webroot"

# Port 80 must be reachable from the Internet and unused for HTTP-01 validation.
docker run --rm --network host \
  -v "$runtime_root/certs:/etc/letsencrypt" \
  -v "$runtime_root/acme-webroot:/var/www/certbot" \
  certbot/certbot:v3.1.0 certonly --standalone \
  --non-interactive --agree-tos --no-eff-email \
  --email "$ACME_EMAIL" --domain "$DEPLOY_DOMAIN"
