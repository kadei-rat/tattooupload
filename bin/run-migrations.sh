#!/bin/bash
set -e
shopt -s nullglob

DB_NAME="${DB_NAME:-stickerupload}"
TEST_DB_NAME="${DB_NAME}_test"

migrate() {
  for file in database/migrations/*.sql; do
    echo "  Running $(basename "$file")"
    psql -f "$file" "$1"
  done
}

echo "Migrating databases..."

migrate "$DB_NAME"
migrate "$TEST_DB_NAME"

echo "migrations complete"
