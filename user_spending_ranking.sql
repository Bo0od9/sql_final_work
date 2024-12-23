SELECT
    u.username,
    COUNT(DISTINCT o.id) as orders_count,
    SUM(o.total_price) as total_spent,
    RANK() OVER (ORDER BY SUM(o.total_price) DESC) as spending_rank
FROM users u
LEFT JOIN orders o ON u.id = o.user_id AND o.status != 'Отменён'
GROUP BY u.id, u.username
HAVING COUNT(DISTINCT o.id) > 0
ORDER BY total_spent DESC;