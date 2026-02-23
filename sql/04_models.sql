CREATE OR REPLACE VIEW v_daily_kpis AS
WITH dau as (
    SELECT DATE(ts) AS day, COUNT(DISTINCT user_id) AS dau
    FROM events
    GROUP BY 1
),
ord as (
    SELECT DATE(ts) AS day,
    COUNT(order_id) AS orders,
    SUM(amount) as revenue,
    AVG(amount) as aov
    FROM orders
    GROUP BY 1
)
SELECT 
    COALESCE(d.day, o.day) as day, 
    COALESCE(d.dau, 0) as dau, 
    COALESCE(o.orders, 0) as orders, 
    ROUND(COALESCE(o.revenue, 0)::numeric,2) as revenue,
    ROUND(COALESCE(o.aov, NULL)::numeric,2) as aov
FROM dau d
FULL OUTER JOIN ord o 
ON d.day = o.day;

CREATE OR REPLACE VIEW v_daily_funnel AS
WITH per_users_days as (
    SELECT DATE(ts) AS day,
    user_id,
    MAX((event_name = 'view_product')::int) AS viewed,
    MAX((event_name = 'add_to_cart')::int) AS added,
    MAX((event_name = 'purchase')::int) AS purchased
    FROM events
    GROUP BY (DATE(ts),user_id)
)
SELECT 
    day,
    SUM(viewed) AS users_viewed,
    SUM(added) AS users_added,
    SUM(purchased) AS users_purchased,
    ROUND(SUM(added)::numeric / NULLIF(SUM(viewed),0), 4) AS view_to_cart,
    ROUND(SUM(purchased)::numeric / NULLIF(SUM(added),0), 4) AS cart_to_purchase
FROM per_users_days
GROUP BY day
ORDER BY day;

CREATE OR REPLACE VIEW v_retention_d1 AS
WITH signup as (
    SELECT user_id, DATE(created_at) AS signup_day
    FROM users
),
activity as (
    SELECT DISTINCT user_id, DATE(ts) as active_day
    FROM events
),
joined as (
    SELECT s.user_id, s.signup_day, a.active_day
    FROM signup s
    LEFT JOIN activity a
    ON s.user_id = a.user_id
)
SELECT
    signup_day,
    COUNT(DISTINCT user_id) as cohort_size,
    COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '1 day' THEN user_id END) AS retained_d1,
    ROUND(COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '1 day' THEN user_id END)::numeric/ NULLIF(COUNT(DISTINCT user_id),0),4) AS d1_retention
FROM joined
GROUP BY 1
ORDER BY 1;

CREATE OR REPLACE VIEW v_retention_d7 AS
WITH signup as (
    SELECT user_id, DATE(created_at) AS signup_day
    FROM users
),
activity as (
    SELECT DISTINCT user_id, DATE(ts) as active_day
    FROM events
),
joined as (
    SELECT s.user_id, s.signup_day, a.active_day
    FROM signup s
    LEFT JOIN activity a
    ON s.user_id = a.user_id
)
SELECT
    signup_day,
    COUNT(DISTINCT user_id) as cohort_size,
    COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '7 day' THEN user_id END) AS retained_d7,
    ROUND(COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '7 day' THEN user_id END)::numeric/ NULLIF(COUNT(DISTINCT user_id),0),4) AS d7_retention
FROM joined
GROUP BY 1
ORDER BY 1;

CREATE OR REPLACE VIEW v_retention_summary AS
WITH signup as (
    SELECT user_id, DATE(created_at) AS signup_day
    FROM users
),
activity as (
    SELECT DISTINCT user_id, DATE(ts) as active_day
    FROM events
),
joined as (
    SELECT s.user_id, s.signup_day, a.active_day
    FROM signup s
    LEFT JOIN activity a
    ON s.user_id = a.user_id
)
SELECT
    signup_day,
    COUNT(DISTINCT user_id) as cohort_size,
    COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '1 day' THEN user_id END) AS retained_d1,
    ROUND(COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '1 day' THEN user_id END)::numeric/ NULLIF(COUNT(DISTINCT user_id),0),4) AS d1_retention,
    COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '7 day' THEN user_id END) AS retained_d7,
    ROUND(COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '7 day' THEN user_id END)::numeric/ NULLIF(COUNT(DISTINCT user_id),0),4) AS d7_retention,
    COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '30 day' THEN user_id END) AS retained_d30,
    ROUND(COUNT(DISTINCT CASE WHEN active_day = signup_day + INTERVAL '30 day' THEN user_id END)::numeric/ NULLIF(COUNT(DISTINCT user_id),0),4) AS d30_retention
FROM joined
GROUP BY 1
ORDER BY 1;

CREATE OR REPLACE VIEW v_sessions AS
WITH flagged AS (
    SELECT
        user_id,
        ts,
        event_name,
    CASE
        WHEN LAG(ts) OVER (PARTITION BY user_id ORDER BY ts) IS NULL THEN 1
        WHEN ts - LAG(ts) OVER (PARTITION BY user_id ORDER BY ts) > INTERVAL '30 minutes' THEN 1
        ELSE 0
    END AS is_new_session
  FROM events
),
numbered AS (
    SELECT
        user_id,
        ts,
        SUM(is_new_session) OVER (PARTITION BY user_id ORDER BY ts) AS session_id
    FROM flagged
)
SELECT
    user_id,
    session_id,
    MIN(ts) as session_start,
    MAX(ts) as session_end,
    COUNT(*) as events_in_session,
    EXTRACT(EPOCH FROM (MAX(ts) - MIN(ts))) as session_duration_seconds
FROM numbered
GROUP BY user_id, session_id
ORDER BY user_id, session_id;





--tests

SELECT * FROM v_daily_kpis ORDER BY day;
SELECT MIN(ts), MAX(ts) FROM events;
SELECT MIN(ts), MAX(ts) FROM orders;

SELECT * FROM v_daily_funnel ORDER BY day;

SELECT * FROM v_retention_d1 ORDER BY signup_day;

-- should return 0 rows
SELECT * FROM v_retention_d1 WHERE signup_day IS NULL;

-- should return 0 rows
SELECT * FROM v_retention_d1 WHERE retained_d1 > cohort_size;

SELECT * FROM v_retention_d7 ORDER BY signup_day;

SELECT * FROM v_sessions ORDER BY user_id, session_id;
SELECT
  user_id,
  COUNT(*) AS sessions,
  ROUND(AVG(session_duration_seconds)) AS avg_session_seconds
FROM v_sessions
GROUP BY 1
ORDER BY sessions DESC;