-- models/staging/stg_clients.sql

WITH source AS (

    SELECT * FROM {{ source('flowboard_raw', 'clients') }}

),

cleaned AS (

    SELECT
        client_id,
        INITCAP(company_name)       AS company_name,
        country,
        segment,
        onboarded_date,

        -- How many days has this client been with FlowPay
        (CURRENT_DATE - onboarded_date)::INT AS days_as_client

    FROM source

)

SELECT * FROM cleaned