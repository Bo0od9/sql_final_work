SELECT
    u.username,
    COUNT(DISTINCT o.id) as order_count,
    COALESCE(SUM(o.total_price), 0) as total_spent
FROM users u
LEFT JOIN orders o ON u.id = o.user_id AND o.status != 'Отменён'
GROUP BY u.id, u.username
ORDER BY total_spent DESC;