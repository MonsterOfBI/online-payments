# 3. Интеграция с платёжным сервисом

## 3.1. Последовательность: оплата картой или СБП
```mermaid
sequenceDiagram
    autonumber
    actor U as Покупатель
    participant F as Сайт (фронт)
    participant B as Бэкенд магазина
    participant K as ЮKassa
    participant Bank as Банк покупателя
    U->>F: Оплатить заказ
    F->>B: POST /orders/{id}/payments {method}
    B->>K: POST /v3/payments (Idempotence-Key = order-attempt)
    alt таймаут 10 с
        B->>K: тот же запрос, тот же ключ (до 3 раз)
    end
    K-->>B: 200 {id, status: pending, confirmation_url}
    B-->>F: 201 {payment_id, confirmation_url}
    F->>U: Редирект на форму / QR СБП
    U->>Bank: Подтвердить (3-DS или приложение банка)
    Bank-->>K: Результат авторизации
    K->>B: webhook payment.succeeded | payment.canceled
    B->>K: GET /v3/payments/{id} (перепроверка)
    K-->>B: 200 {status}
    alt succeeded
        B->>B: заказ paid (если уже paid — ничего)
    else canceled
        B->>B: причина → текст для покупателя
    end
    B-->>K: 200 OK (за ≤ 3 с)
    opt webhook не пришёл за 10 мин
        B->>K: GET /v3/payments/{id}
    end
```
Исходник PlantUML: `uml/payment-sequence.puml`.

## 3.2. Статусы платежа (модель платёжного сервиса)
```mermaid
stateDiagram-v2
    [*] --> pending: платёж создан
    pending --> waiting_for_capture: двухстадийная оплата, деньги заморожены
    pending --> succeeded: одностадийная, оплачено
    pending --> canceled: отказ банка, не подтвердил, истекло время
    waiting_for_capture --> succeeded: магазин подтвердил (capture)
    waiting_for_capture --> canceled: магазин отменил или истёк срок
    succeeded --> [*]
    canceled --> [*]
```
Магазин использует **одностадийную** оплату (`capture: true`): товары в наличии, резервировать деньги не нужно. Двухстадийная пригодилась бы для товаров под заказ — отмечено как открытый вопрос.

## 3.3. Статусы заказа в магазине
```mermaid
stateDiagram-v2
    [*] --> awaiting_payment
    awaiting_payment --> paid: payment.succeeded + GET подтвердил
    awaiting_payment --> canceled: 3 неудачные попытки или 24 ч без оплаты
    paid --> partially_refunded: частичный возврат
    paid --> refunded: полный возврат
    partially_refunded --> refunded: вернули остаток
```

## 3.4. Ключи идемпотентности
| Операция | Ключ | Почему так |
|---|---|---|
| Создание платежа | `{order_id}-{attempt_no}` | повтор той же попытки → тот же платёж; новая попытка только после `canceled` |
| Создание возврата | `refund-{refund_request_id}` | оператор нажал кнопку дважды → один возврат |
| Обработка webhook | `payment_id + event` | повторная доставка не меняет заказ |

> Деталь, которую спрашивают: у ЮKassa заголовок называется `Idempotence-Key`, во многих других API — `Idempotency-Key`. В нашем API магазина используется `Idempotency-Key` (`api/openapi.yaml`).

## 3.5. Что можно проверить руками
`api/yookassa-test.postman_collection.json` — коллекция для тестового магазина ЮKassa (создать платёж, получить статус, вернуть). Нужны `shopId` и секретный ключ тестового магазина (регистрация бесплатна, договор не нужен).
**Статус проверки:** коллекция собрана по документации, живым запросом из этого окружения не проверялась.
