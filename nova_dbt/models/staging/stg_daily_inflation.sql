with source as (
    select * from {{ source('main', 'raw_inflation') }}
),

cleaned as (
    select
        cast(observation_date as date) as inflation_date,
        strftime(cast(observation_date as date), '%Y-%m') as year_month,
        cast(T10YIE as numeric) as inflation_rate
    from source
    where observation_date is not null 
      and T10YIE is not null
)

select * from cleaned