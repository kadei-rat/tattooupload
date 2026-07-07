#!/usr/bin/env bash
# Print, for each submission, the image filename and the submitter's
# Telegram first name + username.
set -euo pipefail

# Load DATABASE_URL from .env if not already set in the environment.
if [[ -z "${DATABASE_URL:-}" && -f "$(dirname "$0")/../.env" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$(dirname "$0")/../.env"; set +a
fi

psql "$DATABASE_URL" -P pager=off -c "
  SELECT
    s.image_filename AS filename,
    u.first_name,
    u.username
  FROM submissions s
  LEFT JOIN users u ON u.id = s.user_id
  ORDER BY s.created_at;
"
