BEGIN;

CREATE TABLE IF NOT EXISTS users (
  user_id      BIGINT PRIMARY KEY,
  created_at   TIMESTAMP NOT NULL,
  country      TEXT,
  acquisition_channel TEXT
);

CREATE TABLE IF NOT EXISTS events (
  event_id     BIGINT PRIMARY KEY,
  user_id      BIGINT NOT NULL REFERENCES users(user_id),
  ts           TIMESTAMP NOT NULL,
  event_name   TEXT NOT NULL,
  device       TEXT,
  page         TEXT
);

CREATE TABLE IF NOT EXISTS orders (
  order_id     BIGINT PRIMARY KEY,
  user_id      BIGINT NOT NULL REFERENCES users(user_id),
  ts           TIMESTAMP NOT NULL,
  amount       NUMERIC(10,2) NOT NULL CHECK (amount >= 0)
);

-- Helpful indexes for analytics queries
CREATE INDEX IF NOT EXISTS idx_events_user_ts ON events(user_id, ts);
CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
CREATE INDEX IF NOT EXISTS idx_orders_user_ts ON orders(user_id, ts);
CREATE INDEX IF NOT EXISTS idx_orders_ts ON orders(ts);

COMMIT;
