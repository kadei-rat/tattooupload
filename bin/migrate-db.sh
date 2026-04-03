#!/bin/bash
set -e
shopt -s nullglob

./bin/teardown-db.sh

DB_NAME="${DB_NAME:-stickerupload}"
TEST_DB_NAME="${DB_NAME}_test"

setup() {
    echo "setting up $1"
    psql -f database/setup.sql "$1"
    for file in migrations/*.sql; do
      echo "  Running $(basename "$file")"
      psql -f "$file" "$1"
    done
}

echo "Setting up databases..."

createdb "$DB_NAME"
createdb "$TEST_DB_NAME"

# for the main database, migrate rather than setting up
pgloader database/migrate.load
setup "$TEST_DB_NAME"

echo "Setup complete!"
