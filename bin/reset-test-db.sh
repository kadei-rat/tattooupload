#!/bin/bash
set -e
shopt -s nullglob

echo "Resetting test database..."

setup() {
    echo "setting up $1"
    psql -f database/setup.sql "$1"
}

TEST_DB_NAME="${DB_NAME:-tattooupload}_test"

dropdb "$TEST_DB_NAME"
createdb "$TEST_DB_NAME"
setup "$TEST_DB_NAME"

echo "Reset complete!"
