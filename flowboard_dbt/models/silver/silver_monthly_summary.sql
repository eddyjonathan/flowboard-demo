-- models/silver/silver_monthly_summary.sql
-- Monthly aggregation joined with revenue targets
-- This powers the "Are we hitting our targets?" view

WITH transactions AS (

    SELECT * FROM {{ ref('silver_transactions') }}

),

targets AS (

    SELECT * FROM {{ ref('stg_revenue_targets') }}

),

monthly_actuals AS (

    SELECT
        month_start,
        COUNT(transaction_id)       AS transaction_count,
        COUNT(DISTINCT client_id)   AS active_clients,
        ROUND(SUM(send_amount), 2)  AS total_volume,
        ROUND(SUM(total_revenue_huf), 2) AS total_revenue,----modified to total_revenue_huf Fix 2
        ROUND(AVG(fx_margin_pct), 4) AS avg_fx_margin_pct,
        ROUND(SUM(fee_revenue), 2)  AS total_fee_revenue,
        ROUND(SUM(fx_revenue), 2)   AS total_fx_revenue

    FROM transactions
    GROUP BY month_start

),

joined AS (

    SELECT
        a.month_start,
        a.transaction_count,
        a.active_clients,
        a.total_volume,
        a.total_revenue,
        a.avg_fx_margin_pct,
        a.total_fee_revenue,
        a.total_fx_revenue,

        -- Join revenue targets from Excel
        t.revenue_target_huf,

        -- How much of the target did we achieve?
        ROUND(
            a.total_revenue / NULLIF(t.revenue_target_huf, 0) * 100
        , 2)                        AS target_achievement_pct,

        -- Are we above or below target?
        CASE
            WHEN a.total_revenue >= t.revenue_target_huf THEN '✅ On Target'
            WHEN a.total_revenue >= t.revenue_target_huf * 0.9 THEN '⚠️ Near Target'
            ELSE '🔴 Below Target'
        END                         AS target_status

    FROM monthly_actuals a
    LEFT JOIN targets t
        ON a.month_start = t.month_start

)

SELECT * FROM joined
ORDER BY month_start