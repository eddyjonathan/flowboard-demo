# FlowBoard — Automated Financial Dashboard

A full end-to-end BI pipeline built as a portfolio project demonstrating 
the **Automated Financial Reporting** for fintech and financial services companies.

## Business Problem

Finance teams at payment companies spend 2–3 days every month manually 
pulling transaction data into Excel, cleaning it, and building reports 
that are already outdated by the time leadership sees them. They have no 
real-time visibility into FX margin by corridor, client revenue trends, 
or early churn signals.

## Solution

A fully automated pipeline that ingests data from two sources daily, 
transforms it through a medallion architecture, and serves a live 
Power BI dashboard refreshed every morning — zero manual work.

## Architecture

PostgreSQL (transactions, clients)
Excel (revenue targets, FX fee schedule)
↓
Python ingestion scripts
↓
dbt transformation (Bronze → Silver → Gold)
↓
Power BI dashboard (3 pages)


## Tech Stack

| Layer | Tool |
|---|---|
| Source systems | PostgreSQL, Excel |
| Ingestion | Python (pandas, psycopg2, openpyxl) |
| Transformation | dbt Core (SQL models) |
| Data model | Star schema (fact + dimensions) |
| Visualization | Power BI (DAX measures) |

## Dashboard Pages

**Page 1 — Executive Overview**
Revenue vs target, MoM growth, 3-month trend, monthly status table

**Page 2 — Corridor Performance**
FX revenue by corridor, volume vs margin scatter, monthly margin heat map

**Page 3 — Client Intelligence**
Active/At Risk client counts, revenue by segment, top client ranking, 
health signals with MoM trends

## Data Models (dbt)

Staging (4 views)
├── stg_transactions
├── stg_clients
├── stg_revenue_targets
└── stg_fx_fee_schedule

Silver (2 views)
├── silver_transactions ← joins + FX calculations
└── silver_monthly_summary ← monthly aggregation + target join

Gold (3 tables)
├── gold_executive_summary ← executive KPIs + MoM metrics
├── gold_corridor_performance ← FX corridor profitability
└── gold_client_performance ← client health + revenue trends

## Project Structure

flowboard_practice/
├── flowboard_dbt/ ← dbt project (models, tests, docs)
├── data/
│ └── bronze/ ← raw Parquet files
├── generate_data.py ← synthetic data generator
├── generate_excel.py ← Excel source generator
├── ingest_postgres.py ← PostgreSQL ingestion
├── ingest_excel.py ← Excel ingestion
├── load_staging.py ← loads Excel data to PostgreSQL
└── README.md

## Setup

1. Install PostgreSQL and create a `flowboard` database
2. Install Python dependencies:
```bash
pip install psycopg2-binary pandas openpyxl sqlalchemy faker dbt-postgres
```
3. Generate and load synthetic data:
```bash
python generate_data.py
python ingest_postgres.py
python generate_excel.py
python ingest_excel.py
python load_staging.py
```
4. Run dbt pipeline:
```bash
cd flowboard_dbt
dbt run
```
5. Open `FlowBoard_Demo.pbix` in Power BI Desktop and refresh


If your finance team still spends days on manual reports, 
[let's talk](https://www.linkedin.com/in/eddy-manouan/).