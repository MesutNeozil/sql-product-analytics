-- 1) Users with null created_at (should be none)
SELECT * FROM users WHERE created_at IS NULL;

-- 2) Events referencing missing users (FK should prevent, but check anyway)
SELECT e.*
FROM events e
LEFT JOIN users u ON u.user_id = e.user_id
WHERE u.user_id IS NULL;

-- 3) Orders with negative amount (should be none)
SELECT * FROM orders WHERE amount < 0;

-- 4) Duplicate events by (user_id, ts, event_name) heuristic
SELECT user_id, ts, event_name, COUNT(*) AS cnt
FROM events
GROUP BY 1,2,3
HAVING COUNT(*) > 1;

-- 5) Timestamps in the future 
SELECT * FROM events WHERE ts > NOW() + INTERVAL '5 minutes';
SELECT * FROM orders WHERE ts > NOW() + INTERVAL '5 minutes';
