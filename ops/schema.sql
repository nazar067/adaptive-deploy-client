CREATE TABLE IF NOT EXISTS administrator(id integer PRIMARY KEY CHECK(id=1), login text NOT NULL UNIQUE, password_hash text NOT NULL);
CREATE TABLE IF NOT EXISTS sessions(token_hash text PRIMARY KEY, expires_at timestamptz NOT NULL);
CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires_at);
