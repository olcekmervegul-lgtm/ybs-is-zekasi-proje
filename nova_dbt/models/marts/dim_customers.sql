{{ config(materialized='table') }}

-- Her satır = bir müşteri, RFM metrikleri ile
-- Recency: son alışverişten bu yana geçen gün
-- Frequency: toplam alışveriş sayısı
-- Monetary: toplam harcama
with purchases as (
    select * from {{ ref('fct_customer_churn') }}
),

ref_date as (
    select max(purchase_date) as max_date from purchases
)

select
    p.customer_id,
    any_value(p.customer_age)                          as customer_age,
    any_value(p.gender)                                as gender,
    min(p.purchase_date)                               as first_purchase_date,
    max(p.purchase_date)                               as last_purchase_date,
    date_diff('day', max(p.purchase_date), r.max_date) as recency_days,
    count(*)                                           as frequency,
    sum(p.total_purchase_amount)                       as monetary,
    sum(p.is_returned)                                 as total_returns,
    round(avg(p.monthly_inflation_rate), 3)            as avg_inflation_exposure,
    max(p.is_churn)                                    as is_churn
from purchases p
cross join ref_date r
group by p.customer_id, r.max_date
