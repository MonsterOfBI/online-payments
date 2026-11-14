-- Бизнес-вопрос: сколько покупатель ждёт возврата и на каком этапе теряется время?
-- Этап 1: запрос → оператор создал возврат вручную в личном кабинете. Этап 2: создание → деньги ушли.
SELECT COUNT(*)                                                                             AS refunds,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP
             (ORDER BY EXTRACT(EPOCH FROM r.created_at - r.requested_at) / 3600))::numeric, 1)  AS median_h_waiting_operator,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP
             (ORDER BY EXTRACT(EPOCH FROM r.succeeded_at - r.created_at) / 3600))::numeric, 2)  AS median_h_provider,
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP
             (ORDER BY EXTRACT(EPOCH FROM r.succeeded_at - r.requested_at) / 3600))::numeric, 1) AS p90_h_total,
       COUNT(*) FILTER (WHERE r.amount < p.amount)                                          AS partial_refunds
FROM refunds r
JOIN payments p ON p.payment_id = r.payment_id
WHERE r.status = 'succeeded';
