import pandas as pd
import os

os.makedirs("data/bronze", exist_ok=True)

def ingest_targets():
    df = pd.read_excel(
        "data/finance_targets.xlsx",
        sheet_name="Revenue_Targets"
    )
    df.to_parquet("data/bronze/revenue_targets.parquet", index=False)
    print(f"Ingested {len(df)} monthly targets → data/bronze/revenue_targets.parquet")

def ingest_fee_schedule():
    df = pd.read_excel(
        "data/finance_targets.xlsx",
        sheet_name="FX_Fee_Schedule"
    )
    df.to_parquet("data/bronze/fx_fee_schedule.parquet", index=False)
    print(f"Ingested {len(df)} corridor rules → data/bronze/fx_fee_schedule.parquet")

if __name__ == "__main__":
    ingest_targets()
    ingest_fee_schedule()