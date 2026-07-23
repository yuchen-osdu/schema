#!/usr/bin/env bash
#
# Script that bootstraps schema service using Python scripts, that make requests to schema service
#
# Expected environment variables:
# - DATA_PARTITION
# - SCHEMA_URL
# - ENTITLEMENTS_HOST
# - OPENID_PROVIDER_URL
# - OPENID_PROVIDER_CLIENT_ID
# - OPENID_PROVIDER_CLIENT_SECRET

set -euo pipefail

log() {
  echo "[$(date -Iseconds)] $*"
}

fail() {
  echo "[$(date -Iseconds)] ERROR: $*" >&2
  exit 1
}

wait_for_entitlements() {
  log "Waiting for Entitlements service to become reachable..."

  local max_retries=60
  local delay=3

  for ((i=1; i<=max_retries; i++)); do
    local status_code
    status_code=$(curl --location --request GET "${ENTITLEMENTS_HOST}/api/entitlements/v2/groups" \
      --write-out "%{http_code}" --silent --output /dev/null \
      --connect-timeout 5 --max-time 15 \
      --header 'Content-Type: application/json' \
      --header "data-partition-id: ${DATA_PARTITION}" \
      --header "Authorization: Bearer ${ACCESS_TOKEN}")

    if [ "$status_code" == 200 ]; then
      log "Entitlements provisioning completed successfully"
      sleep 5
      return 0
    fi

    log "Entitlements not reachable yet (HTTP ${status_code}, $i/$max_retries)..."
    sleep "$delay"
  done

  fail "Entitlements did not become reachable in time"
}

get_access_token() {
  log "Requesting access token from Keycloak..." >&2

  local token
  token=$(curl -s --location \
    --connect-timeout 5 --max-time 15 \
    "${OPENID_PROVIDER_URL}/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "scope=openid" \
    --data-urlencode "client_id=${OPENID_PROVIDER_CLIENT_ID}" \
    --data-urlencode "client_secret=${OPENID_PROVIDER_CLIENT_SECRET}" \
    | jq -r ".access_token")

  [[ -z "$token" || "$token" == "null" ]] && fail "Failed to obtain access token"

  echo "$token"
}

bootstrap_schema_deploy_shared_schemas() {
  python3 ./scripts/DeploySharedSchemas.py -e -u "${SCHEMA_URL}"/api/schema-service/v1/schemas/system
}

# --- MAIN ---

: "${DATA_PARTITION:?missing}"
: "${SCHEMA_URL:?missing}"
: "${ENTITLEMENTS_HOST:?missing}"
: "${OPENID_PROVIDER_URL:?missing}"
: "${OPENID_PROVIDER_CLIENT_ID:?missing}"
: "${OPENID_PROVIDER_CLIENT_SECRET:?missing}"

log "Starting schema bootstrap..."

ACCESS_TOKEN=$(get_access_token)
export ACCESS_TOKEN
export BEARER_TOKEN="Bearer ${ACCESS_TOKEN}"

wait_for_entitlements

bootstrap_schema_deploy_shared_schemas

touch /tmp/bootstrap_ready
log "Bootstrap finished successfully"

sleep infinity
