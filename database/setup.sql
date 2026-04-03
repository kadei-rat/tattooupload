CREATE TABLE users (
  id BIGINT PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL DEFAULT '',
  username TEXT,
  photo_url TEXT,
  role TEXT NOT NULL DEFAULT 'user',
  ban TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE submissions (
  id SERIAL PRIMARY KEY,
  image_data BYTEA NOT NULL,
  image_filename TEXT NOT NULL,
  image_content_type TEXT NOT NULL,
  width_cm NUMERIC(5,1) NOT NULL,
  user_id BIGINT REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_submissions_status ON submissions(status);
CREATE INDEX idx_submissions_user_id ON submissions(user_id);
