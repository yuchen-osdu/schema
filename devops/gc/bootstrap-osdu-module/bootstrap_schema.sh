#!/usr/bin/env bash
#
# Script that bootstraps schema service using Python scripts, that make requests to schema service
# Contains logic for both Reference and Google Cloud version
#
# Expected environment variables:
# (both environments):
# - DATA_PARTITION
# - SCHEMA_URL
# - ENTITLEMENTS_HOST
# (for Google Cloud):
# - AUDIENCES
# (for Reference):
# - OPENID_PROVIDER_URL
# - OPENID_PROVIDER_CLIENT_ID
# - OPENID_PROVIDER_CLIENT_SECRET

set -e

source ./validate-env.sh "SCHEMA_URL"
source ./validate-env.sh "ENTITLEMENTS_HOST"

bootstrap_schema_gettoken_gc() {

  BEARER_TOKEN=$(gcloud auth print-identity-token)

  export BEARER_TOKEN
}

bootstrap_schema_precheck_env() {

  local max_retries=30
  local retry_count=0
  local status_code=0


  echo "Starting Entitlements provisioning precheck (connecting to ${ENTITLEMENTS_HOST})..."
  while [ $retry_count -lt $max_retries ]; do
    status_code=$(curl --retry 1 --location --globoff --request GET "${ENTITLEMENTS_HOST}/api/entitlements/v2/groups" \
      --write-out "%{http_code}" --silent --output "/opt/system-groups.json" \
      --header 'Content-Type: application/json' \
      --header 'data-partition-id: system' \
      --header "Authorization: Bearer ${BEARER_TOKEN}")

    if [ "$status_code" == 200 ]; then
      echo "$status_code: Entitlements provisioning completed successfully!"
      if jq -r '.groups[].name' /opt/system-groups.json | grep -q "schema-service.system-admin"; then                                                                                                                                                                                                                      
        echo "All necessary permissions granted! Starting the bootstrap"
        rm /opt/system-groups.json
        return 0
      else
        echo "System permissions were not granted"
      fi 
    fi

    retry_count=$((retry_count + 1))
    echo "Attempt $retry_count/$max_retries failed (status: $status_code). Retrying in 10 seconds..."
    sleep 10
  done

  echo "Error: Entitlements provisioning precheck failed after $max_retries attempts."
  exit 1
}

bootstrap_schema_deploy_shared_schemas() {
  python3 ./scripts/DeploySharedSchemas.py -e -u "${SCHEMA_URL}"/api/schema-service/v1/schemas/system
}

# Specifying "system" partition for GC installation
export DATA_PARTITION="system"

# Get credentials for Google Cloud
bootstrap_schema_gettoken_gc

# Precheck entitlements
bootstrap_schema_precheck_env

# Deploy shared schemas
bootstrap_schema_deploy_shared_schemas
