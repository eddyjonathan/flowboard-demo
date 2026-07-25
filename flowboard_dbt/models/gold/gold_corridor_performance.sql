-- models/gold/gold_corridor_performance.sql
-- Answers: "Which FX corridors are most profitable?"
-- One row per corridor per month

WITH transactions AS (

    SELECT * FROM {{ ref('silver_transactions') }}

),

aggregated AS (

    SELECT
        month_start::DATE    AS month_start,
        corridor,
        send_currency,
        receive_currency,
        target_markup_pct,
        min_markup_pct,
        max_markup_pct,

        COUNT(transaction_id)               AS transaction_count,
        COUNT(DISTINCT client_id)           AS unique_clients,
        ROUND(SUM(send_amount), 2)          AS total_volume,
        ROUND(SUM(total_revenue), 2)        AS total_revenue,
        ROUND(SUM(fee_revenue), 2)          AS total_fee_revenue,
        ROUND(SUM(fx_revenue), 2)           AS total_fx_revenue,
        ROUND(AVG(fx_margin_pct), 4)        AS avg_fx_margin_pct,

        TO_CHAR(month_start, 'YYYY-MM')     AS year_month,

        -- Revenue margin = revenue as % of volume
        ROUND(
            SUM(total_revenue)
            / NULLIF(SUM(send_amount), 0) * 100
        , 4)                                AS revenue_margin_pct,

        -- Is avg margin within the target range?
        CASE
            WHEN AVG(fx_margin_pct) >= 0.35 THEN '✅ Above Target'
            WHEN AVG(fx_margin_pct) >= 0.28 THEN '⚠️ Within Range'
            ELSE '🔴 Below Minimum'
        END                                 AS corridor_health

    FROM transactions
    GROUP BY
        month_start,
        corridor,
        send_currency,
        receive_currency,
        target_markup_pct,
        min_markup_pct,
        max_markup_pct

),

with_ranking AS (

    SELECT
        *,
        -- Rank corridors by revenue within each month
        RANK() OVER (
            PARTITION BY month_start
            ORDER BY total_revenue DESC
        )                                   AS revenue_rank,


        -- Overall health across all months for summary table
        AVG(avg_fx_margin_pct) OVER (
        PARTITION BY corridor
        )                                   AS corridor_avg_margin_all_months

    FROM aggregated

)

SELECT * FROM with_ranking
ORDER BY month_start, revenue_rank