#!/usr/bin/env bash
# Backup and restore Firefly III Docker volumes for this repo's compose.yml.
# Follows https://docs.firefly-iii.org/how-to/firefly-iii/advanced/backup/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/compose.yml}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-$(basename "$ROOT" | tr '[:upper:]' '[:lower:]')}"

DB_VOLUME="${PROJECT_NAME}_firefly_db"
UPLOAD_VOLUME="${PROJECT_NAME}_firefly_upload"

usage() {
  cat <<EOF
Usage: $(basename "$0") <backup|restore|volumes> [archive]

  backup [dir]    Write firefly-backup-YYYY-MM-DD.tar.gz to dir (default: ./backups)
  restore <file>  Restore db + upload volumes from archive (stack must be stopped)
  volumes         Print the Docker volume names this script will use

Environment:
  COMPOSE_FILE           Path to compose file (default: repo compose.yml)
  COMPOSE_PROJECT_NAME   Compose project prefix for volume names
EOF
}

require_docker() {
  command -v docker >/dev/null 2>&1 || {
    echo "docker is required" >&2
    exit 1
  }
}

volume_exists() {
  docker volume inspect "$1" >/dev/null 2>&1
}

assert_volumes_exist() {
  local missing=0
  for vol in "$DB_VOLUME" "$UPLOAD_VOLUME"; do
    if ! volume_exists "$vol"; then
      echo "Missing volume: $vol" >&2
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    echo "Start the stack once with: docker compose -f \"$COMPOSE_FILE\" up -d" >&2
    echo "Or set COMPOSE_PROJECT_NAME to match your volume prefix." >&2
    exit 1
  fi
}

cmd_volumes() {
  echo "project=$PROJECT_NAME"
  echo "db=$DB_VOLUME"
  echo "upload=$UPLOAD_VOLUME"
  echo "compose=$COMPOSE_FILE"
}

cmd_backup() {
  require_docker
  assert_volumes_exist

  local out_dir="${1:-$ROOT/backups}"
  mkdir -p "$out_dir"
  local stamp
  stamp="$(date +%F)"
  local archive="$out_dir/firefly-backup-$stamp.tar.gz"
  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/fireracoon-backup.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" EXIT

  mkdir -p "$work/volumes/db" "$work/volumes/upload" "$work/meta"

  echo "Backing up $DB_VOLUME..."
  docker run --rm \
    -v "$DB_VOLUME:/volume:ro" \
    -v "$work/volumes/db:/backup" \
    alpine:3.20 \
    tar -czf /backup/db.tar.gz -C /volume .

  echo "Backing up $UPLOAD_VOLUME..."
  docker run --rm \
    -v "$UPLOAD_VOLUME:/volume:ro" \
    -v "$work/volumes/upload:/backup" \
    alpine:3.20 \
    tar -czf /backup/upload.tar.gz -C /volume .

  # Capture launch config the Firefly docs require for a usable restore.
  cp "$COMPOSE_FILE" "$work/meta/compose.yml"
  {
    echo "PROJECT_NAME=$PROJECT_NAME"
    echo "DB_VOLUME=$DB_VOLUME"
    echo "UPLOAD_VOLUME=$UPLOAD_VOLUME"
    echo "CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "NOTE=Preserve APP_KEY and DB passwords from compose/env; volumes alone are not enough."
  } >"$work/meta/backup.env"

  tar -czf "$archive" -C "$work" volumes meta
  echo "Wrote $archive"
  echo "Keep APP_KEY and database passwords with this archive."
}

cmd_restore() {
  require_docker
  local archive="${1:-}"
  if [[ -z "$archive" || ! -f "$archive" ]]; then
    echo "restore requires an existing archive path" >&2
    usage >&2
    exit 1
  fi

  if docker compose -f "$COMPOSE_FILE" ps -q 2>/dev/null | grep -q .; then
    echo "Stop the stack first: docker compose -f \"$COMPOSE_FILE\" down" >&2
    exit 1
  fi

  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/fireracoon-restore.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$work'" EXIT

  tar -xzf "$archive" -C "$work"
  if [[ ! -f "$work/volumes/db/db.tar.gz" || ! -f "$work/volumes/upload/upload.tar.gz" ]]; then
    echo "Archive is missing volume payloads" >&2
    exit 1
  fi

  # Ensure named volumes exist without starting app containers.
  docker volume create "$DB_VOLUME" >/dev/null
  docker volume create "$UPLOAD_VOLUME" >/dev/null

  echo "Restoring $DB_VOLUME..."
  docker run --rm \
    -v "$DB_VOLUME:/volume" \
    -v "$work/volumes/db:/backup:ro" \
    alpine:3.20 \
    sh -c 'find /volume -mindepth 1 -delete; tar -xzf /backup/db.tar.gz -C /volume'

  echo "Restoring $UPLOAD_VOLUME..."
  docker run --rm \
    -v "$UPLOAD_VOLUME:/volume" \
    -v "$work/volumes/upload:/backup:ro" \
    alpine:3.20 \
    sh -c 'find /volume -mindepth 1 -delete; tar -xzf /backup/upload.tar.gz -C /volume'

  echo "Restore complete. Start with: docker compose -f \"$COMPOSE_FILE\" up -d"
  echo "Confirm APP_KEY and DB passwords still match the backup era."
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    backup) cmd_backup "${1:-}" ;;
    restore) cmd_restore "${1:-}" ;;
    volumes) cmd_volumes ;;
    -h | --help | help | '') usage ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
