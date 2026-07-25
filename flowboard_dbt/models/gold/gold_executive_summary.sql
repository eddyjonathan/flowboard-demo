-- models/gold/gold_executive_summary.sql
-- Answers: "Is the business growing and are we hitting targets?"
-- One row per month — connects directly to Power BI executive page

WITH monthly AS (

    SELECT * FROM {{ ref('silver_monthly_summary') }}

),

with_growth AS (

    SELECT
        month_start::DATE    AS month_start,
        TO_CHAR(month_start, 'YYYY-MM')     AS year_month,
        transaction_count,
        active_clients,
        total_volume,
        total_revenue,
        total_fee_revenue,
        total_fx_revenue,
        avg_fx_margin_pct,
        revenue_target_huf,
        target_achievement_pct,
        target_status,

        -- Prior month revenue for MoM calculation
        LAG(total_revenue) OVER (ORDER BY month_start)  AS prior_month_revenue,
        LAG(total_volume)  OVER (ORDER BY month_start)  AS prior_month_volume,
        LAG(active_clients) OVER (ORDER BY month_start) AS prior_month_clients,

        -- MoM growth rates
        ROUND(
            (total_revenue - LAG(total_revenue) OVER (ORDER BY month_start))
            / NULLIF(LAG(total_revenue) OVER (ORDER BY month_start), 0) * 100
        , 2)                                            AS revenue_mom_pct,

        ROUND(
            (total_volume - LAG(total_volume) OVER (ORDER BY month_start))
            / NULLIF(LAG(total_volume) OVER (ORDER BY month_start), 0) * 100
        , 2)                                            AS volume_mom_pct,

        -- 3-month rolling average revenue (smooths out spikes)
        ROUND(
            AVG(total_revenue) OVER (
                ORDER BY month_start
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            )
        , 2)                                            AS revenue_3m_avg,

        -- Cumulative revenue (year to date within each year)
        ROUND(
            SUM(total_revenue) OVER (
                PARTITION BY EXTRACT(YEAR FROM month_start)
                ORDER BY month_start
            )
        , 2)                                            AS ytd_revenue

    FROM monthly

)

SELECT * FROM with_growth
ORDER BY month_start