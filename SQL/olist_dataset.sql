selec
SELECT
    current_database() AS database_name,
    current_user AS connected_user,
    version() AS postgresql_version;

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


SELECT
    table_name,
    COUNT(column_name) AS total_columns
FROM information_schema.columns
WHERE table_schema = 'olist'
GROUP BY table_name
ORDER BY table_name;

select * from olist.dim_customer