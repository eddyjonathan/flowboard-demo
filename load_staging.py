import pandas as pd
from sqlalchemy import create_engine

engine = create_engine(
    "postgresql://postgres:admin@localhost:5433/flowboard"
)

# Load fx fee schedule (no dependencies — replace works fine)
fees = pd.read_parquet("data/bronze/fx_fee_schedule.parquet")
fees.to_sql("stg_fx_fee_schedule", engine, if_exists="replace", index=False)
print(f"Loaded {len(fees)} rows → stg_fx_fee_schedule")

# Load revenue targets using TRUNCATE to avoid dependency conflict
targets = pd.read_parquet("data/bronze/revenue_targets.parquet")
with engine.connect() as conn:
    conn.execute(text("TRUNCATE TABLE stg_revenue_targets"))
    conn.commit()
targets.to_sql("stg_revenue_targets", engine, if_exists="append", index=False)
print(f"Loaded {len(targets)} rows → stg_revenue_targets")