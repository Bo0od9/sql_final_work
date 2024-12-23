SELECT
    DATE_TRUNC('month', o.created_at) AS month,
    SUM(o.total_price) AS monthly_revenue,
    SUM(SUM(o.total_price)) OVER () AS total_revenue,
    ROUND((SUM(o.total_price) / SUM(SUM(o.total_price)) OVER ()) * 100, 2) AS revenue_share
FROM orders o
WHERE o.status != 'Отменён'
GROUP BY DATE_TRUNC('month', o.created_at)
ORDER BY month;
