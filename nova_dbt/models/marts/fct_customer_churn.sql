{{ config(materialized='table') }}

-- Her satır = bir alışveriş + o ayın ortalama enflasyon beklentisi (FRED T10YIE)
with purchases as (
    select * from {{ ref('stg_ecom_customers') }}
),

inflation as (
    -- Günlük enflasyon verisini aylık ortalamaya çeviriyoruz
    select
        year_month,
        round(avg(inflation_rate), 3) as avg_monthly_inflation
    from {{ ref('stg_daily_inflation') }}
    group by year_month
)

select
    row_number() over (order by p.customer_id, p.purchase_date) as purchase_id,
    p.customer_id,
    p.purchase_date,
    strftime(p.purchase_date, '%Y-%m')  as purchase_year_month,
    p.product_category,
    p.product_price,
    p.quantity,
    p.total_purchase_amount,
    p.payment_method,
    coalesce(p.returns, 0)              as is_returned,
    p.customer_age,
    p.gender,
    p.is_churn,
    i.avg_monthly_inflation             as monthly_inflation_rate
from purchases p
left join inflation i
    on strftime(p.purchase_date, '%Y-%m') = i.year_month