SELECT * FROM OLIST.DIM_CUSTOMER; --customer_unique_id;
SELECT * FROM OLIST.DIM_DATE; --date,year,month_numder,month_name,quarter,day,day_of_week,day_of_week_number;
SELECT * FROM OLIST.DIM_PRODUCT; --product_id,product_category_name,product_category_name_english,product_name_length,product_description_length,product_photos_qty,
                                 --product_weight_g,product_length_cm,product_height_cm,product_width_cm;
SELECT * FROM OLIST.DIM_SELLER; --seller_id,seller_zip_code_prefix,seller_city,seller_stste;
SELECT * FROM OLIST.FACT_ORDER_ITEMS; --order_id,order_items_id,produc_id,seller_id,shipping_limit_date,price,freight_value,customer_unique_id,item_count;
SELECT * FROM OLIST.FACT_ORDERS; --order_id,customer_id,order_status,order_purchase_timestamp,order_approved_at,order_delivered_carrier_date,order_delivered_customer_date,
                                 --order_estimated_delivery_date,customer_unique_id,customer_zip_code_prefix,customer_city,customer_state,order_count;
SELECT * FROM OLIST.FACT_PAYMENTS; --order_id,payment_sequential,payment_type,payment_installments,payment_value,customer_unique_id;
SELECT * FROM OLIST.FACT_REVIEWS; --review_id,order_id,review_score,review_comment_title,review_comment_message,review_creation_date,review_answer_timestamp,customer_unique_id,review_count;

-- Analysis 1 — Overall delivery performance
-- Business question: How well is Olist meeting its estimated delivery dates?

WITH delivery_analysis AS (
    SELECT
        order_id,
        order_delivered_customer_date::DATE AS actual_date,
        order_estimated_delivery_date::DATE AS estimated_date,
        CASE
            WHEN order_delivered_customer_date::DATE
                 <= order_estimated_delivery_date::DATE
            THEN 'On Time'
            ELSE 'Late'
        END AS delivery_status,
        GREATEST(
            order_delivered_customer_date::DATE
            - order_estimated_delivery_date::DATE,
            0
        ) AS delay_days
    FROM olist.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    COUNT(*) AS total_delivered_orders,
    COUNT(*) FILTER (
        WHERE delivery_status = 'On Time'
    ) AS on_time_orders,
    COUNT(*) FILTER (
        WHERE delivery_status = 'Late'
    ) AS late_orders,
    ROUND(
        COUNT(*) FILTER (
            WHERE delivery_status = 'On Time'
        ) * 100.0 / COUNT(*), 2
    ) AS on_time_percentage,
    ROUND(
        COUNT(*) FILTER (
            WHERE delivery_status = 'Late'
        ) * 100.0 / COUNT(*), 2
    ) AS late_percentage,
    ROUND(
        AVG(delay_days) FILTER (
            WHERE delivery_status = 'Late'
        ), 2
    ) AS average_delay_days,
    MAX(delay_days) AS maximum_delay_days
FROM delivery_analysis;


-- Analysis 2 — Delivery delay distribution
-- Business question: How severe are Olist's delivery delays?

WITH delayed_orders AS (
    SELECT
        order_id,
        order_delivered_customer_date::DATE
        - order_estimated_delivery_date::DATE AS delay_days
    FROM olist.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date::DATE
          > order_estimated_delivery_date::DATE
),
delay_groups AS (
    SELECT
        CASE
            WHEN delay_days BETWEEN 1 AND 3 THEN '01. 1-3 Days'
            WHEN delay_days BETWEEN 4 AND 7 THEN '02. 4-7 Days'
            WHEN delay_days BETWEEN 8 AND 14 THEN '03. 8-14 Days'
            ELSE '04. 15+ Days'
        END AS delay_category
    FROM delayed_orders
)
SELECT
    delay_category,
    COUNT(*) AS total_orders,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS percentage_of_late_orders
FROM delay_groups
GROUP BY delay_category
ORDER BY delay_category;

-- Analysis 3 — Monthly delivery performance
-- Business question: Is delivery performance improving or worsening over time?

WITH monthly_delivery AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp)::DATE AS order_month,
        order_id,
        order_delivered_customer_date::DATE AS actual_date,
        order_estimated_delivery_date::DATE AS estimated_date
    FROM olist.fact_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT
    TO_CHAR(order_month, 'YYYY-MM') AS month,
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE actual_date <= estimated_date
    ) AS on_time_orders,
    COUNT(*) FILTER (
        WHERE actual_date > estimated_date
    ) AS late_orders,
    ROUND(
        COUNT(*) FILTER (
            WHERE actual_date > estimated_date
        ) * 100.0 / COUNT(*), 2
    ) AS late_percentage,
    ROUND(
        AVG(actual_date - estimated_date) FILTER (
            WHERE actual_date > estimated_date
        ), 2
    ) AS average_delay_days
FROM monthly_delivery
GROUP BY order_month
ORDER BY order_month;

-- Analysis 4 — Customer satisfaction: On-time vs late delivery
-- One of our most important analyses
-- Business question: Do late deliveries result in lower customer review scores?

WITH delivery_reviews AS (
    SELECT
        o.order_id,
        CASE
            WHEN o.order_delivered_customer_date::DATE
                 <= o.order_estimated_delivery_date::DATE
            THEN 'On Time'
            ELSE 'Late'
        END AS delivery_status,
        r.review_score
    FROM olist.fact_orders o
    INNER JOIN olist.fact_reviews r
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND r.review_score IS NOT NULL
)
SELECT
    delivery_status,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS average_review_score,
    COUNT(*) FILTER (
        WHERE review_score <= 2
    ) AS negative_reviews,
    ROUND(
        COUNT(*) FILTER (
            WHERE review_score <= 2
        ) * 100.0 / COUNT(*), 2
    ) AS negative_review_percentage,
    COUNT(*) FILTER (
        WHERE review_score >= 4
    ) AS positive_reviews,
    ROUND(
        COUNT(*) FILTER (
            WHERE review_score >= 4
        ) * 100.0 / COUNT(*), 2
    ) AS positive_review_percentage
FROM delivery_reviews
GROUP BY delivery_status
ORDER BY delivery_status;

-- Analysis 5 — Overall review score distribution
-- Business question: What is the overall customer satisfaction level?

SELECT
    review_score,
    COUNT(*) AS total_reviews,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS review_percentage
FROM olist.fact_reviews
WHERE review_score BETWEEN 1 AND 5
GROUP BY review_score
ORDER BY review_score;

-- Analysis 6 — State-wise delivery performance
-- Business question: Which Brazilian states experience the most delivery problems?

SELECT
    customer_state AS state,
    COUNT(*) AS total_delivered_orders,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date::DATE
              > order_estimated_delivery_date::DATE
    ) AS late_orders,
    ROUND(
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date::DATE
                  > order_estimated_delivery_date::DATE
        ) * 100.0 / COUNT(*), 2
    ) AS late_percentage,
    ROUND(
        AVG(
            order_delivered_customer_date::DATE
            - order_estimated_delivery_date::DATE
        ) FILTER (
            WHERE order_delivered_customer_date::DATE
                  > order_estimated_delivery_date::DATE
        ), 2
    ) AS average_delay_days
FROM olist.fact_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY customer_state
ORDER BY late_percentage DESC;

-- Analysis 7 — Seller-wise delivery performance
-- Business question: Are certain sellers associated with more delivery delays?

WITH seller_delivery AS (
    SELECT
        oi.seller_id,
        oi.order_id,
        o.order_delivered_customer_date::DATE AS actual_date,
        o.order_estimated_delivery_date::DATE AS estimated_date
    FROM olist.fact_order_items oi
    INNER JOIN olist.fact_orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
)
SELECT
    sd.seller_id,
    ds.seller_state,
    COUNT(*) AS total_order_items,
    COUNT(*) FILTER (
        WHERE sd.actual_date > sd.estimated_date
    ) AS late_order_items,
    ROUND(
        COUNT(*) FILTER (
            WHERE sd.actual_date > sd.estimated_date
        ) * 100.0 / COUNT(*), 2
    ) AS late_percentage,
    ROUND(
        AVG(sd.actual_date - sd.estimated_date) FILTER (
            WHERE sd.actual_date > sd.estimated_date
        ), 2
    ) AS average_delay_days
FROM seller_delivery sd
LEFT JOIN olist.dim_seller ds
    ON sd.seller_id = ds.seller_id
GROUP BY sd.seller_id, ds.seller_state
HAVING COUNT(*) >= 20
ORDER BY late_percentage DESC;

-- Analysis 8 — Product category delivery performance
-- Business question: Are certain product categories associated with more delivery delays?

SELECT dp.product_category_name AS product_category,
   COUNT(foi.order_id) AS total_order_items,
   COUNT(
        CASE
            WHEN fo.order_delivered_customer_date >
                 fo.order_estimated_delivery_date
            THEN 1
        END
    ) AS late_order_items,

    ROUND(
        COUNT(
            CASE
                WHEN fo.order_delivered_customer_date >
                     fo.order_estimated_delivery_date
                THEN 1
            END
        ) * 100.0 / COUNT(foi.order_id),
        2
    ) AS late_percentage,

    ROUND(
        (
            AVG(
                EXTRACT(
                    EPOCH FROM (
                        fo.order_delivered_customer_date -
                        fo.order_estimated_delivery_date
                    )
                ) / 86400
            ) FILTER (
                WHERE fo.order_delivered_customer_date >
                      fo.order_estimated_delivery_date
            )
        )::NUMERIC,
        2
    ) AS average_delay_days

FROM olist.fact_order_items foi

INNER JOIN olist.fact_orders fo
    ON foi.order_id = fo.order_id

INNER JOIN olist.dim_product dp
    ON foi.product_id = dp.product_id

WHERE fo.order_status = 'delivered'
  AND fo.order_delivered_customer_date IS NOT NULL
  AND fo.order_estimated_delivery_date IS NOT NULL
GROUP BY dp.product_category_name
HAVING COUNT(foi.order_id) >= 50
ORDER BY late_percentage DESC;

-- Analysis 9 — Actual delivery time analysis
-- Business question: How long does Olist actually take to deliver an order after purchase?

-- Analysis 9: Actual Delivery Time Analysis

SELECT

    COUNT(order_id) AS total_delivered_orders,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date - order_purchase_timestamp
                )
            ) / 86400
        )::NUMERIC,
        2
    ) AS average_delivery_time_days,

    ROUND(
        PERCENTILE_CONT(0.50) WITHIN GROUP (
            ORDER BY EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date - order_purchase_timestamp
                )
            ) / 86400
        )::NUMERIC,
        2
    ) AS median_delivery_time_days,

    ROUND(
        MIN(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date - order_purchase_timestamp
                )
            ) / 86400
        )::NUMERIC,
        2
    ) AS minimum_delivery_time_days,

    ROUND(
        MAX(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date - order_purchase_timestamp
                )
            ) / 86400
        )::NUMERIC,
        2
    ) AS maximum_delivery_time_days,

    ROUND(
        PERCENTILE_CONT(0.90) WITHIN GROUP (
            ORDER BY EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date - order_purchase_timestamp
                )
            ) / 86400
        )::NUMERIC,
        2
    ) AS percentile_90_delivery_time_days

FROM olist.fact_orders

WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date >= order_purchase_timestamp;

-- Analysis 10 — Delivery delays and business impact
-- Business question: How large is the difference in customer satisfaction between late and on-time deliveries, and how much delivery-related negative feedback does Olist receive?
-- Analysis 10: Delivery Delays and Business Impact

WITH delivery_reviews AS (

    SELECT
        fo.order_id,

        fo.order_delivered_customer_date,
        fo.order_estimated_delivery_date,

        fr.review_score,

        CASE
            WHEN fo.order_delivered_customer_date >
                 fo.order_estimated_delivery_date
            THEN 'Late Delivery'

            ELSE 'On-Time Delivery'
        END AS delivery_status

    FROM olist.fact_orders fo

    INNER JOIN olist.fact_reviews fr
        ON fo.order_id = fr.order_id

    WHERE fo.order_status = 'delivered'
      AND fo.order_delivered_customer_date IS NOT NULL
      AND fo.order_estimated_delivery_date IS NOT NULL
      AND fr.review_score IS NOT NULL
)

SELECT

    COUNT(*) AS total_reviews,

    COUNT(*) FILTER (
        WHERE delivery_status = 'Late Delivery'
    ) AS late_delivery_reviews,

    COUNT(*) FILTER (
        WHERE delivery_status = 'On-Time Delivery'
    ) AS ontime_delivery_reviews,

    ROUND(
        AVG(review_score) FILTER (
            WHERE delivery_status = 'Late Delivery'
        )::NUMERIC,
        2
    ) AS avg_late_delivery_rating,

    ROUND(
        AVG(review_score) FILTER (
            WHERE delivery_status = 'On-Time Delivery'
        )::NUMERIC,
        2
    ) AS avg_ontime_delivery_rating,

    ROUND(
        (
            AVG(review_score) FILTER (
                WHERE delivery_status = 'On-Time Delivery'
            )
            -
            AVG(review_score) FILTER (
                WHERE delivery_status = 'Late Delivery'
            )
        )::NUMERIC,
        2
    ) AS customer_satisfaction_difference,

    COUNT(*) FILTER (
        WHERE delivery_status = 'Late Delivery'
          AND review_score <= 2
    ) AS negative_late_reviews,

    COUNT(*) FILTER (
        WHERE delivery_status = 'On-Time Delivery'
          AND review_score <= 2
    ) AS negative_ontime_reviews,

    ROUND(
        COUNT(*) FILTER (
            WHERE delivery_status = 'Late Delivery'
              AND review_score <= 2
        ) * 100.0 /
        NULLIF(
            COUNT(*) FILTER (
                WHERE delivery_status = 'Late Delivery'
            ), 0
        ),
        2
    ) AS negative_late_review_percentage

FROM delivery_reviews;

-- Analysis 11: Top 10 product categories by revenue
-- Business question: Which product categories generate the highest revenue?

SELECT
    category_revenue.product_category,
    category_revenue.total_revenue
FROM (
    SELECT
        p.product_category_name_english AS product_category,
        SUM(oi.price) AS total_revenue
    FROM olist.fact_order_items oi
    JOIN olist.dim_product p
        ON oi.product_id = p.product_id
    JOIN olist.fact_orders o
        ON oi.order_id = o.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY p.product_category_name_english
) AS category_revenue
ORDER BY category_revenue.total_revenue DESC
LIMIT 10;

