"""
Generates fake data for the Brewly cohort retention project.
Clean data = ground truth. Dirty data = clean data + realistic mess.
Re-run anytime: python scripts/generate_data.py  (seeded, so output is identical)
"""
import random, csv, datetime as dt, calendar, os
random.seed(42)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
FIRST = ["ava","liam","noah","emma","olivia","mia","lucas","ethan","zoe","leo","nora","owen","ivy","jack","ella",
         "aria","maya","finn","ruby","theo","isla","eli","luna","kai","sara","omar","priya","chen","diego","fatima",
         "hana","yusuf","nina","marco","lena","raj","sofia","jonas","amara","felix"]
LAST = ["smith","brown","lee","patel","garcia","nguyen","martin","kim","wilson","clark","lopez","young","walker",
        "hall","allen","wright","khan","singh","muller","rossi","costa","silva","murphy","kelly","cohen","moreau"]
DOMAINS = ["gmail.com","yahoo.com","outlook.com","icloud.com","hotmail.com","proton.me"]

def pick(weights):
    r, acc = random.random(), 0
    for k, w in weights.items():
        acc += w
        if r < acc: return k
    return k

COUNTRY = {"US":.45,"CA":.15,"UK":.15,"DE":.12,"AU":.13}
CHANNEL = {"organic":.30,"paid_social":.25,"paid_search":.20,"referral":.15,"email":.10}
DEVICE  = {"ios":.45,"android":.30,"web":.25}
CH_MULT = {"referral":1.12,"organic":1.05,"email":1.0,"paid_search":0.95,"paid_social":0.82}
PRICES  = [19.99,24.99,29.99,34.99,44.99]

def month_add(d, k):
    y, m = d.year + (d.month - 1 + k) // 12, (d.month - 1 + k) % 12 + 1
    return dt.date(y, m, 1)

def rand_day(start, end):
    return start + dt.timedelta(days=random.randint(0, (end - start).days))

# ---------- users ----------
users, uid = [], 10001
for m in range(1, 13):
    n = int(150 + m * 9 + random.randint(-15, 15))     # growing signups
    last = calendar.monthrange(2025, m)[1]
    for _ in range(n):
        fn, ln = random.choice(FIRST), random.choice(LAST)
        users.append(dict(user_id=uid,
            email=f"{fn}.{ln}{random.randint(1,999)}@{random.choice(DOMAINS)}",
            signup_date=dt.date(2025, m, random.randint(1, last)),
            country=pick(COUNTRY), acquisition_channel=pick(CHANNEL), signup_device=pick(DEVICE)))
        uid += 1

# ---------- orders (survival model) ----------
END = dt.date(2025, 12, 31)
raw_orders = []
def add_orders(u, start, end, n):
    for _ in range(n):
        amt = random.choice(PRICES) + random.choice([0,0,0,5.99,9.99])
        r = random.random()
        status = "completed" if r < .94 else ("refunded" if r < .975 else "cancelled")
        raw_orders.append(dict(user_id=u["user_id"], order_date=rand_day(start, end),
                               amount=round(amt, 2), status=status))

for u in users:
    sd, mult = u["signup_date"], CH_MULT[u["acquisition_channel"]]
    onboarding_v2 = sd >= dt.date(2025, 6, 1)           # the hidden "story"
    m0_end = dt.date(sd.year, sd.month, calendar.monthrange(sd.year, sd.month)[1])
    if random.random() < (0.78 if u["acquisition_channel"] == "paid_social" else 0.87):
        add_orders(u, sd, m0_end, random.choice([1,1,1,2]))
    alive, k = True, 1
    while True:
        ms = month_add(sd, k)
        if ms > END: break
        me = dt.date(ms.year, ms.month, calendar.monthrange(ms.year, ms.month)[1])
        if alive:
            s = (0.55 + (0.12 if onboarding_v2 else 0)) if k == 1 else 0.86
            alive = random.random() < min(0.97, s * mult)
        if alive and random.random() < 0.88:
            add_orders(u, ms, me, random.choice([1]*14 + [2]*5 + [3]))
        elif not alive and random.random() < 0.02:          # occasional win-back
            add_orders(u, ms, me, 1)
        k += 1

raw_orders.sort(key=lambda o: (o["order_date"], o["user_id"]))
for i, o in enumerate(raw_orders): o["order_id"] = 500001 + i

# ---------- write clean ----------
def write(path, rows, cols):
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader()
        for r in rows: w.writerow({c: r.get(c, "") for c in cols})

UCOLS = ["user_id","email","signup_date","country","acquisition_channel","signup_device"]
OCOLS = ["order_id","user_id","order_date","amount","status"]
write(f"{OUT}/clean/users.csv", users, UCOLS)
write(f"{OUT}/clean/orders.csv", [dict(o, amount=f"{o['amount']:.2f}") for o in raw_orders], OCOLS)

# ---------- dirty ----------
COUNTRY_V = {"US":["US","usa","United States"," us","U.S."],"CA":["CA","Canada","canada "],
             "UK":["UK","GB","United Kingdom","uk"],"DE":["DE","Germany","germany"],"AU":["AU","Australia"," AU "]}
CHANNEL_V = {"organic":["organic","Organic","ORGANIC "],"paid_social":["paid_social","Paid Social","paid-social","PAID_SOCIAL"],
             "paid_search":["paid_search","Paid Search","paid-search"],"referral":["referral","Referral"," referral"],
             "email":["email","Email","E-mail"]}
STATUS_V = {"completed":["completed","Completed","COMPLETE","complete "," completed"],
            "refunded":["refunded","Refunded","REFUNDED"],"cancelled":["cancelled","canceled","Cancelled"]}

def fmt_date(d, user=False):
    r = random.random()
    if r < .60: return d.isoformat()
    if r < .85: return d.strftime("%m/%d/%Y")
    if user:     return d.strftime("%b %d, %Y")
    return f"{d.isoformat()}{random.choice(['T',' '])}{random.randint(0,23):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"

def mess_user(u):
    em = u["email"]
    if random.random() < .15: em = em.upper()
    if random.random() < .08: em = " " + em + " "
    dev = u["signup_device"]
    if random.random() < .2: dev = dev.upper()
    return dict(u, email=em, signup_date=fmt_date(u["signup_date"], True),
                country=random.choice(COUNTRY_V[u["country"]]),
                acquisition_channel=random.choice(CHANNEL_V[u["acquisition_channel"]]),
                signup_device=dev)

d_users = [mess_user(u) for u in users]
d_users += [mess_user(u) for u in random.sample(users, int(len(users)*.03))]   # re-imported duplicates

test_users = []                                         # internal / QA accounts (not in clean)
for i in range(28):
    tu = dict(user_id=uid, email=random.choice([f"test{i}@gmail.com", f"qa.team{i}@brewly.com", f"TEST_user{i}@outlook.com"]),
              signup_date=dt.date(2025, random.randint(1,12), random.randint(1,28)),
              country="US", acquisition_channel="organic", signup_device="web")
    test_users.append(tu); uid += 1
d_users += [mess_user(u) for u in test_users]
random.shuffle(d_users)

def mess_order(o):
    a = f"{float(o['amount']):.2f}"
    r = random.random()
    if r < .30: a = "$" + a
    elif r < .38: a = a + " USD"
    return dict(o, order_date=fmt_date(o["order_date"]), amount=a, status=random.choice(STATUS_V[o["status"]]))

d_orders = [mess_order(o) for o in raw_orders]
d_orders += [mess_order(o) for o in random.sample(raw_orders, int(len(raw_orders)*.02))]   # duplicate loads
nid = 900001
def extra(user_id, d):
    global nid
    o = dict(order_id=nid, user_id=user_id, order_date=d, amount=random.choice(PRICES), status="completed"); nid += 1
    return mess_order(o)
for tu in test_users:
    for _ in range(random.randint(2, 8)): d_orders.append(extra(tu["user_id"], rand_day(tu["signup_date"], END)))
for _ in range(45): d_orders.append(dict(extra(0, rand_day(dt.date(2025,1,1), END)), user_id=""))           # null user
for _ in range(40): d_orders.append(extra(random.randint(90001, 90999), rand_day(dt.date(2025,1,1), END)))  # orphans
late_signups = [u for u in users if u["signup_date"] > dt.date(2025,2,1)]
for _ in range(35):                                                                                          # before signup
    u = random.choice(late_signups)
    d_orders.append(extra(u["user_id"], u["signup_date"] - dt.timedelta(days=random.randint(3, 40))))
for _ in range(20):                                                                                          # future-dated
    d_orders.append(extra(random.choice(users)["user_id"], rand_day(dt.date(2026,2,1), dt.date(2026,9,30))))
random.shuffle(d_orders)

write(f"{OUT}/dirty/users_raw.csv", d_users, UCOLS)
write(f"{OUT}/dirty/orders_raw.csv", d_orders, OCOLS)
print(f"clean users {len(users)}, clean orders {len(raw_orders)}")
print(f"dirty users {len(d_users)}, dirty orders {len(d_orders)}")
