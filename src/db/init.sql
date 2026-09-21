CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO events (name, payload) VALUES
    ('user_signup', '{"user_id": 1}'),
    ('user_login', '{"user_id": 1}'),
    ('order_created', '{"order_id": 100}'),
    ('order_paid', '{"order_id": 100}'),
    ('order_shipped', '{"order_id": 100}');
