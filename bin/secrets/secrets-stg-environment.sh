#!/bin/bash

# Set these variables in the current shell with:
# source ./bin/secrets/secrets-stg-environment.sh

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo >&2 "This script must be sourced: source ./bin/secrets/secrets-stg-environment.sh"
  exit 1
fi

_opal_fetch_staging_secret() {
  az keyvault secret show --vault-name opal-stg --name "$1" 2>/dev/null \
    | jq -er '.value | select(type == "string" and length > 0)' 2>/dev/null
}

_opal_load_staging_secrets() {
  if [[ "$-" == *x* ]]; then
    echo >&2 "Bash xtrace is enabled. Run 'set +x' before sourcing this script to protect secret values."
    return 1
  fi

  local aad_client_id
  local aad_client_secret
  local aad_tenant_id
  local opal_test_user_password
  local launch_darkly_sdk_key

  command -v az >/dev/null 2>&1 || {
    echo >&2 'The "az" command is required. Install Azure CLI and run "az login" before sourcing this script.'
    return 1
  }
  command -v jq >/dev/null 2>&1 || {
    echo >&2 'The "jq" command is required before sourcing this script.'
    return 1
  }

  echo "Retrieving staging secrets from Azure Key Vault..."

  aad_client_id="$(_opal_fetch_staging_secret AzureADClientId)" || return 1
  aad_client_secret="$(_opal_fetch_staging_secret AzureADClientSecret)" || return 1
  aad_tenant_id="$(_opal_fetch_staging_secret AzureADTenantId)" || return 1
  opal_test_user_password="$(_opal_fetch_staging_secret OpalTestUserPassword)" || return 1
  launch_darkly_sdk_key="$(_opal_fetch_staging_secret launch-darkly-sdk-key)" || return 1

  export AAD_CLIENT_ID="$aad_client_id"
  export AAD_CLIENT_SECRET="$aad_client_secret"
  export AAD_TENANT_ID="$aad_tenant_id"
  export OPAL_TEST_USER_PASSWORD="$opal_test_user_password"
  export LAUNCH_DARKLY_SDK_KEY="$launch_darkly_sdk_key"

  # Local database variables used by the Gradle Flyway tasks.
  export FLYWAY_URL="jdbc:postgresql://localhost:5432/opal-maintenance-db"
  export FLYWAY_USER="opal-db-user"
  export FLYWAY_PASSWORD="opal-db-password"

  echo "Staging secrets and local Flyway settings were exported to the current shell."
}

if _opal_load_staging_secrets; then
  unset -f _opal_fetch_staging_secret _opal_load_staging_secrets
  return 0
else
  echo >&2 "Unable to export staging secrets. Check Azure login and Key Vault access, then try again."
  unset -f _opal_fetch_staging_secret _opal_load_staging_secrets
  return 1
fi
