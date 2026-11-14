"""Синтетические данные AS-IS для кейса «Оплата в интернет-магазине» (сентябрь–октябрь 2026).
Запуск: python data/generate_data.py → data/seed.sql. seed фиксирован, данные воспроизводимы.
Причины отказа взяты из модели ЮKassa (cancellation_details.reason)."""
import random, uuid
from datetime import datetime, timedelta
from pathlib import Path

random.seed(7)
R = random.Random(7)
OUT = Path(__file__).parent
REASONS = [("3d_secure_failed", 30), ("insufficient_funds", 22), ("expired_on_confirmation", 20),
           ("general_decline", 12), ("card_expired", 6), ("fraud_suspected", 4), ("canceled_by_merchant", 6)]

def pick_reason():
    return R.choices([r for r, _ in REASONS], [w for _, w in REASONS])[0]

def pid():
    return str(uuid.UUID(int=R.getrandbits(128)))

def q(v):
    if v is None: return "NULL"
    if isinstance(v, bool): return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)): return str(v)
    return "'" + str(v).replace("'", "''") + "'"

orders, payments, refunds, hooks = [], [], [], []
start = datetime(2026, 9, 1)
for oid in range(1, 4001):
    created = start + timedelta(minutes=R.randrange(0, 61 * 24 * 60))
    device = R.choices(["mobile", "desktop"], [65, 35])[0]
    amount = round(R.lognormvariate(8.0, 0.7), -1)
    status = "awaiting_payment"
    t = created + timedelta(minutes=R.randint(1, 5))
    paid = False
    for attempt in range(3):
        method = R.choices(["bank_card", "yoo_money"], [93, 7])[0]
        # на мобильных 3-DS чаще срывается: покупатель уходит в приложение банка и не возвращается
        p_ok = 0.80 if device == "desktop" else 0.70
        ok = R.random() < p_ok
        p = pid()
        fin = t + timedelta(seconds=R.randint(20, 600))
        payments.append([p, oid, None, method, amount, "succeeded" if ok else "canceled",
                         None if ok else pick_reason(), t, fin])
        if ok:
            paid = True
            hooks.append([p, "payment.succeeded", fin + timedelta(seconds=R.randint(1, 30)), False])
            if R.random() < 0.08:   # повторная доставка того же уведомления
                hooks.append([p, "payment.succeeded", fin + timedelta(minutes=R.randint(1, 20)), False])
            # двойное списание: покупатель нажал «Оплатить» дважды, ключа идемпотентности нет
            if R.random() < 0.006:
                p2 = pid()
                payments.append([p2, oid, None, method, amount, "succeeded", None, t + timedelta(seconds=3), fin + timedelta(seconds=5)])
                hooks.append([p2, "payment.succeeded", fin + timedelta(seconds=9), False])
            break
        else:
            hooks.append([p, "payment.canceled", fin + timedelta(seconds=R.randint(1, 30)), False])
        if R.random() < 0.55:  # больше половины после отказа уходят
            break
        t = fin + timedelta(minutes=R.randint(1, 10))
    if paid:
        status = "paid"
        if R.random() < 0.05:
            sp = [x for x in payments if x[1] == oid and x[5] == "succeeded"][0]
            req = sp[8] + timedelta(days=R.randint(1, 10), hours=R.randint(0, 12))
            created_r = req + timedelta(hours=R.choice([2, 5, 20, 26, 48, 70, 96]))  # оператор вручную в личном кабинете
            succ = created_r + timedelta(minutes=R.randint(1, 60))
            ramt = amount if R.random() < 0.8 else round(amount * 0.4, 2)
            refunds.append([pid(), sp[0], ramt, req, created_r, succ, "succeeded"])
            status = "refunded" if ramt == amount else "partially_refunded"
    else:
        status = "canceled"
    orders.append([oid, created, amount, device, status])

sql = ["-- Синтетические данные (data/generate_data.py, seed=7)", "BEGIN;"]
sql += ["INSERT INTO orders VALUES (" + ", ".join(q(v) for v in o) + ");" for o in orders]
sql += ["INSERT INTO payments VALUES (" + ", ".join(q(v) for v in p) + ");" for p in payments]
sql += ["INSERT INTO refunds VALUES (" + ", ".join(q(v) for v in r) + ");" for r in refunds]
sql += ["INSERT INTO webhook_events (payment_id, event, received_at, processed) VALUES (" + ", ".join(q(v) for v in h) + ");" for h in hooks]
sql += ["COMMIT;"]
(OUT / "seed.sql").write_text("\n".join(sql), encoding="utf-8")
print(f"orders={len(orders)} payments={len(payments)} refunds={len(refunds)} webhooks={len(hooks)}")
