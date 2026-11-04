with source as (
    select * from {{ source('main', 'raw_ecom_churn') }}
),

cleaned as (
    select
        cast("Customer ID" as integer) as customer_id,
        cast("Customer Name" as string) as customer_name,
        cast("Customer Age" as integer) as customer_age,
        cast("Gender" as string) as gender,
        cast("Purchase Date" as date) as purchase_date,
        cast("Product Category" as string) as product_category,
        cast("Product Price" as numeric) as product_price,
        cast("Quantity" as integer) as quantity,
        cast("Total Purchase Amount" as numeric) as total_purchase_amount,
        cast("Payment Method" as string) as payment_method,
        cast("Returns" as integer) as returns,
        cast("Churn" as integer) as is_churn
    from source
    where "Customer ID" is not null
)

select * from cleaned