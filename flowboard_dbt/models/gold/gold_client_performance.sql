-- models/gold/gold_client_performance.sql
WITH transactions AS (
    SELECT * FROM {{ ref('silver_transactions') }}
),

client_monthly AS (
    SELECT
        month_start::DATE                       AS month_start,
        TO_CHAR(month_start, 'YYYY-MM')         AS year_month,
        client_id,
        company_name,
        country,
        segment,
        COUNT(transaction_id)                   AS transaction_count,
        ROUND(SUM(send_amount), 2)              AS total_volume,
        ROUND(SUM(total_revenue), 2)            AS total_revenue,
        ROUND(AVG(fx_margin_pct), 4)            AS avg_fx_margin_pct,
        MAX(transaction_date)                   AS last_transaction_date
    FROM transactions
    GROUP BY
        month_start,
        client_id,
        company_name,
        country,
        segment
),

with_metrics AS (
    SELECT
        month_start,
        year_month,
        client_id,
        company_name,
        country,
        segment,
        transaction_count,
        total_volume,
        total_revenue,
        avg_fx_margin_pct,
        last_transaction_date,

        LAG(total_revenue) OVER (
            PARTITION BY client_id
            ORDER BY month_start
        )                                       AS prior_month_revenue,

        ROUND(
            (total_revenue - LAG(total_revenue) OVER (
                PARTITION BY client_id ORDER BY month_start)
            ) / NULLIF(LAG(total_revenue) OVER (
                PARTITION BY client_id ORDER BY month_start), 0) * 100
        , 2)                                    AS client_revenue_mom_pct_raw,

        RANK() OVER (
            PARTITION BY month_start
            ORDER BY total_revenue DESC
        )                                       AS monthly_revenue_rank,

        (DATE '2024-06-30' - MAX(last_transaction_date) OVER (
            PARTITION BY client_id
        ))::INT                                 AS days_since_last_txn,

        ROUND(
            total_revenue / NULLIF(SUM(total_revenue) OVER (
                PARTITION BY month_start
            ), 0) * 100
        , 2)                                    AS revenue_share_pct

    FROM client_monthly
),

with_health AS (
    SELECT
        month_start,
        year_month,
        client_id,
        company_name,
        country,
        segment,
        transaction_count,
        total_volume,
        total_revenue,
        avg_fx_margin_pct,
        last_transaction_date,
        prior_month_revenue,
        monthly_revenue_rank,
        days_since_last_txn,
        revenue_share_pct,

        -- Capped MoM % — nulls out synthetic data noise above 150%
        CASE
            WHEN ABS(client_revenue_mom_pct_raw) > 150 THEN NULL
            ELSE client_revenue_mom_pct_raw
        END                                     AS client_revenue_mom_pct,

        -- Client health signal
        CASE
            WHEN days_since_last_txn > 60       THEN '🔴 Churned'
            WHEN days_since_last_txn > 30       THEN '🟡 At Risk'
            WHEN client_revenue_mom_pct_raw < -30 THEN '🟡 Declining'
            ELSE                                     '🟢 Active'
        END                                     AS client_health,

        -- Top 10 flag
        CASE
            WHEN monthly_revenue_rank <= 10 THEN TRUE
            ELSE FALSE
        END                                     AS is_top_10_client

    FROM with_metrics
)

SELECT * FROM with_health
ORDER BY month_start, monthly_revenue_rank