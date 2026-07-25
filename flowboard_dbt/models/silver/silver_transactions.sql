-- models/silver/silver_transactions.sql
-- Enriched transaction fact — joins staging sources together
-- Calculates FX margin vs target, revenue components

WITH transactions AS (

    SELECT * FROM {{ ref('stg_transactions') }}

),

clients AS (

    SELECT * FROM {{ ref('stg_clients') }}

),

fee_schedule AS (

    SELECT * FROM {{ ref('stg_fx_fee_schedule') }}

),

enriched AS (

    SELECT
        -- Transaction identifiers
        t.transaction_id,
        t.transaction_date,
        t.year,
        t.month,
        t.month_start,

        -- Client dimensions
        t.client_id,
        c.company_name,
        c.country,
        c.segment,

        -- FX details
        t.send_currency,
        t.receive_currency,
        t.corridor,
        t.send_amount,
        t.receive_amount,
        t.fx_rate_applied,
        t.processing_fee_pct,

        -- Revenue components
        t.fee_revenue,

        -- FX margin = actual markup applied on this transaction
        -- Actual margin per transaction based on processing fee applied
        ROUND(t.processing_fee_pct * 100, 4)        AS fx_margin_pct,

        -- FX revenue = send amount × actual markup
        ROUND(
            t.send_amount * f.target_markup_pct
        , 2)                                        AS fx_revenue,

        -- Total revenue per transaction
        ROUND(
            t.fee_revenue +
            (t.send_amount * f.target_markup_pct)
        , 2)                                        AS total_revenue,


        -- Approximate HUF conversion rates (in real life, use ECB rates) ---fixed
        -- HUF conversion of total revenue
        ROUND(
            CASE t.send_currency
                WHEN 'EUR' THEN (t.fee_revenue + (t.send_amount * f.target_markup_pct)) * 390
                WHEN 'GBP' THEN (t.fee_revenue + (t.send_amount * f.target_markup_pct)) * 455
                WHEN 'CHF' THEN (t.fee_revenue + (t.send_amount * f.target_markup_pct)) * 435
                WHEN 'PLN' THEN (t.fee_revenue + (t.send_amount * f.target_markup_pct)) * 95
                WHEN 'USD' THEN (t.fee_revenue + (t.send_amount * f.target_markup_pct)) * 362
                ELSE             t.fee_revenue + (t.send_amount * f.target_markup_pct)
            END
        , 2)                                        AS total_revenue_huf,



        -- Is this corridor performing above or below target markup?
        f.target_markup_pct,
        f.min_markup_pct,
        f.max_markup_pct,

        CASE
            WHEN t.processing_fee_pct >= f.target_markup_pct THEN 'Above Target'
            WHEN t.processing_fee_pct >= f.min_markup_pct    THEN 'Within Range'
            ELSE 'Below Minimum'
        END                                         AS margin_status



    FROM transactions t

    LEFT JOIN clients c
        ON t.client_id = c.client_id

    LEFT JOIN fee_schedule f
        ON t.corridor = f.corridor

)

SELECT * FROM enriched