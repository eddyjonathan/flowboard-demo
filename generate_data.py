import psycopg2
import pandas as pd
import random
from faker import Faker
from datetime import datetime, timedelta
import uuid

fake = Faker()
random.seed(42)  # makes results reproducible

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
DB_CONFIG = {
    "host": "localhost",
    "database": "flowboard",
    "user": "postgres",
    "password": "admin",  # the password you set during PostgreSQL installation
    "port": 5433                          # your port
}

NUM_CLIENTS = 40
NUM_TRANSACTIONS = 8000  # ~18 months of data

CURRENCIES = ["EUR", "GBP", "CHF", "PLN", "USD"]
RECEIVE_CURRENCY = "HUF"  # FlowPay converts everything to HUF for Hungarian clients

# Realistic FX rates (send currency → HUF)
FX_BASE_RATES = {
    "EUR": 390.0,
    "GBP": 455.0,
    "CHF": 435.0,
    "PLN": 95.0,
    "USD": 362.0
}

# FlowPay charges a small markup above market rate
FX_MARKUP_RANGE = (0.005, 0.025)  # 0.5% to 2.5% above market

SEGMENTS = ["SME", "SME", "SME", "MID", "MID", "ENTERPRISE"]  # weighted toward SME
COUNTRIES = ["Hungary", "Germany", "Austria", "Poland", "Czech Republic",
             "Slovakia", "Romania", "Netherlands"]

START_DATE = datetime(2023, 1, 1)
END_DATE   = datetime(2024, 6, 30)

# ─────────────────────────────────────────
# GENERATE CLIENTS
# ─────────────────────────────────────────
def generate_clients():
    clients = []
    for i in range(NUM_CLIENTS):
        client_id = f"CLT{str(i+1).zfill(4)}"
        clients.append({
            "client_id":      client_id,
            "company_name":   fake.company(),
            "country":        random.choice(COUNTRIES),
            "segment":        random.choice(SEGMENTS),
            "onboarded_date": fake.date_between(
                                  start_date=START_DATE,
                                  end_date=START_DATE + timedelta(days=180)
                              )
        })
    return pd.DataFrame(clients)

# ─────────────────────────────────────────
# GENERATE TRANSACTIONS
# ─────────────────────────────────────────
def generate_transactions(client_ids):
    transactions = []

    # Enterprise clients get more transactions
    def get_client():
        return random.choice(client_ids)

    for i in range(NUM_TRANSACTIONS):
        txn_id       = f"TXN{str(i+1).zfill(8)}"
        client_id    = get_client()
        send_ccy = random.choices(
        CURRENCIES,
        weights=[40, 25, 15, 12, 8]  # EUR dominant, PLN rare
        )[0]
        market_rate  = FX_BASE_RATES[send_ccy]

        # Add some noise to market rate (rates fluctuate daily)
        market_rate  = market_rate * random.uniform(0.97, 1.03)

        # FlowPay applies a markup on top of market rate
        markup       = random.uniform(*FX_MARKUP_RANGE)
        applied_rate = round(market_rate * (1 + markup), 6)

        # Transaction amount varies by segment
        # EUR transactions tend to be larger corporate payments
        # PLN transactions tend to be smaller
        amount_ranges = {
            "EUR": (5000, 50000),
            "GBP": (3000, 40000),
            "CHF": (2000, 35000),
            "USD": (1000, 25000),
            "PLN": (500, 8000)
        }
        low, high = amount_ranges[send_ccy]
        send_amount = round(random.uniform(low, high), 2)



        receive_amount = round(send_amount * applied_rate, 2)

        # Processing fee between 0.1% and 0.5%
        fee_pct      = round(random.uniform(0.001, 0.005), 4)

        # Most transactions complete, some fail or refund
        status       = random.choices(
            ["completed", "failed", "refunded"],
            weights=[92, 5, 3]
        )[0]

        # Random timestamp within date range
        delta_days   = (END_DATE - START_DATE).days
        txn_date     = START_DATE + timedelta(
            days=random.randint(0, delta_days),
            hours=random.randint(8, 18),
            minutes=random.randint(0, 59)
        )

        transactions.append({
            "transaction_id":     txn_id,
            "client_id":          client_id,
            "transaction_date":   txn_date,
            "send_currency":      send_ccy,
            "receive_currency":   RECEIVE_CURRENCY,
            "send_amount":        send_amount,
            "receive_amount":     receive_amount,
            "fx_rate_applied":    applied_rate,
            "processing_fee_pct": fee_pct,
            "status":             status
        })

    return pd.DataFrame(transactions)

# ─────────────────────────────────────────
# LOAD INTO POSTGRESQL
# ─────────────────────────────────────────
def load_to_postgres(clients_df, transactions_df):
    conn = psycopg2.connect(**DB_CONFIG)
    cur  = conn.cursor()

    print("Loading clients...")
    for _, row in clients_df.iterrows():
        cur.execute("""
            INSERT INTO clients 
                (client_id, company_name, country, segment, onboarded_date)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (client_id) DO NOTHING
        """, (
            row["client_id"], row["company_name"], row["country"],
            row["segment"],   row["onboarded_date"]
        ))

    print("Loading transactions...")
    for _, row in transactions_df.iterrows():
        cur.execute("""
            INSERT INTO transactions
                (transaction_id, client_id, transaction_date, send_currency,
                 receive_currency, send_amount, receive_amount,
                 fx_rate_applied, processing_fee_pct, status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (transaction_id) DO NOTHING
        """, (
            row["transaction_id"], row["client_id"],
            row["transaction_date"], row["send_currency"],
            row["receive_currency"], row["send_amount"],
            row["receive_amount"],   row["fx_rate_applied"],
            row["processing_fee_pct"], row["status"]
        ))

    conn.commit()
    cur.close()
    conn.close()
    print(f"Done. {len(clients_df)} clients and {len(transactions_df)} transactions loaded.")

# ─────────────────────────────────────────
# RUN
# ─────────────────────────────────────────
if __name__ == "__main__":
    clients_df      = generate_clients()
    transactions_df = generate_transactions(clients_df["client_id"].tolist())

    load_to_postgres(clients_df, transactions_df)

    # Preview
    print("\nSample clients:")
    print(clients_df.head(3).to_string())
    print("\nSample transactions:")
    print(transactions_df.head(3).to_string())