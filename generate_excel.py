import pandas as pd
import random

random.seed(42)

# ─────────────────────────────────────────
# SHEET 1: Revenue Targets
# CFO sets these at start of each year
# ─────────────────────────────────────────
months = pd.date_range(start="2023-01-01", end="2024-06-01", freq="MS")

targets = []
base_target = 8_000_000  # 8 million HUF base monthly target

for month in months:
    # Targets grow slightly each month (business is growing)
    growth    = 1 + (months.get_loc(month) * 0.015)
    target    = round(base_target * growth, -3)  # round to nearest 1000
    targets.append({
        "month":             month.strftime("%Y-%m"),
        "revenue_target_huf": target
    })

targets_df = pd.DataFrame(targets)

# ─────────────────────────────────────────
# SHEET 2: FX Fee Schedule
# What markup FlowPay charges per corridor
# Maintained by CFO in Excel
# ─────────────────────────────────────────
corridors = ["EUR→HUF", "GBP→HUF", "CHF→HUF", "PLN→HUF", "USD→HUF"]
markups   = [0.015, 0.020, 0.018, 0.012, 0.016]  # target markup per corridor

fee_schedule = pd.DataFrame({
    "corridor":         corridors,
    "target_markup_pct": markups,
    "min_markup_pct":   [m - 0.005 for m in markups],
    "max_markup_pct":   [m + 0.005 for m in markups]
})

# ─────────────────────────────────────────
# SAVE TO EXCEL (two sheets)
# ─────────────────────────────────────────
output_path = "data/finance_targets.xlsx"

import os
os.makedirs("data", exist_ok=True)

with pd.ExcelWriter(output_path, engine="openpyxl") as writer:
    targets_df.to_excel(writer, sheet_name="Revenue_Targets", index=False)
    fee_schedule.to_excel(writer, sheet_name="FX_Fee_Schedule", index=False)

print(f"Excel file created: {output_path}")
print("\nRevenue Targets:")
print(targets_df.to_string())
print("\nFX Fee Schedule:")
print(fee_schedule.to_string())