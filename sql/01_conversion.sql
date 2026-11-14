-- Бизнес-вопрос: какая доля заказов доходит до успешной оплаты и где теряем больше?
-- Конверсия оплаты = заказы хотя бы с одним succeeded / все заказы, перешедшие к оплате.
WITH per_order AS (
    SELECT o.order_id, o.device,
           BOOL_OR(p.status = 'succeeded') AS paid,
           COUNT(*)                        AS attempts
    FROM orders o
    JOIN payments p ON p.order_id = o.order_id
    GROUP BY o.order_id, o.device
)
SELECT COALESCE(device, 'ИТОГО')                          AS device,
       COUNT(*)                                           AS orders,
       ROUND(100.0 * AVG(paid::int), 1)                   AS payment_conversion_pct,
       ROUND(AVG(attempts), 2)                            AS avg_attempts
FROM per_order
GROUP BY ROLLUP (device)
ORDER BY device;
