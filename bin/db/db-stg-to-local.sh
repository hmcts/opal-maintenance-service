#!/bin/bash
set -e
umask 077

PRIVATE_TEMP_DIR=""

cleanup() {
  unset PGPASSWORD
  if [ -n "$PRIVATE_TEMP_DIR" ] && [ -d "$PRIVATE_TEMP_DIR" ]; then
    rm -rf -- "$PRIVATE_TEMP_DIR"
  fi
}

run_with_pgpassword() (
  trap 'unset PGPASSWORD' EXIT
  export PGPASSWORD="$1"
  shift
  "$@"
)

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

echo "*** WARNING: This script will destroy your local OPAL API database and restore it from staging. ***"
echo "It requires \"az\" \"pg_dump\" and \"psql\", and you must also be connected to the HMCTS VPN and have a postgres database running locally."

command -v jq >/dev/null 2>&1 || { echo >&2 "I require \"jq\" but it's not installed. Aborting."; exit 1; }
command -v az >/dev/null 2>&1 || { echo >&2 "I require \"az\" but it's not installed. Aborting."; exit 1; }
command -v pg_dump >/dev/null 2>&1 || { echo >&2 "I require \"pg_dump\" but it's not installed. Aborting."; exit 1; }
command -v psql >/dev/null 2>&1 || { echo >&2 "I require \"psql\" but it's not installed. Aborting."; exit 1; }

read -r -p 'Are you sure you want to continue (y/n): ' continue
if [ "$continue" != "y" ]
then
  exit 1
fi

echo "Fetching secrets from staging key-vault..."

PRIVATE_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opal-maintenance-stg-to-local.XXXXXX")"
DUMP_FILE="$PRIVATE_TEMP_DIR/opal-api-stg-dump.sql"
RESTORE_OUTPUT="$PRIVATE_TEMP_DIR/opal-api-local-stdout.log"

SCHEMA="public"
DATABASE="$(az keyvault secret show --vault-name opal-stg --name maintenance-service-POSTGRES-DATABASE | jq .value -r)"

LOCAL_HOST="localhost"
LOCAL_USER="opal-db-user"
LOCAL_PASSWORD="opal-db-password"

STG_HOST="$(az keyvault secret show --vault-name opal-stg --name maintenance-service-POSTGRES-HOST | jq .value -r)"
STG_USER="$(az keyvault secret show --vault-name opal-stg --name maintenance-service-POSTGRES-USER | jq .value -r)"
STG_PASSWORD="$(az keyvault secret show --vault-name opal-stg --name maintenance-service-POSTGRES-PASS | jq .value -r)"
STG_PORT="$(az keyvault secret show --vault-name opal-stg --name maintenance-service-POSTGRES-PORT | jq .value -r)"

echo "Dumping staging database..."

run_with_pgpassword "$STG_PASSWORD" \
  pg_dump -h "$STG_HOST" -p "$STG_PORT" -U "$STG_USER" -n "$SCHEMA" -d "$DATABASE" > "$DUMP_FILE"

echo "Dump complete, dump file: $DUMP_FILE"
echo "Restoring local database..."

if ! run_with_pgpassword "$LOCAL_PASSWORD" \
  psql -X -v ON_ERROR_STOP=1 --single-transaction \
  -h "$LOCAL_HOST" -U "$LOCAL_USER" -d "$DATABASE" \
  -c "DROP SCHEMA IF EXISTS \"$SCHEMA\" CASCADE" -f "$DUMP_FILE" \
  > "$RESTORE_OUTPUT" 2>&1
then
  echo >&2 "Restore failed; the local schema transaction was rolled back."
  exit 1
fi

echo "Restore complete."
