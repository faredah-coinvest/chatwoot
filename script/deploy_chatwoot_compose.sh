#!/usr/bin/env sh

set -eu

COMPOSE_FILE="docker-compose.production.yaml"
COMPOSE_ENV_FILE=".env"
APP_SERVICES="rails sidekiq"
SKIP_PULL=false
SKIP_MIGRATE=false

usage() {
  cat <<'USAGE'
Usage: script/deploy_chatwoot_compose.sh [options]

Options:
  --stg                    Use docker-compose.stg.yaml
  --compose-file FILE      Use a custom Compose file
  --env-file FILE          Use a custom Compose env file
  --services "SERVICES"    App services to recreate (default: "rails sidekiq")
  --skip-pull              Do not pull app service images
  --skip-migrate           Do not run db:chatwoot_prepare
  -h, --help               Show this help

This script only touches Chatwoot app services. It does not stop Traefik or Redis.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --stg)
      COMPOSE_FILE="docker-compose.stg.yaml"
      COMPOSE_ENV_FILE=".env.stg"
      shift
      ;;
    --compose-file)
      COMPOSE_FILE="${2:?missing value for --compose-file}"
      shift 2
      ;;
    --env-file)
      COMPOSE_ENV_FILE="${2:?missing value for --env-file}"
      shift 2
      ;;
    --services)
      APP_SERVICES="${2:?missing value for --services}"
      shift 2
      ;;
    --skip-pull)
      SKIP_PULL=true
      shift
      ;;
    --skip-migrate)
      SKIP_MIGRATE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "Compose file not found: $COMPOSE_FILE" >&2
  exit 1
fi

if [ ! -f "$COMPOSE_ENV_FILE" ]; then
  echo "Compose env file not found: $COMPOSE_ENV_FILE" >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Docker Compose is not available." >&2
  exit 1
fi

if ! $COMPOSE --env-file "$COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null; then
  echo "Compose configuration is invalid for $COMPOSE_FILE." >&2
  exit 1
fi

echo "Compose file: $COMPOSE_FILE"
echo "Compose env file: $COMPOSE_ENV_FILE"
echo "App services: $APP_SERVICES"
echo "Traefik and Redis will not be recreated by this script."

if [ "$SKIP_PULL" = false ]; then
  echo "Pulling app images..."
  # shellcheck disable=SC2086
  $COMPOSE --env-file "$COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" pull $APP_SERVICES
else
  echo "Skipping image pull."
fi

if [ "$SKIP_MIGRATE" = false ]; then
  echo "Running database preparation..."
  $COMPOSE --env-file "$COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" run --rm --no-deps rails sh -lc \
    'POSTGRES_STATEMENT_TIMEOUT=600s bundle exec rails db:chatwoot_prepare'
else
  echo "Skipping database preparation."
fi

echo "Recreating app services only..."
# shellcheck disable=SC2086
$COMPOSE --env-file "$COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" up -d --no-deps $APP_SERVICES

echo "Current service status:"
$COMPOSE --env-file "$COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" ps rails sidekiq redis traefik || \
  $COMPOSE --env-file "$COMPOSE_ENV_FILE" -f "$COMPOSE_FILE" ps
