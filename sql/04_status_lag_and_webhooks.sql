-- Бизнес-вопрос: сколько покупатель ждёт, пока заказ станет «оплачен», и что с уведомлениями?
-- AS-IS: магазин игнорирует webhooks и опрашивает статусы раз в 30 минут (в :00 и :30).
WITH lag AS (
    SELECT p.payment_id,
           EXTRACT(EPOCH FROM (
               DATE_TRUNC('hour', p.finished_at)
               + INTERVAL '30 min' * (FLOOR(EXTRACT(MINUTE FROM p.finished_at) / 30) + 1)
               - p.finished_at)) / 60 AS minutes_to_status
    FROM payments p
    WHERE p.status = 'succeeded'
)
SELECT ROUND(AVG(minutes_to_status)::numeric, 1)                                                     AS avg_min_asis,
       ROUND((PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY minutes_to_status))::numeric, 1)          AS p95_min_asis
FROM lag;

-- Сколько уведомлений приходит повторно (обработчик обязан быть идемпотентным)?
SELECT event,
       COUNT(*)                                    AS events,
       COUNT(DISTINCT payment_id)                  AS payments,
       COUNT(*) - COUNT(DISTINCT payment_id)       AS duplicate_deliveries
FROM webhook_events
GROUP BY event
ORDER BY event;
