-- models/staging/stg_revenue_targets.sql

WITH source AS (

    SELECT * FROM {{ source('flowboard_raw', 'stg_revenue_targets') }}

),

cleaned AS (

    SELECT
        TO_DATE(month, 'YYYY-MM')       AS month_start,
        revenue_target_huf::DECIMAL     AS revenue_target_huf

    FROM source

)

SELECT * FROM cleaned