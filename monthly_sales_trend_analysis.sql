WITH monthly_sales AS (
    SELECT
        DATE_TRUNC('month', o.created_at) as month,
        SUM(o.total_price) as revenue
    FROM orders o
    WHERE o.status != 'Отменён'
    GROUP BY DATE_TRUNC('month', o.created_at)
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) as prev_month_revenue,
    ROUND(
        ((revenue - LAG(revenue) OVER (ORDER BY month)) /
        LAG(revenue) OVER (ORDER BY month) * 100)::numeric,
        2
    ) as growth_percentage
FROM monthly_sales
ORDER BY month DESC;