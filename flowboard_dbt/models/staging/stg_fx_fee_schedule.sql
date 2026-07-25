-- models/staging/stg_fx_fee_schedule.sql

WITH source AS (

    SELECT * FROM {{ source('flowboard_raw', 'stg_fx_fee_schedule') }}

),

cleaned AS (

    SELECT
        corridor,
        target_markup_pct::DECIMAL  AS target_markup_pct,
        min_markup_pct::DECIMAL     AS min_markup_pct,
        max_markup_pct::DECIMAL     AS max_markup_pct
    FROM source

)

SELECT * FROM cleaned