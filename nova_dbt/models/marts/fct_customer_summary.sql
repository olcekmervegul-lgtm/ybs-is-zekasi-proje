SELECT
    customer_id,
    COUNT(*) AS total_orders,
    SUM(total_purchase_amount) AS total_spent,
    AVG(total_purchase_amount) AS avg_order_value
FROM {{ ref('stg_ecom_orders') }}
GROUP BY customer_id