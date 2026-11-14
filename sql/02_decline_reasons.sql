-- Бизнес-вопрос: почему платежи не проходят и что делает покупатель после отказа?
WITH canceled AS (
    SELECT p.*,
           EXISTS (SELECT 1 FROM payments n
                   WHERE n.order_id = p.order_id AND n.created_at > p.created_at) AS retried
    FROM payments p
    WHERE p.status = 'canceled'
)
SELECT cancel_reason,
       COUNT(*)                                             AS attempts,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS share_pct,
       ROUND(100.0 * AVG((NOT retried)::int), 1)            AS left_after_decline_pct
FROM canceled
GROUP BY cancel_reason
ORDER BY attempts DESC;
