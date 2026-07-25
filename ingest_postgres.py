import psycopg2
import pandas as pd
import os

DB_CONFIG = {
    "host": "localhost",
    "database": "flowboard",
    "user": "postgres",
    "password": "admin",  # the password you set during PostgreSQL installation
    "port": 5433                          # your port
}

os.makedirs("data/bronze", exist_ok=True)

def ingest_transactions():
    conn = psycopg2.connect(**DB_CONFIG)

    df = pd.read_sql("""
        SELECT
            transaction_id,
            client_id,
            transaction_date,
            send_currency,
            receive_currency,
            send_amount,
            receive_amount,
            fx_rate_applied,
            processing_fee_pct,
            status
        FROM transactions
        WHERE status = 'completed'
    """, conn)

    conn.close()

    df.to_parquet("data/bronze/transactions.parquet", index=False)
    print(f"Ingested {len(df)} completed transactions → data/bronze/transactions.parquet")

def ingest_clients():
    conn = psycopg2.connect(**DB_CONFIG)

    df = pd.read_sql("SELECT * FROM clients", conn)
    conn.close()

    df.to_parquet("data/bronze/clients.parquet", index=False)
    print(f"Ingested {len(df)} clients → data/bronze/clients.parquet")

if __name__ == "__main__":
    ingest_transactions()
    ingest_clients()