-- models/staging/stg_transactions.sql
-- Purpose: clean and type-cast raw transactions
-- This is the Bronze → early Silver step

WITH source AS (

    SELECT * FROM {{ source('flowboard_raw', 'transactions') }}

),

cleaned AS (

    SELECT
        transaction_id,
        client_id,
        transaction_date::DATE                          AS transaction_date,
        EXTRACT(YEAR  FROM transaction_date)::INT       AS year,
        EXTRACT(MONTH FROM transaction_date)::INT       AS month,
        DATE_TRUNC('month', transaction_date)::DATE     AS month_start,
        send_currency,
        receive_currency,
        send_currency || '→' || receive_currency        AS corridor,
        send_amount,
        receive_amount,
        fx_rate_applied,
        processing_fee_pct,
        status,

        -- Revenue calculations happen here once, used everywhere downstream
        ROUND(send_amount * processing_fee_pct, 2)      AS fee_revenue,
        ROUND(send_amount * fx_rate_applied, 2)         AS gross_receive_amount

    FROM source
    WHERE status = 'completed'  -- only analyse completed transactions

)

SELECT * FROM cleaned