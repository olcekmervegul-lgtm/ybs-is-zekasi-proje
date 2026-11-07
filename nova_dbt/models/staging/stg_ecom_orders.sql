SELECT
    "Customer ID" AS customer_id,
    "Product Category" AS product_category,
    "Product Price" AS product_price,
    "Quantity" AS quantity,
    "Total Purchase Amount" AS total_purchase_amount,
    "Payment Method" AS payment_method,
    "Purchase Date" AS purchase_date
FROM {{ source('main', 'raw_ecom_churn') }}