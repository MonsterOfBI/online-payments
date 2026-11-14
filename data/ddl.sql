-- Платежи интернет-магазина «Ромашка-Маркет» (учебный проект, PostgreSQL 14+).
-- Статусы платежа и возврата повторяют модель ЮKassa: pending → waiting_for_capture → succeeded | canceled.
DROP TABLE IF EXISTS webhook_events, refunds, payments, orders CASCADE;

CREATE TABLE orders (
    order_id     SERIAL PRIMARY KEY,
    created_at   TIMESTAMP NOT NULL,
    amount       NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    device       TEXT NOT NULL CHECK (device IN ('mobile','desktop')),
    status       TEXT NOT NULL CHECK (status IN ('awaiting_payment','paid','canceled','refunded','partially_refunded'))
);

-- Одна попытка оплаты = одна строка. У заказа может быть несколько попыток.
CREATE TABLE payments (
    payment_id       TEXT PRIMARY KEY,                 -- id платежа в платёжном сервисе
    order_id         INT  NOT NULL REFERENCES orders,
    idempotency_key  TEXT,                             -- в AS-IS не передавался (NULL)
    method           TEXT NOT NULL CHECK (method IN ('bank_card','sbp','yoo_money')),
    amount           NUMERIC(12,2) NOT NULL,
    status           TEXT NOT NULL CHECK (status IN ('pending','waiting_for_capture','succeeded','canceled')),
    cancel_reason    TEXT,                             -- cancellation_details.reason при canceled
    created_at       TIMESTAMP NOT NULL,
    finished_at      TIMESTAMP                         -- когда стал succeeded/canceled в платёжном сервисе
);

CREATE TABLE refunds (
    refund_id     TEXT PRIMARY KEY,
    payment_id    TEXT NOT NULL REFERENCES payments,
    amount        NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    requested_at  TIMESTAMP NOT NULL,                  -- покупатель запросил возврат
    created_at    TIMESTAMP,                           -- оператор создал возврат в сервисе
    succeeded_at  TIMESTAMP,
    status        TEXT NOT NULL CHECK (status IN ('requested','pending','succeeded','canceled'))
);

-- Входящие уведомления (webhooks). Один и тот же event может прийти несколько раз.
CREATE TABLE webhook_events (
    event_id     SERIAL PRIMARY KEY,
    payment_id   TEXT NOT NULL REFERENCES payments,
    event        TEXT NOT NULL,                        -- payment.succeeded, payment.canceled, refund.succeeded
    received_at  TIMESTAMP NOT NULL,
    processed    BOOLEAN NOT NULL                      -- AS-IS: магазин не обрабатывал webhooks, только опрос раз в 30 мин
);
CREATE INDEX ix_payments_order ON payments (order_id);
