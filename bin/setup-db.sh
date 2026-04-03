#!/bin/bash
set -e
shopt -s nullglob

DB_NAME="${DB_NAME:-stickerupload}"
TEST_DB_NAME="${DB_NAME}_test"

setup() {
    echo "setting up $1"
    psql -f database/setup.sql "$1"
}

echo "Setting up databases..."

createdb "$DB_NAME"
createdb "$TEST_DB_NAME"

setup "$DB_NAME"
setup "$TEST_DB_NAME"

echo "Setup complete!"
