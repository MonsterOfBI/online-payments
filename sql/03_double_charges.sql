-- Бизнес-вопрос: сколько заказов оплачено дважды (покупатель нажал «Оплатить» повторно)?
-- В AS-IS магазин не передаёт ключ идемпотентности, поэтому повторный запрос создаёт новый платёж.
WITH doubles AS (
    SELECT o.order_id,
           COUNT(*)                                 AS succeeded_payments,
           SUM(p.amount) - MIN(o.amount)            AS overcharged_rub,
           MAX(p.created_at) - MIN(p.created_at)    AS gap_between_attempts
    FROM orders o
    JOIN payments p ON p.order_id = o.order_id AND p.status = 'succeeded'
    GROUP BY o.order_id
    HAVING COUNT(*) > 1
)
SELECT COUNT(*)                                                   AS orders_charged_twice,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders WHERE status <> 'canceled'), 2) AS share_of_paid_pct,
       SUM(overcharged_rub)                                       AS overcharged_total_rub,
       MAX(gap_between_attempts)                                  AS max_gap
FROM doubles;

-- Детализация: 10 самых крупных случаев
WITH doubles AS (
    SELECT o.order_id, SUM(p.amount) - MIN(o.amount) AS overcharged_rub
    FROM orders o
    JOIN payments p ON p.order_id = o.order_id AND p.status = 'succeeded'
    GROUP BY o.order_id
    HAVING COUNT(*) > 1
)
SELECT * FROM doubles ORDER BY overcharged_rub DESC LIMIT 10;
