#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <compose-file> <production.env>" >&2
  exit 64
fi

compose_file=$1
environment_file=$2
docker compose --env-file "$environment_file" -f "$compose_file" \
  --profile maintenance run --rm certbot renew --webroot -w /var/www/certbot --quiet
docker compose --env-file "$environment_file" -f "$compose_file" exec -T gateway nginx -s reload
