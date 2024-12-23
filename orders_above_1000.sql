SELECT
    o.id AS order_id,
    u.username,
    o.total_price,
    o.created_at
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.total_price > 1000
ORDER BY o.total_price DESC;
