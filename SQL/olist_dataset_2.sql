CREATE SCHEMA IF NOT EXISTS olist;

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'olist';

-- 1. Customer dimension
CREATE TABLE olist.dim_customer (
    customer_unique_id VARCHAR(50) PRIMARY KEY
);


-- 2. Product dimension
CREATE TABLE olist.dim_product (
    product_id VARCHAR(50) PRIMARY KEY,
    product_category_name TEXT,
    product_category_name_english TEXT,
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC(10,2),
    product_length_cm NUMERIC(10,2),
    product_height_cm NUMERIC(10,2),
    product_width_cm NUMERIC(10,2)
);


-- 3. Seller dimension
CREATE TABLE olist.dim_seller (
    seller_id VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(10),
    seller_city TEXT,
    seller_state VARCHAR(2)
);


-- 4. Date dimension
CREATE TABLE olist.dim_date (
    date DATE PRIMARY KEY,
    year INTEGER,
    month_number INTEGER,
    month_name VARCHAR(20),
    quarter INTEGER,
    day INTEGER,
    day_of_week VARCHAR(20),
    day_of_week_number INTEGER
);


-- 1. Orders fact table
CREATE TABLE olist.fact_orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50),
    order_status VARCHAR(30),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(10),
    customer_city TEXT,
    customer_state VARCHAR(2),
    order_count INTEGER,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES olist.dim_customer(customer_unique_id)
);


-- 2. Order items fact table
CREATE TABLE olist.fact_order_items (
    order_id VARCHAR(50),
    order_item_id INTEGER,
    product_id VARCHAR(50),
    seller_id VARCHAR(50),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    customer_unique_id VARCHAR(50),
    item_count INTEGER,

    PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id)
        REFERENCES olist.fact_orders(order_id),

    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id)
        REFERENCES olist.dim_product(product_id),

    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES olist.dim_seller(seller_id),

    CONSTRAINT fk_items_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES olist.dim_customer(customer_unique_id)
);


-- 3. Payments fact table
CREATE TABLE olist.fact_payments (
    order_id VARCHAR(50),
    payment_sequential INTEGER,
    payment_type VARCHAR(30),
    payment_installments INTEGER,
    payment_value NUMERIC(12,2),
    customer_unique_id VARCHAR(50),

    PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id)
        REFERENCES olist.fact_orders(order_id),

    CONSTRAINT fk_payments_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES olist.dim_customer(customer_unique_id)
);


-- 4. Reviews fact table
CREATE TABLE olist.fact_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    customer_unique_id VARCHAR(50),
    review_count INTEGER,

    PRIMARY KEY (review_id, order_id),

    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES olist.fact_orders(order_id),

    CONSTRAINT fk_reviews_customer
        FOREIGN KEY (customer_unique_id)
        REFERENCES olist.dim_customer(customer_unique_id)
);

CREATE TABLE olist.fact_orders_staging (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT,
    customer_unique_id TEXT,
    customer_zip_code_prefix VARCHAR(10),
    customer_city TEXT,
    customer_state VARCHAR(2),
    order_count INTEGER
);

INSERT INTO olist.fact_orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_count
)
SELECT
    order_id,
    customer_id,
    order_status,

    CASE
        WHEN NULLIF(TRIM(order_purchase_timestamp), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(order_purchase_timestamp, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,

    CASE
        WHEN NULLIF(TRIM(order_approved_at), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(order_approved_at, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,

    CASE
        WHEN NULLIF(TRIM(order_delivered_carrier_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(order_delivered_carrier_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,

    CASE

	
        WHEN NULLIF(TRIM(order_delivered_customer_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(order_delivered_customer_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,

    CASE
        WHEN NULLIF(TRIM(order_estimated_delivery_date), '') IS NULL THEN NULL
        ELSE TO_DATE(order_estimated_delivery_date, 'DD-MM-YYYY')::TIMESTAMP
    END,

    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_count

FROM olist.fact_orders_staging;



CREATE TABLE olist.fact_order_items_staging (
    order_id TEXT,
    order_item_id INTEGER,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TEXT,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    customer_unique_id TEXT,
    item_count INTEGER
);

CREATE TABLE olist.fact_reviews_staging (
    review_id TEXT,
    order_id TEXT,
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TEXT,
    review_answer_timestamp TEXT,
    customer_unique_id TEXT,
    review_count INTEGER
);


INSERT INTO olist.fact_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    customer_unique_id,
    review_count
)
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    CASE
        WHEN NULLIF(TRIM(review_creation_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(review_creation_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,
    CASE
        WHEN NULLIF(TRIM(review_answer_timestamp), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(review_answer_timestamp, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,
    customer_unique_id,
    review_count
FROM olist.fact_reviews_staging;

INSERT INTO olist.fact_order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    customer_unique_id,
    item_count
)
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    CASE
        WHEN NULLIF(TRIM(shipping_limit_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(shipping_limit_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,
    price,
    freight_value,
    customer_unique_id,
    item_count
FROM olist.fact_order_items_staging;


SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS unique_orders
FROM olist.fact_orders;

SELECT *
FROM olist.fact_orders
WHERE order_id = 'a548910a1c6147796b98fdf73dbeba33';

SELECT
    COUNT(*) AS unmatched_reviews
FROM olist.fact_reviews_staging r
LEFT JOIN olist.fact_orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS staging_order_count
FROM olist.fact_orders_staging;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_rows
FROM olist.fact_orders_staging;

SELECT COUNT(*) AS missing_order_ids
FROM olist.fact_orders_staging
WHERE order_id IS NULL
   OR TRIM(order_id) = '';

select * from olist.dim_seller 
select * from olist.fact_order_items_staging

INSERT INTO olist.dim_customer (customer_unique_id)
VALUES ('861eff4711a542e4b93843c6dd7febb0')
ON CONFLICT (customer_unique_id) DO NOTHING;





select * from olist.dim_customer;
select * from olist.dim_date;
select * from olist.dim_product;
select * from olist.dim_seller;
select * from olist.fact_order_items;
select * from olist.fact_payments;
select * from olist.fact_orders;
select * from olist.fact_reviews;

INSERT INTO olist.fact_order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    customer_unique_id,
	item_count
)


SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    CASE
        WHEN NULLIF(TRIM(shipping_limit_date), '') IS NULL THEN NULL
        ELSE TO_TIMESTAMP(shipping_limit_date, 'DD-MM-YYYY HH24:MI')::TIMESTAMP
    END,
    price,
    freight_value,
    customer_unique_id,
    item_count
FROM olist.fact_order_items_staging;


INSERT INTO olist.dim_seller (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
VALUES (
    '3442f8959a84dea7ee197c632cb2df15',
    '13023',
    'campinas',
    'SP'
);


INSERT INTO olist.dim_product (
    product_id,
    product_category_name,
    product_category_name_english,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
VALUES (
    '1e9e8ef04dbcff4541ed26657ea517e5',
    'perfumaria',
    'perfumery',
    40,
    287,
    1,
    225,
    16,
    10,
    14
);


SELECT *
FROM olist.fact_orders_staging
WHERE order_id = 'e481f51cbdc54678b7cc49136f2d6af7';


INSERT INTO olist.fact_orders_staging (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_count
)
VALUES (
    'e481f51cbdc54678b7cc49136f2d6af7',
    '9ef432eb6251297304e76186b10a928d',
    'delivered',
    '02-10-2017 10:56',
    '02-10-2017 11:07',
    '04-10-2017 19:55',
    '10-10-2017 21:25',
    '18-10-2017',
    '7c396fd4830fd04220f754e42b4e5bff',
    '3149',
    'sao paulo',
    'SP',
    1
);



INSERT INTO olist.fact_orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_count
)
SELECT
    order_id,
    customer_id,
    order_status,
    TO_TIMESTAMP(order_purchase_timestamp, 'DD-MM-YYYY HH24:MI'),
    TO_TIMESTAMP(order_approved_at, 'DD-MM-YYYY HH24:MI'),
    TO_TIMESTAMP(order_delivered_carrier_date, 'DD-MM-YYYY HH24:MI'),
    TO_TIMESTAMP(order_delivered_customer_date, 'DD-MM-YYYY HH24:MI'),
    TO_DATE(order_estimated_delivery_date, 'DD-MM-YYYY')::TIMESTAMP,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    order_count
FROM olist.fact_orders_staging
WHERE order_id = 'e481f51cbdc54678b7cc49136f2d6af7';



