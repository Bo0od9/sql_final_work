SELECT
    p.name,
    w.stock_quantity,
    w.next_delivery_date
FROM warehouse w
JOIN products p ON w.product_id = p.id
ORDER BY w.stock_quantity DESC
LIMIT 10;
