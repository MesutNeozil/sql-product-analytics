import os
import random
from datetime import datetime, timedelta
from dataclasses import dataclass
from typing import List, Tuple, Dict

import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv


# Configs

@dataclass
class Config:
    n_new_users: int = 2000
    max_days_ago_signup: int = 45
    p_return_next_day: float = 0.25     # TODO: try 0.15 vs 0.35 and see D1 retention move
    p_return_week: float = 0.12         # TODO: impacts D7
    session_gap_minutes: int = 30       # should match your SQL sessionization
    max_sessions_per_user: int = 6
    # Funnel probabilities by acquisition channel (view -> add -> purchase)
    funnel: Dict[str, Tuple[float, float, float]] = None

    def __post_init__(self):
        if self.funnel is None:
            # (p_view, p_add_given_view, p_purchase_given_add)
            # TODO: make channels meaningfully different and observe your by-channel query
            self.funnel = {
                "tiktok": (0.85, 0.28, 0.18),
                "instagram": (0.80, 0.32, 0.20),
                "google": (0.75, 0.35, 0.25),
                "referral": (0.70, 0.40, 0.30),
            }


COUNTRIES = ["SG", "MY", "ID", "PH", "TH"]
DEVICES = ["ios", "android", "web"]
CHANNELS = ["tiktok", "instagram", "google", "referral"]
PAGES = ["/home", "/search", "/product/111", "/product/222", "/product/333", "/cart", "/checkout"]


def connect():
    load_dotenv()
    conn = psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=int(os.getenv("PGPORT", "5432")),
        dbname=os.getenv("PGDATABASE", "analytics"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD"),
    )
    conn.autocommit = False
    return conn


def get_next_ids(cur) -> Tuple[int, int, int]:
    cur.execute("SELECT COALESCE(MAX(user_id), 0) FROM users;")
    max_user = cur.fetchone()[0]
    cur.execute("SELECT COALESCE(MAX(event_id), 0) FROM events;")
    max_event = cur.fetchone()[0]
    cur.execute("SELECT COALESCE(MAX(order_id), 0) FROM orders;")
    max_order = cur.fetchone()[0]
    return max_user + 1, max_event + 1, max_order + 1


def random_timestamp_between(start: datetime, end: datetime) -> datetime:
    delta = end - start
    seconds = int(delta.total_seconds())
    return start + timedelta(seconds=random.randint(0, max(seconds, 0)))


def generate_users(cfg: Config, start_user_id: int) -> List[Tuple[int, datetime, str, str]]:
    now = datetime.now()
    rows = []
    for i in range(cfg.n_new_users):
        user_id = start_user_id + i
        created_at = now - timedelta(days=random.randint(0, cfg.max_days_ago_signup),
                                     hours=random.randint(0, 23),
                                     minutes=random.randint(0, 59))
        country = random.choice(COUNTRIES)
        channel = random.choices(CHANNELS, weights=[0.35, 0.25, 0.25, 0.15], k=1)[0]
        rows.append((user_id, created_at, country, channel))
    return rows


def simulate_sessions_for_user(cfg: Config, created_at: datetime) -> List[datetime]:
    """
    Returns a list of session_start timestamps for a user.
    We create:
    - 1 initial session near signup
    - optional return sessions (next day / within week / later)
    """
    session_starts = []

    # session 1: within 0-6 hours after signup
    session_starts.append(created_at + timedelta(minutes=random.randint(5, 360)))

    # next day return
    if random.random() < cfg.p_return_next_day:
        session_starts.append(created_at + timedelta(days=1, hours=random.randint(0, 3), minutes=random.randint(0, 59)))

    # within week return
    if random.random() < cfg.p_return_week:
        session_starts.append(created_at + timedelta(days=random.randint(2, 7), hours=random.randint(0, 23), minutes=random.randint(0, 59)))

    # extra random sessions later
    extra = random.randint(0, max(0, cfg.max_sessions_per_user - len(session_starts)))
    for _ in range(extra):
        session_starts.append(created_at + timedelta(days=random.randint(2, cfg.max_days_ago_signup),
                                                     hours=random.randint(0, 23),
                                                     minutes=random.randint(0, 59)))
    session_starts.sort()
    return session_starts[: cfg.max_sessions_per_user]


def generate_events_and_orders(
    cfg: Config,
    users: List[Tuple[int, datetime, str, str]],
    start_event_id: int,
    start_order_id: int
) -> Tuple[List[Tuple], List[Tuple]]:
    """
    Generates events with per-channel funnel behavior and a rough session structure.
    Returns (events_rows, orders_rows)
    """
    now = datetime.now()

    event_rows = []
    order_rows = []

    event_id = start_event_id
    order_id = start_order_id

    for (user_id, created_at, country, channel) in users:
        device = random.choice(DEVICES)
        (p_view, p_add_given_view, p_purchase_given_add) = cfg.funnel[channel]

        session_starts = simulate_sessions_for_user(cfg, created_at)

        for s_start in session_starts:
            # keep sessions not in the future
            if s_start > now:
                continue

            # generate a handful of events within the session
            # TODO: tweak these bounds and see how session_duration changes
            n_events = random.randint(2, 8)

            # Decide whether this session participates in the funnel
            viewed = 1 if random.random() < p_view else 0
            added = 1 if (viewed and random.random() < p_add_given_view) else 0
            purchased = 1 if (added and random.random() < p_purchase_given_add) else 0

            # Build event sequence (not strictly ordered, but realistic enough)
            timeline = [s_start + timedelta(minutes=random.randint(0, 25), seconds=random.randint(0, 59))
                        for _ in range(n_events)]
            timeline.sort()

            # base browsing events
            for t in timeline:
                page = random.choice(PAGES)
                event_name = random.choice(["page_view", "search", "scroll"])
                event_rows.append((event_id, user_id, t, event_name, device, page))
                event_id += 1

            # funnel events placed within session timeline
            if viewed:
                t = s_start + timedelta(minutes=random.randint(0, 8), seconds=random.randint(0, 59))
                event_rows.append((event_id, user_id, t, "view_product", device, random.choice(["/product/111", "/product/222", "/product/333"])))
                event_id += 1

            if added:
                t = s_start + timedelta(minutes=random.randint(5, 15), seconds=random.randint(0, 59))
                event_rows.append((event_id, user_id, t, "add_to_cart", device, "/cart"))
                event_id += 1

            if purchased:
                t = s_start + timedelta(minutes=random.randint(10, 25), seconds=random.randint(0, 59))
                event_rows.append((event_id, user_id, t, "purchase", device, "/checkout"))
                event_id += 1

                # Create an order tied to purchase time
                amount = round(random.uniform(8.0, 80.0), 2)
                order_rows.append((order_id, user_id, t, amount))
                order_id += 1

    return event_rows, order_rows


def bulk_insert(conn, users_rows, events_rows, orders_rows):
    with conn.cursor() as cur:
        execute_values(
            cur,
            "INSERT INTO users (user_id, created_at, country, acquisition_channel) VALUES %s "
            "ON CONFLICT (user_id) DO NOTHING;",
            users_rows,
            page_size=5000
        )

        execute_values(
            cur,
            "INSERT INTO events (event_id, user_id, ts, event_name, device, page) VALUES %s "
            "ON CONFLICT (event_id) DO NOTHING;",
            events_rows,
            page_size=5000
        )

        execute_values(
            cur,
            "INSERT INTO orders (order_id, user_id, ts, amount) VALUES %s "
            "ON CONFLICT (order_id) DO NOTHING;",
            orders_rows,
            page_size=5000
        )

    conn.commit()


def main():
    random.seed(42)
    cfg = Config()

    conn = connect()
    try:
        with conn.cursor() as cur:
            next_user_id, next_event_id, next_order_id = get_next_ids(cur)

        users_rows = generate_users(cfg, next_user_id)
        events_rows, orders_rows = generate_events_and_orders(cfg, users_rows, next_event_id, next_order_id)

        print(f"Generated: users={len(users_rows)}, events={len(events_rows)}, orders={len(orders_rows)}")

        bulk_insert(conn, users_rows, events_rows, orders_rows)
        print("Insert complete.")

    except Exception as e:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    main()