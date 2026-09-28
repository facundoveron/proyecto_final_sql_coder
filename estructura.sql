-- ============================================================================
-- PROYECTO FINAL - OLIST E-COMMERCE (Coderhouse)
-- SCRIPT DDL (CREATE TABLE) Y DML (COPY / BULK LOAD)
-- Motor: PostgreSQL 14+
-- ============================================================================
-- ARQUITECTURA Y DECISIONES DE DISEÑO:
-- 1. TIPOS DE DATOS EFICIENTES:
--    - Identificadores (MD5 hex de 32 chars): VARCHAR(32).
--    - Monedas (price, freight_value, payment_value): NUMERIC(10, 2) para
--      precisión financiera exacta (evita errores de redondeo de FLOAT).
--    - Códigos postales (ZIP): VARCHAR(5) para preservar ceros a la izquierda (CEP Brasil).
--    - Estados: CHAR(2) longitud fija estándar.
--    - Contadores/Cantidades pequeñas (installments, photos, item_id): SMALLINT (2 bytes).
--    - Timestamps: TIMESTAMP sin zona horaria (8 bytes, microsegundos).
-- 2. INTEGRIDAD REFERENCIAL (FKs):
--    - customer, seller, product son tablas maestras independientes.
--    - orders depende de customer.
--    - order_item depende de orders, product y seller.
--    - order_payment depende de orders.
-- 3. INDEXACIÓN DE CLAVES FORÁNEAS:
--    - PostgreSQL NO indexa FKs automáticamente. Se crean índices B-Tree en FKs
--      para acelerar JOINs y evitar bloqueos de tabla completa en UPDATE/DELETE padre.
-- ============================================================================

-- CREACIÓN DE BASE DE DATOS (Ejecutar en postgres/pgAdmin)
-- \c capstone_project;

CREATE DATABASE capstone_project;


-- ----------------------------------------------------------------------------
-- 0. LIMPIEZA IDEMPOTENTE (Orden inverso a las dependencias)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS order_payment CASCADE;
DROP TABLE IF EXISTS order_item CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS product CASCADE;
DROP TABLE IF EXISTS seller CASCADE;
DROP TABLE IF EXISTS customer CASCADE;

-- ----------------------------------------------------------------------------
-- 1. TABLA: CUSTOMER (Clientes)
-- Archivo origen: olist_customers_dataset.csv (99,441 filas)
-- ----------------------------------------------------------------------------
CREATE TABLE customer (
    customer_id                 VARCHAR(32) PRIMARY KEY,
    customer_unique_id          VARCHAR(32) NOT NULL,
    customer_zip_code_prefix    VARCHAR(5)  NOT NULL,
    customer_city               VARCHAR(100) NOT NULL,
    customer_state              CHAR(2)     NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2. TABLA: SELLER (Vendedores)
-- Archivo origen: olist_sellers_dataset.csv (3,095 filas)
-- ----------------------------------------------------------------------------
CREATE TABLE seller (
    seller_id                   VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix      VARCHAR(5)  NOT NULL,
    seller_city                 VARCHAR(100) NOT NULL,
    seller_state                CHAR(2)     NOT NULL
);

-- ----------------------------------------------------------------------------
-- 3. TABLA: PRODUCT (Productos)
-- Archivo origen: olist_products_dataset.csv (32,951 filas)
-- ----------------------------------------------------------------------------
CREATE TABLE product (
    product_id                  VARCHAR(32) PRIMARY KEY,
    product_category_name       VARCHAR(100),
    product_name_lenght         SMALLINT,
    product_description_lenght  SMALLINT,
    product_photos_qty          SMALLINT,
    product_weight_g            INTEGER,
    product_length_cm           SMALLINT,
    product_height_cm           SMALLINT,
    product_width_cm            SMALLINT
);

-- ----------------------------------------------------------------------------
-- 4. TABLA: ORDERS (Cabecera de Pedidos)
-- Archivo origen: olist_orders_dataset.csv (99,441 filas)
-- ----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id                        VARCHAR(32) PRIMARY KEY,
    customer_id                     VARCHAR(32) NOT NULL,
    order_status                    VARCHAR(20) NOT NULL,
    order_purchase_timestamp        TIMESTAMP   NOT NULL,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP   NOT NULL,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id)
);

-- Índice para optimizar JOINs y validaciones de FK
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- ----------------------------------------------------------------------------
-- 5. TABLA: ORDER_ITEM (Detalle de Pedidos)
-- Archivo origen: olist_order_items_dataset.csv (112,650 filas)
-- ----------------------------------------------------------------------------
CREATE TABLE order_item (
    order_id                    VARCHAR(32)     NOT NULL,
    order_item_id               SMALLINT        NOT NULL,
    product_id                  VARCHAR(32)     NOT NULL,
    seller_id                   VARCHAR(32)     NOT NULL,
    shipping_limit_date         TIMESTAMP       NOT NULL,
    price                       NUMERIC(10, 2)  NOT NULL,
    freight_value               NUMERIC(10, 2)  NOT NULL,

    CONSTRAINT pk_order_item
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_item_orders
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_order_item_product
        FOREIGN KEY (product_id)
        REFERENCES product(product_id),

    CONSTRAINT fk_order_item_seller
        FOREIGN KEY (seller_id)
        REFERENCES seller(seller_id)
);

-- Índices en columnas de Foreign Keys para rendimiento de consultas relacionales
CREATE INDEX idx_order_item_order_id   ON order_item(order_id);
CREATE INDEX idx_order_item_product_id ON order_item(product_id);
CREATE INDEX idx_order_item_seller_id  ON order_item(seller_id);

-- ----------------------------------------------------------------------------
-- 6. TABLA: ORDER_PAYMENT (Transacciones de Pago de Pedidos)
-- Archivo origen: olist_order_payments_dataset.csv (103,886 filas)
-- ----------------------------------------------------------------------------
CREATE TABLE order_payment (
    order_id                    VARCHAR(32)     NOT NULL,
    payment_sequential          SMALLINT        NOT NULL,
    payment_type                VARCHAR(20)     NOT NULL,
    payment_installments        SMALLINT        NOT NULL,
    payment_value               NUMERIC(10, 2)  NOT NULL,

    CONSTRAINT pk_order_payment
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_order_payment_orders
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE CASCADE
);

-- Índice en FK para JOINs con la cabecera
CREATE INDEX idx_order_payment_order_id ON order_payment(order_id);


-- ============================================================================
-- ETAPA DE INGESTIÓN MASIVA (COPY / BULK LOAD)
-- NOTA: Si ejecutas este script desde la consola interactiva psql (cliente),
-- sustituye 'COPY' por '\copy' (sin punto y coma final).
-- ============================================================================

-- 1. Cargar Maestras: Clientes
COPY customer(
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
FROM 'C:/Users/Facundo/Documents/proyecto_final_sql_coder/olist_customers_dataset.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    ENCODING 'UTF8'
);

-- 2. Cargar Maestras: Vendedores
COPY seller(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
FROM 'C:/Users/Facundo/Documents/proyecto_final_sql_coder/olist_sellers_dataset.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    ENCODING 'UTF8'
);

-- 3. Cargar Maestras: Productos
COPY product(
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
FROM 'C:/Users/Facundo/Documents/proyecto_final_sql_coder/olist_products_dataset.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    ENCODING 'UTF8'
);

-- 4. Cargar Hechos Nivel 1: Pedidos (Requiere que existan los clientes)
COPY orders(
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
FROM 'C:/Users/Facundo/Documents/proyecto_final_sql_coder/olist_orders_dataset.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    ENCODING 'UTF8'
);

-- 5. Cargar Hechos Nivel 2: Renglones de Pedidos (Requiere orders, product, seller)
COPY order_item(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
FROM 'C:/Users/Facundo/Documents/proyecto_final_sql_coder/olist_order_items_dataset.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    ENCODING 'UTF8'
);

-- 6. Cargar Hechos Nivel 2: Pagos de Pedidos (Requiere orders)
COPY order_payment(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
FROM 'C:/Users/Facundo/Documents/proyecto_final_sql_coder/olist_order_payments_dataset.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    ENCODING 'UTF8'
);
