-- A) Daily Active Users (DAU)
SELECT DATE(ts) AS day, COUNT(DISTINCT user_id) AS dau
FROM events
GROUP BY 1
ORDER BY 1;

-- B) Funnel conversion (view -> add_to_cart -> purchase) at user level
WITH per_user AS (
  SELECT
    user_id,
    MAX((event_name = 'view_product')::int) AS viewed,
    MAX((event_name = 'add_to_cart')::int)  AS added,
    MAX((event_name = 'purchase')::int)     AS purchased
  FROM events
  GROUP BY 1
)
SELECT
  SUM(viewed) AS users_viewed,
  SUM(added) AS users_added,
  SUM(purchased) AS users_purchased,
  ROUND(SUM(added)::numeric / NULLIF(SUM(viewed),0), 4) AS view_to_cart,
  ROUND(SUM(purchased)::numeric / NULLIF(SUM(added),0), 4) AS cart_to_purchase
FROM per_user;

-- C) Revenue by acquisition channel
SELECT
  u.acquisition_channel,
  COUNT(DISTINCT o.order_id) AS orders,
  ROUND(SUM(o.amount), 2) AS revenue,
  ROUND(AVG(o.amount), 2) AS aov
FROM orders o
JOIN users u ON u.user_id = o.user_id
GROUP BY 1
ORDER BY revenue DESC NULLS LAST;
