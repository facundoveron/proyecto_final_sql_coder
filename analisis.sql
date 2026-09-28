-- ============================================================================
-- SCRIPT DE ANÁLISIS ESTRATÉGICO DE E-COMMERCE (OLIST DATASET)
-- Rol: Senior E-commerce Data Analyst | Motor: PostgreSQL 14+
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. TOP CLIENTES POR MONTO DE COMPRA (Identificación de Cuentas Clave / Ballenas)
-- Justificación de Negocio:
-- Permite segmentar el percentil superior de clientes para programas VIP, 
-- calcular concentración de facturación (regla 80/20) y priorizar la atención postventa.
-- ----------------------------------------------------------------------------
SELECT 
    c.customer_unique_id,                               -- Identificador persistente del comprador (unifica compras recurrentes del mismo usuario)
    MAX(c.customer_city)        AS customer_city,       -- Ubicación geográfica representativa del cliente
    MAX(c.customer_state)       AS customer_state,      -- Estado federal para análisis macro de demanda regional
    COUNT(DISTINCT o.order_id)  AS total_pedidos,       -- Métrica de frecuencia: evalúa recurrencia vs compra única de alto ticket
    SUM(p.payment_value)        AS total_gastado        -- Valor Monetario acumulado (M del modelo RFM / Gross Revenue devengado)
FROM customer c
JOIN orders o 
    ON c.customer_id = o.customer_id                    -- Vincula la transacción con la identidad temporal del pedido
JOIN order_payment p 
    ON o.order_id = p.order_id                          -- Captura la liquidación monetaria real de la orden (incluye envíos y recargos)
WHERE o.order_status = 'delivered'                      -- Reconocimiento de ingresos devengados: excluye cancelaciones, fraude y pedidos en tránsito
GROUP BY c.customer_unique_id
ORDER BY total_gastado DESC
LIMIT 5;                                                -- Focaliza el esfuerzo comercial en el cohort de mayor impacto monetario


-- ----------------------------------------------------------------------------
-- 2. EVOLUCIÓN HISTÓRICA DE INGRESOS MENSUALES (Monthly GMV & Run-rate)
-- Justificación de Negocio:
-- Monitorear el ritmo de crecimiento MoM (Month-over-Month), detectar estacionalidades
-- macroeconómicas (Black Friday Q4 vs valles en Q1) y proyectar flujo de caja operativo.
-- ----------------------------------------------------------------------------
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS mes, -- Normaliza la granularidad temporal al primer día del mes para series de tiempo
    COUNT(DISTINCT o.order_id)                            AS total_pedidos, -- Volumen transaccional neto para calibrar la capacidad operativa y logística
    SUM(p.payment_value)                                  AS total_ventas,   -- GMV neto liquidado por la pasarela de pagos
    ROUND(SUM(p.payment_value) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS ticket_promedio -- AOV (Average Order Value): detecta si el crecimiento es por volumen o precio
FROM orders o
JOIN order_payment p 
    ON o.order_id = p.order_id                            -- Incorpora el desglose financiero del pedido
WHERE o.order_status = 'delivered'                        -- Considera exclusivamente transacciones efectivizadas y cerradas contablemente
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)::DATE
ORDER BY mes ASC;                                         -- Orden cronológico mandatorio para análisis de cohortes y tendencias temporales


-- ----------------------------------------------------------------------------
-- 3. PRODUCTOS DE BAJA ROTACIÓN / COLA LARGA (Slow Movers & Riesgo de Obsolescencia)
-- Justificación de Negocio:
-- Diagnosticar artículos con nula o mínima tracción comercial para optimizar capital
-- de trabajo inmovilizado, depurar catálogo o renegociar condiciones con sellers específicos.
-- ----------------------------------------------------------------------------
SELECT 
    p.product_id,                                           -- SKUs candidatos a deslistado o remate de inventario
    COALESCE(p.product_category_name, 'SIN_CATEGORIA') AS product_category_name, -- Mitiga sesgos por falta de catalogación en el seller onboarding
    COUNT(oi.order_item_id)                            AS total_unidades_vendidas, -- Unidades físicas absorbidas por el mercado
    ROUND(SUM(oi.price), 2)                            AS ingreso_generado        -- Facturación directa generada (permite diferenciar bajo volumen pero alto margen)
FROM orders o
JOIN order_item oi 
    ON o.order_id = oi.order_id                             -- Accede al detalle a nivel SKU/ítem
JOIN product p 
    ON oi.product_id = p.product_id                         -- Atributos maestros del catálogo
WHERE o.order_status = 'delivered'                          -- Aísla la demanda real satisfecha (evita contar demanda rebotada por stockout)
GROUP BY p.product_id, p.product_category_name
ORDER BY total_unidades_vendidas ASC, ingreso_generado ASC  -- Jerarquiza los productos más críticos por volumen y luego por aporte financiero
LIMIT 3;                                                    -- Muestra de control para acciones inmediatas de depuración de catálogo


-- ----------------------------------------------------------------------------
-- 4. JERARQUÍA Y PARTICIPACIÓN POR CATEGORÍA DE PRODUCTO (Pareto de Categorías)
-- Justificación de Negocio:
-- Permite al equipo de Category Management rankear la demanda para focalizar
-- inversión publicitaria (SEM/Social Ads), acuerdos con sellers y espacio promocional.
-- ----------------------------------------------------------------------------
SELECT
    COALESCE(p.product_category_name, 'SIN_CATEGORIA_ASIGNADA') AS categoria_producto, -- Higiene de datos: clasifica el tráfico no catalogado
    COUNT(oi.order_item_id)                                     AS total_unidades_vendidas, -- Demanda bruta por categoría
    ROUND(SUM(oi.price), 2)                                     AS facturacion_categoria,   -- Ingresos directos generados por la vertical
    DENSE_RANK() OVER (ORDER BY COUNT(oi.order_item_id) DESC)   AS rank_demanda_unidades,  -- Ranking sin saltos numéricos ante eventuales empates en volumen
    ROUND(
        100.0 * COUNT(oi.order_item_id) / NULLIF(SUM(COUNT(oi.order_item_id)) OVER(), 0), 
        2
    )                                                           AS share_unidades_pct      -- Cuota porcentual sobre el total del catálogo vendido
FROM orders o
JOIN order_item oi 
    ON o.order_id = oi.order_id                                 -- Relaciona la orden confirmada con sus líneas de pedido
JOIN product p 
    ON oi.product_id = p.product_id                             -- Clasificación temática del producto
WHERE o.order_status = 'delivered'                              -- Transacciones con ingreso devengado garantizado
GROUP BY p.product_category_name;

