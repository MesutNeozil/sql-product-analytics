BEGIN;

-- Sanity user/event/order 
INSERT INTO users (user_id, created_at, country, acquisition_channel)
VALUES (1, NOW(), 'SG', 'tiktok')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO events (event_id, user_id, ts, event_name, device, page)
VALUES (1, 1, NOW(), 'view_product', 'ios', '/product/123')
ON CONFLICT (event_id) DO NOTHING;

INSERT INTO orders (order_id, user_id, ts, amount)
VALUES (1, 1, NOW(), 19.90)
ON CONFLICT (order_id) DO NOTHING;

-- Seed users
INSERT INTO users (user_id, created_at, country, acquisition_channel) VALUES
(2, NOW() - INTERVAL '10 days', 'SG', 'instagram'),
(3, NOW() - INTERVAL '9 days',  'MY', 'google'),
(4, NOW() - INTERVAL '8 days',  'ID', 'tiktok'),
(5, NOW() - INTERVAL '7 days',  'SG', 'referral')
ON CONFLICT (user_id) DO NOTHING;

-- Seed events 
INSERT INTO events (event_id, user_id, ts, event_name, device, page) VALUES
(2, 2, NOW() - INTERVAL '9 days',  'view_product', 'android', '/product/111'),
(3, 2, NOW() - INTERVAL '9 days',  'add_to_cart',  'android', '/cart'),
(4, 2, NOW() - INTERVAL '9 days',  'purchase',     'android', '/checkout'),
(5, 3, NOW() - INTERVAL '8 days',  'view_product', 'ios',     '/product/222'),
(6, 3, NOW() - INTERVAL '8 days',  'add_to_cart',  'ios',     '/cart'),
(7, 4, NOW() - INTERVAL '7 days',  'view_product', 'ios',     '/product/333'),
(8, 5, NOW() - INTERVAL '6 days',  'view_product', 'android', '/product/444'),
(9, 5, NOW() - INTERVAL '6 days',  'purchase',     'android', '/checkout')
ON CONFLICT (event_id) DO NOTHING;

-- Seed orders
INSERT INTO orders (order_id, user_id, ts, amount) VALUES
(2, 2, NOW() - INTERVAL '9 days', 39.90),
(3, 5, NOW() - INTERVAL '6 days', 12.50)
ON CONFLICT (order_id) DO NOTHING;

COMMIT;