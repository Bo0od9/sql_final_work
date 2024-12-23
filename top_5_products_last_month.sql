SELECT
    p.name,
    SUM(oi.quantity) as total_quantity,
    COUNT(DISTINCT o.id) as order_count,
    SUM(oi.quantity * oi.price) as total_revenue
FROM products p
JOIN order_items oi ON p.id = oi.product_id
JOIN orders o ON oi.order_id = o.id
WHERE o.status != 'Отменён'
    AND o.created_at >= NOW() - INTERVAL '1 month'
GROUP BY p.id, p.name
ORDER BY total_quantity DESC
LIMIT 5;