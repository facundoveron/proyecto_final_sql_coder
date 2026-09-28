# Proyecto Final - Análisis E-commerce Olist (PostgreSQL)

## Módulo: Clientes & Comportamiento de Compra

---

### Análisis: Top 5 de Clientes con Mayor Nivel de Gasto (High-Value Customers)

#### 1. Contexto & Enfoque de Negocio
En el comercio electrónico, la concentración del valor monetario suele seguir el Principio de Pareto (el 20% de los clientes genera el 80% del GMV). Identificar a los clientes de mayor facturación (**High-Value Customers** o ballenas) es fundamental para:
- Comprender el perfil socioeconómico y geográfico de los compradores de mayor ticket (**Monetary value** en segmentación RFM).
- Diseñar estrategias de retención, programas VIP de fidelización y atención preferencial.
- Diferenciar el comportamiento transaccional esporádico (B2B, revendedores o compras atípicas) del comprador recurrente regular (B2C).
- Filtrar exclusivamente transacciones efectivas (`order_status = 'delivered'`) para evitar distorsiones financieras causadas por pedidos cancelados, devoluciones o fraudes.

---

#### 2. Query PostgreSQL

```sql
-- ============================================================================
-- Análisis: Top 5 de clientes con mayor gasto histórico consolidado
-- Tablas involucradas: customer, orders, order_payment
-- Criterio financiero: Exclusión de órdenes no entregadas ('delivered')
-- ============================================================================

SELECT 
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    SUM(p.payment_value) AS total_gastado -- Consolidación monetaria del cliente
FROM customer c
JOIN orders o 
    ON c.customer_id = o.customer_id     -- Relación 1:1 entre registro de compra y orden
JOIN order_payment p 
    ON o.order_id = p.order_id          -- Relación 1:N con los pagos asociados al pedido
WHERE o.order_status = 'delivered'       -- Solo ingresos devengados y entregados
GROUP BY 
    c.customer_id, 
    c.customer_unique_id, 
    c.customer_city, 
    c.customer_state
ORDER BY total_gastado DESC
LIMIT 5;
```

##### Resultados Obtenidos

| customer_id | customer_unique_id | customer_city | customer_state | total_gastado (BRL) |
| :--- | :--- | :--- | :---: | :---: |
| `1617b1357756262bfa56ab541c47bc16` | `0a0a92112bd4c708ca5fde585afaa872` | rio de janeiro | RJ | $13,664.08 |
| `ec5b2ba62e574342386871631fafd3fc` | `763c8b1c9c68a0229c42c9fc6f662b93` | vila velha | ES | $7,274.88 |
| `c6e2731c5b391845f6800c97401a43a9` | `dc4802a71eae9be1dd28f5d788ceb526` | campo grande | MS | $6,929.31 |
| `f48d464a0baaea338cb25f816991ab1f` | `459bef486812aa25204be022145caa62` | vitoria | ES | $6,922.21 |
| `3fd6777bbce08a352fddd04e4a7cc8f6` | `ff4159b92c40ebe40454e3e6a7c35ed6` | marilia | SP | $6,726.66 |

---

#### 3. Explicación Técnica

1. **Granularidad y Modelado de Datos (Olist Architecture):**
   - En el modelo de Olist, `customer_id` es un identificador por sesión/pedido (clave foránea en `orders`), mientras que `customer_unique_id` representa al individuo físico único en el tiempo.
   - En esta consulta se agrupa por `c.customer_id` y `c.customer_unique_id`. Esto captura el gasto total liquidado por transacción de cliente entregada.
2. **Cardinalidad del `JOIN` y Multiplicidad de Pagos:**
   - La relación entre `orders` y `order_payment` es **1 a N** (un pedido puede dividirse en múltiples métodos de pago, como crédito + cupón/voucher). El uso de `SUM(p.payment_value)` agrega correctamente el valor total liquidado por orden.
3. **Filtro de Integridad Contable:**
   - El predicado `WHERE o.order_status = 'delivered'` previene el cómputo de GMV fantasma proveniente de pedidos cancelados (`canceled`), en tránsito (`shipped`) o no aprobados (`unavailable`), garantizando precisión en el Revenue devengado.
4. **Consideraciones de Índices y Rendimiento:**
   - **Índices FK:** La consulta aprovecha los índices `idx_orders_customer_id` y `idx_order_payment_order_id` sobre las claves foráneas, reduciendo el costo de los joins mediante *Hash Joins* o *Index Scans*.
   - **Optimización recomendada para escala:** Si la tabla `orders` crece a millones de registros, es recomendable un índice compuesto o parcial:
     ```sql
     CREATE INDEX idx_orders_delivered_customer ON orders(customer_id) WHERE order_status = 'delivered';
     ```
     Esto evitaría escanear pedidos con otros estados del ciclo de vida.

---

#### 4. Insights & Accionables

1. **Alta Dispersión de Ticket Promedio vs. Top Spender:**
   - El cliente `#1` en Río de Janeiro gastó **$13,664.08 BRL**, lo cual supera en casi un **88%** al segundo lugar ($7,274.88 BRL). 
   - *Acción:* Realizar un análisis de canasta (*Basket Analysis*) sobre este cliente específico para comprobar si se trató de una compra B2B (volumen mayorista de un mismo ítem) o una compra de lujo/tecnología de alto valor unitario.
2. **Diversificación Geográfica fuera del Eje Tradicional São Paulo Capital:**
   - Aunque São Paulo suele concentrar el mayor volumen de pedidos en Olist, el Top 5 incluye compradores en **Espírito Santo (ES: Vila Velha y Vitória)**, **Mato Grosso do Sul (MS: Campo Grande)** e interior de **São Paulo (Marília)**.
   - *Acción:* Evaluar acuerdos logísticos y tiempos de entrega para el corredor sureste y centro-oeste. Los clientes de alto poder adquisitivo fuera de las capitales principales representan nichos con menor sensibilidad al precio del flete, siempre que el SLA de entrega sea confiable.
3. **Estrategia de Fidelización y LTV:**
   - Para estos clientes clave, el *Customer Acquisition Cost* (CAC) ya fue amortizado con creces. 
   - *Acción:* Implementar un flujo automatizado de nutrición post-venta: encuestas de satisfacción directa (NPS prioritario), soporte dedicado por canal VIP y promociones personalizadas para incentivar una segunda compra dentro del período de recompra esperado (*time-to-second-order*).

---

## Módulo: Ventas & Finanzas

---

### Análisis: Evolución Histórica de Ventas Mensuales (GMV Trend & Seasonality)

#### 1. Contexto & Enfoque de Negocio
El seguimiento longitudinal del **Gross Merchandise Value (GMV)** y la facturación mensual es la métrica reina (*North Star Metric*) para evaluar la salud, escalabilidad y tracción de un marketplace o e-commerce. Este análisis permite:
- **Evaluar las fases de madurez del negocio:** Identificar el período piloto/lanzamiento (*ramp-up*), el ciclo de crecimiento acelerado (*hypergrowth*) y la fase de estabilización o meseta.
- **Detectar picos de estacionalidad e impacto promocional:** Medir el efecto de eventos macroeconómicos como el **Black Friday** (noviembre), Navidad o promociones comerciales de mitad de año.
- **Planificación de capacidad operativa y logística:** Anticipar el volumen de despachos, dimensionar la infraestructura de atención al cliente y prever necesidades de capital de trabajo para los vendedores del marketplace.
- **Consistencia financiera:** Al igual que en el análisis de clientes, la métrica se aísla únicamente para órdenes efectivamente completadas (`order_status = 'delivered'`), reflejando ingresos genuinos libres de cancelaciones y devoluciones.

---

#### 2. Query PostgreSQL

```sql
-- ============================================================================
-- Análisis: Facturación bruta consolidada agrupada por período mensual (GMV)
-- Tablas involucradas: orders, order_payment
-- Lógica temporal: Truncamiento por mes (DATE_TRUNC) sobre timestamp de compra
-- Criterio de liquidación: Pedidos con entrega efectiva ('delivered')
-- ============================================================================

SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) AS mes,
    SUM(p.payment_value) AS total_ventas
FROM orders o
JOIN order_payment p 
    ON o.order_id = p.order_id          -- Agregación de todas las transacciones de pago por pedido
WHERE o.order_status = 'delivered'       -- Exclusión de pedidos cancelados o en proceso
GROUP BY mes
ORDER BY mes;
```

##### Resultados Obtenidos

| Período (Mes) | Ventas Totales (BRL) | Crecimiento MoM (%) | Hito de Negocio / Fase |
| :---: | :---: | :---: | :--- |
| `2016-10-01` | $46,566.71 | — | Fase Piloto / Lanzamiento inicial |
| `2016-12-01` | $19.62 | -99.9% | Período de ajuste técnico / Pausa operativa |
| `2017-01-01` | $127,545.67 | +649,979% | Reinicio oficial de operaciones comerciales |
| `2017-02-01` | $271,298.65 | +112.7% | Escalado acelerado temprano |
| `2017-03-01` | $414,369.39 | +52.7% | Expansión sostenida de catálogo |
| `2017-04-01` | $390,952.18 | -5.7% | Ajuste post-Q1 |
| `2017-05-01` | $567,066.73 | +45.0% | Campaña Día de la Madre |
| `2017-06-01` | $490,225.60 | -13.5% | Corrección estacional de mitad de año |
| `2017-07-01` | $566,403.93 | +15.5% | Recuperación de volumen |
| `2017-08-01` | $646,000.61 | +14.1% | Crecimiento orgánico mensual |
| `2017-09-01` | $701,169.99 | +8.5% | Consolidación Q3 |
| `2017-10-01` | $751,140.27 | +7.1% | Pre-temporada alta |
| `2017-11-01` | **$1,153,528.05** | **+53.6%** | **Pico histórico: Black Friday 2017** |
| `2017-12-01` | $843,199.17 | -26.9% | Resaca post-Black Friday / Ventas navideñas |
| `2018-01-01` | $1,078,606.86 | +27.9% | Liquidaciones de inicio de año |
| `2018-02-01` | $966,510.88 | -10.4% | Efecto calendario (mes corto / Carnaval) |
| `2018-03-01` | $1,120,678.00 | +15.9% | Retorno al nivel > 1M BRL |
| `2018-04-01` | $1,132,933.95 | +1.1% | Meseta de estabilidad operativa |
| `2018-05-01` | $1,128,836.69 | -0.4% | Día de la Madre 2018 |
| `2018-06-01` | $1,012,090.68 | -10.3% | Ajuste de mitad de año |
| `2018-07-01` | $1,027,903.86 | +1.6% | Volumen maduro constante |
| `2018-08-01` | $985,414.28 | -4.1% | Cierre del período observado |

---

#### 3. Explicación Técnica

1. **Agrupación Temporal con `DATE_TRUNC`:**
   - La función nativa de PostgreSQL `DATE_TRUNC('month', timestamp)` trunca cualquier fecha/hora al primer instante de dicho mes (`YYYY-MM-01 00:00:00`). Es significativamente superior a manipular cadenas con `TO_CHAR` o `SUBSTRING`, ya que conserva el tipo de dato nativo `timestamp`, permitiendo ordenamiento cronológico natural sin conversiones de tipos costosas.
2. **Impacto de la Cardinalidad 1:N en Pagos:**
   - Al hacer `JOIN` directo entre `orders` y `order_payment`, si una orden tiene 3 métodos de pago distintos (ej. 2 vouchers y 1 tarjeta de crédito), la fila de la orden se multiplica por 3. Como el objetivo es computar el **monto monetario total recaudado**, el `SUM(p.payment_value)` funciona de forma exacta y no duplica ingresos, ya que cada fila de `order_payment` desagrega una fracción del pago total.
   - *Nota de buenas prácticas:* Si quisiéramos contar pedidos únicos por mes en esta misma consulta, deberíamos usar `COUNT(DISTINCT o.order_id)` en lugar de `COUNT(*)`.
3. **Estrategia de Indexación y Performance:**
   - Para acelerar esta consulta sobre tablas transaccionales de alto volumen, se recomienda un índice compuesto B-tree:
     ```sql
     CREATE INDEX idx_orders_status_timestamp ON orders(order_status, order_purchase_timestamp);
     ```
     O bien un índice parcial que cubra directamente el predicado:
     ```sql
     CREATE INDEX idx_orders_delivered_purchase_ts 
     ON orders(order_purchase_timestamp) 
     WHERE order_status = 'delivered';
     ```
   - Este índice permite a PostgreSQL filtrar inmediatamente el set relevante de órdenes entregadas y ejecutar un *Index Scan* ordenado sobre el timestamp, evitando un costoso *Sequential Scan* en disco y un *Sort* posterior en memoria.

---

#### 4. Insights & Accionables

1. **Hipercrecimiento 2017 y Consolidación de Mercado en 2018:**
   - Durante 2017 la plataforma experimentó una expansión masiva, pasando de **$127.5k BRL en enero** a superar **$1.15M BRL en noviembre** (un incremento del **804%** a lo largo del año).
   - En 2018, el negocio alcanzó una meseta de madurez, estabilizándose consistentemente en una media mensual de **~1.05M BRL**.
   - *Acción:* La empresa pasó de una etapa de adquisición agresiva (*Early Stage*) a una etapa de retención y optimización de márgenes (*Scale-up*). El foco estratégico debe virar de adquirir usuarios a cualquier costo a optimizar el **Customer Lifetime Value (LTV)** y reducir los costos de fulfillment y flete.
2. **Impacto Crítico del Black Friday (Noviembre 2017):**
   - Noviembre de 2017 registró el pico absoluto de la serie ($1,153,528.05 BRL, +53.6% MoM vs. octubre). En diciembre de 2017 las ventas cayeron un 26.9%, lo que demuestra que la demanda navideña en el e-commerce brasileño se anticipó fuertemente en noviembre.
   - *Acción:* 
     - **Gestión de Stock y Vendedores:** Diseñar auditorías de capacidad logística con los sellers 60 días antes de noviembre (septiembre/octubre) para evitar quiebres de inventario (*stockouts*).
     - **Stress Testing Operativo:** Dimensionar servidores, pasarelas de pago y convenios con transportistas para soportar picos de demanda de al menos 1.5x a 2x el promedio mensual regular.
3. **Patrón de Febrero (Efecto Carnaval y Días Hábiles):**
   - Se observa una caída sistemática en febrero respecto a enero (-10.4% en 2018). Esto responde tanto a la menor cantidad de días calendario (28 días) como a la ralentización comercial durante las festividades de Carnaval en Brasil.
   - *Acción:* Ajustar los objetivos de ventas (*targets*) y cuotas comerciales de febrero considerando días hábiles reales o proyectando con métricas de **Ventas Diarias Promedio (ADS - Average Daily Sales)** en lugar de totales mensuales brutos.

---

## Módulo: Producto & Catálogo

---

### Análisis: Diagnóstico de Productos con Menor Rotación (Slow-Movers & Long Tail)

#### 1. Contexto & Enfoque de Negocio
En la gestión de e-commerce y marketplaces, el análisis del extremo inferior de la curva de ventas (la **cola larga** o *Long Tail*) es tan crucial como identificar los *best-sellers*. Los productos de baja o nula rotación (**slow-movers** y **dead stock**) generan fricciones estratégicas y operativas:
- **Costo de oportunidad y capital inmovilizado:** Productos con ventas marginales ocupan espacio en depósitos (*holding costs*), deprecian su valor comercial y diluyen el capital de trabajo de los vendedores (*sellers*).
- **Eficiencia del catálogo y experiencia de búsqueda:** Un catálogo saturado de productos sin tracción perjudica la relevancia en los motores de búsqueda internos (SEO on-site) y reduce la tasa de conversión global (**CR**).
- **Diagnóstico del ciclo de vida del producto:** Permite discernir entre productos en etapa de obsolescencia, artículos de nicho hiperespecífico (B2B / repuestos) o problemas de publicación (*listing issues*, tales como falta de fotografías o descripciones deficientes).

---

#### 2. Query PostgreSQL

```sql
-- ============================================================================
-- Análisis: Identificación de productos con menor volumen de unidades vendidas
-- Tablas involucradas: orders, order_item, product
-- Criterio de liquidación: Pedidos con entrega efectiva ('delivered')
-- Granularidad: Producto y categoría
-- ============================================================================

SELECT 
    p.product_id,
    p.product_category_name,
    COUNT(*) AS total_ventas             -- Unidades efectivas entregadas
FROM orders o
JOIN order_item oi 
    ON o.order_id = oi.order_id          -- Relación 1:N entre cabecera y detalle de ítems
JOIN product p 
    ON oi.product_id = p.product_id      -- Información dimensional del producto
WHERE o.order_status = 'delivered'       -- Solo ítems de órdenes efectivamente entregadas
GROUP BY 
    p.product_id, 
    p.product_category_name
ORDER BY total_ventas ASC
LIMIT 3;
```

##### Resultados Obtenidos

| product_id | product_category_name | total_ventas (unidades) | Diagnóstico Preliminar |
| :--- | :--- | :---: | :--- |
| `9ad4fb75641c9a71f995a06d0386a6f9` | automotivo | 1 | Producto de nicho / Slow-mover |
| `5ed2407e517ceac8615bb4d1ea238fe6` | telefonia | 1 | Accesorio/repuesto de baja rotación |
| `027293c3b6d9e221268d9d6a5ffe5d0b` | industria_comercio_e_negocios | 1 | Artículo industrial B2B esporádico |

---

#### 3. Explicación Técnica

1. **Diferencia Crítica: `INNER JOIN` vs. `LEFT JOIN` (Productos con 0 ventas):**
   - Esta consulta utiliza un `INNER JOIN` desde `orders` pasando por `order_item` hacia `product`. Por definición relacional, este diseño **solo evalúa productos que han tenido al menos una venta entregada**.
   - *Hallazgo de Senior Analyst:* Para detectar el verdadero "inventario muerto" (*dead stock* con 0 ventas absolutas en el marketplace), se requeriría partir de la tabla maestra `product` con un `LEFT JOIN` condicional:
     ```sql
     -- Detección de productos de catálogo sin ninguna venta entregada (Zero-Sellers)
     SELECT p.product_id, p.product_category_name
     FROM product p
     LEFT JOIN (
         SELECT oi.product_id
         FROM order_item oi
         JOIN orders o ON oi.order_id = o.order_id
         WHERE o.order_status = 'delivered'
     ) sold ON p.product_id = sold.product_id
     WHERE sold.product_id IS NULL;
     ```
2. **Empate Masivo en la Cola Larga (*Tie-Breaking* y No Determinismo):**
   - Al haber miles de productos en el catálogo que comparten exactamente **1 venta**, un `ORDER BY total_ventas ASC LIMIT 3` es no determinista sin un criterio secundario de desempate (como fecha de última venta, fecha de alta o ingresos monetarios generados).
3. **Optimización de Índices en Detalle de Órdenes:**
   - Para acelerar la agregación sobre los más de 112,000 registros de `order_item`, es indispensable contar con los índices de clave foránea `idx_order_item_order_id` y `idx_order_item_product_id`.
   - Si la consulta se ejecuta con alta frecuencia, un índice compuesto en `order_item(product_id, order_id)` permite resolver la agregación de ventas por producto mediante un *Index Only Scan*.

---

#### 4. Insights & Accionables

1. **Naturaleza de las Categorías Identificadas:**
   - Las categorías registradas en este Top (`automotivo`, `telefonia`, `industria_comercio_e_negocios`) poseen dinámicas muy dispares:
     - En `industria_comercio_e_negocios`, las compras suelen ser esporádicas y de naturaleza B2B; vender 1 unidad puede ser normal si el margen unitario o el precio es muy alto.
     - En `telefonia` y `automotivo`, rubros de consumo masivo y alta rotación esperada, vender solo 1 unidad suele indicar problemas de competitividad en precio, flete excesivo o desactualización del modelo/compatibilidad.
2. **Auditoría de Calidad del Listing (Content & SEO Score):**
   - Cruzar estos `product_id` con las variables de contenido en la tabla `product`:
     - ¿Tienen pocas fotos (`product_photos_qty <= 1`)?
     - ¿La descripción es escasa (`product_description_lenght < 200 caracteres`)?
   - *Acción:* Implementar un sistema de alertas para los sellers con recomendaciones automáticas: mejorar fotografías, enriquecer especificaciones técnicas y ajustar palabras clave del título.
3. **Estrategias Comerciales para Mitigar Inventario Estancado:**
   - **Bundling / Cross-selling:** Empaquetar productos slow-movers con best-sellers de la misma categoría (ej. protector o cable en `telefonia` incluido junto a un equipo demandado).
   - **Descuentos de Liquidación (*Clearance*):** Promover ofertas relámpago con descuento para liberar espacio en depósito y recuperar liquidez.
   - **Política de Deslistado (*Delisting*):** Si un producto no registra visitas ni ventas durante más de 180 días continuos, pausar la publicación para no canibalizar la visibilidad de los productos de alta conversión.

---

### Análisis: Ranking de Ventas por Categoría de Producto (Window Functions & Category Performance)

#### 1. Contexto & Enfoque de Negocio
La categorización y análisis jerárquico del catálogo permite estructurar la estrategia de **Merchandising**, adquisición de nuevos vendedores (*seller onboarding*) y asignación de presupuesto publicitario. Este análisis aborda objetivos neurálgicos:
- **Identificación de Categorías Tractoras (*Hero Categories*):** Conocer qué categorías concentran la mayor demanda transaccional para negociar mejores comisiones (*take rate*), exclusividades y convenios de abastecimiento.
- **Detección de Brechas de Calidad de Datos (*Data Governance*):** Identificar el impacto de registros sin categoría asignada (`NULL`), lo cual afecta la indexación, los filtros de búsqueda en la app/web y la precisión analítica.
- **Análisis de Diversificación vs. Dependencia:** Evaluar el riesgo de concentración de ingresos y detectar categorías con potencial de crecimiento desaprovechado (*whitespace analysis*), tales como moda, electrónica de alto rendimiento o alimentos.

---

#### 2. Query PostgreSQL

```sql
-- ============================================================================
-- Análisis: Clasificación y jerarquización de categorías por volumen transaccional
-- Tablas involucradas: orders, order_item, product
-- Función analítica: RANK() sobre agregación COUNT(*)
-- Criterio de liquidación: Pedidos con entrega efectiva ('delivered')
-- ============================================================================

SELECT
    p.product_category_name,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_categoria
FROM orders o
JOIN order_item oi 
    ON o.order_id = oi.order_id          -- Detalle de ítems por orden entregada
JOIN product p 
    ON oi.product_id = p.product_id      -- Atributos dimensionales y taxonomía del ítem
WHERE o.order_status = 'delivered'       -- Solo transacciones completadas
GROUP BY p.product_category_name;
```

##### Resultados Obtenidos (Consolidado de 74 Categorías)

| Rango (`RANK`) | Categoría de Producto | Nivel de Rendimiento / Segmento Estratégico |
| :---: | :--- | :--- |
| **1** | `cama_mesa_banho` | **Tier 1 - Líder Absoluto** (Hogar & Textiles) |
| **2** | `beleza_saude` | **Tier 1** (Cuidado Personal & Cosmética) |
| **3** | `esporte_lazer` | **Tier 1** (Deportes, Outdoor & Fitness) |
| **4** | `moveis_decoracao` | **Tier 1** (Muebles & Interiorismo) |
| **5** | `informatica_acessorios` | **Tier 1** (Hardware & Periféricos) |
| **6** | `utilidades_domesticas` | **Tier 1** (Bazar & Artículos de Cocina) |
| **7** | `relogios_presentes` | **Tier 1** (Accesorios de Moda & Regalería) |
| **8** | `telefonia` | **Tier 1** (Smartphones & Accesorios) |
| **9** | `ferramentas_jardim` | **Tier 1** (Bricolaje & Jardinería) |
| **10** | `automotivo` | **Tier 1** (Repuestos & Accesorios Vehiculares) |
| 11 - 19 | `brinquedos`, `cool_stuff`, `perfumaria`, `bebes`, `eletronicos`, `papelaria`, `fashion_bolsas_e_acessorios`, `pet_shop`, `moveis_escritorio` | **Tier 2 - Categorías Consolidadas** (Alta rotación continua) |
| **20** | `[NULL / Sin Categoría]` | ⚠️ **Anomalía de Datos:** Ítems sin clasificación taxonómica |
| 21 - 38 | `consoles_games`, `malas_acessorios`, `construcao_ferramentas_construcao`, `eletrodomesticos`, `eletroportateis`, `instrumentos_musicais`, `casa_construcao`, `livros_interesse_geral`, `alimentos`, `moveis_sala`, `casa_conforto`, `audio`, `bebidas`, `market_place`, `construcao_ferramentas_iluminacao`, `climatizacao`, `moveis_cozinha_area_de_servico_jantar_e_jardim`, `alimentos_bebidas` | **Tier 3 - Categorías Medias** (Rotación moderada) |
| 39 - 68 | `industria_comercio_e_negocios` (39), `livros_tecnicos` (40), `fashion_calcados` (41), `telefonia_fixa` (42), `construcao_ferramentas_jardim` (43), `eletrodomesticos_2` (44), `agro_industria_e_comercio` (45), `pcs` (46), `artes` (47), `sinalizacao_e_seguranca` (47), `construcao_ferramentas_seguranca` (49), `artigos_de_natal` (50), `fashion_underwear_e_moda_praia` (51), `fashion_roupa_masculina` (52), `construcao_ferramentas_ferramentas` (53), `moveis_quarto` (53), `tablets_impressao_imagem` (55), `portateis_casa_forno_e_cafe` (56), `cine_foto` (57), `dvds_blu_ray` (58), `livros_importados` (59), `fashion_roupa_feminina` (60), `artigos_de_festas` (61), `musica` (62), `moveis_colchao_e_estofado` (63), `fraldas_higiene` (63), `flores` (65), `casa_conforto_2` (66), `fashion_esporte` (67), `artes_e_artesanato` (68) | **Tier 4 - Categorías Específicas / Cola Larga** |
| 69 - 74 | `la_cuisine` (69), `cds_dvds_musicais` (69), `portateis_cozinha_e_preparadores_de_alimentos` (69), `pc_gamer` (72), `fashion_roupa_infanto_juvenil` (73), `seguros_e_servicos` (74) | **Tier 5 - Nichos Marginales** (Volumen residual o baja adopción) |

---

#### 3. Explicación Técnica

1. **Mecánica de la Window Function `RANK()` sobre Agregación:**
   - La función analítica `RANK() OVER (ORDER BY COUNT(*) DESC)` se procesa **después** de la fase de agrupación `GROUP BY`.
   - Primero, PostgreSQL agrupa las filas y calcula el `COUNT(*)` por cada categoría; luego, el motor evalúa la ventana clasificando cada categoría en orden decreciente de ventas.
2. **Tratamiento de Empates (*Ties*) y Salto de Rango:**
   - A diferencia de `ROW_NUMBER()` (que asigna números estrictamente secuenciales arbitrando empates) o `DENSE_RANK()` (que no deja huecos tras empates consecutivos), `RANK()` replica el comportamiento olímpico:
     - Las categorías `artes` y `sinalizacao_e_seguranca` empatan en el puesto **47**, por lo que la siguiente categoría salta directamente al puesto **49**.
     - El triple empate en el puesto **69** (`la_cuisine`, `cds_dvds_musicais`, `portateis_cozinha...`) produce un salto hasta el puesto **72** (`pc_gamer`).
3. **Presencia del Valor `NULL` en el Rango 20:**
   - En PostgreSQL, los valores nulos forman su propio grupo dentro del `GROUP BY`.
   - Que `NULL` ocupe la posición número 20 revela un hallazgo de gobierno de datos: existe un volumen considerable de ventas correspondientes a productos que no tienen informada su categoría en la tabla `product`.
   - *Mejora para producción:* Se recomienda enriquecer la consulta con `COALESCE` para visibilizar explícitamente este segmento y no alterar interfaces de reporting:
     ```sql
     SELECT
         COALESCE(p.product_category_name, 'SIN_CATEGORIA_ASIGNADA') AS categoria,
         COUNT(*) AS unidades_vendidas,
         DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_categoria
     FROM orders o
     JOIN order_item oi ON o.order_id = oi.order_id
     JOIN product p ON oi.product_id = p.product_id
     WHERE o.order_status = 'delivered'
     GROUP BY p.product_category_name
     ORDER BY rank_categoria;
     ```

---

#### 4. Insights & Accionables

1. **Dominancia del Eje Hogar, Bienestar y Tecnología (Core Revenue Drivers):**
   - El Top 5 (`cama_mesa_banho`, `beleza_saude`, `esporte_lazer`, `moveis_decoracao`, `informatica_acessorios`) conforma el motor central del marketplace.
   - *Acción:* 
     - **Campañas estacionales:** Concentrar los mayores esfuerzos de marketing de performance y eventos como el Black Friday en estas verticales, donde la elasticidad promocional y la intención de compra son más altas.
     - **Cross-Selling cruzado:** Implementar recomendaciones algorítmicas entre `cama_mesa_banho` y `moveis_decoracao` (alta afinidad de canasta).
2. **Urgencia en Gobierno de Datos y Catalogación (Puesto #20):**
   - El hecho de que la categoría no categorizada supere en ventas a más de 50 categorías formales (como `consoles_games`, `eletrodomesticos` o `alimentos`) representa un problema crítico de experiencia de usuario (UX):
   - *Acción:* 
     - Los clientes que navegan por el menú de categorías **no pueden encontrar estos productos**, limitando su venta únicamente a búsquedas directas por texto.
     - Ejecutar un proceso de saneamiento de datos (vía expresiones regulares o modelos de clasificación NLP sobre el título del producto) para clasificar y reasignar los ítems huérfanos a sus categorías correspondientes.
3. **Oportunidades Inexploradas (*Whitespace Analysis*):**
   - Categorías como `fashion_roupa_feminina` (#60), `fashion_roupa_infanto_juvenil` (#73) y `pc_gamer` (#72) registran volúmenes muy bajos en comparación con el estándar de la industria del comercio electrónico global:
   - *Acción:* 
     - En moda (`fashion`), el bajo rendimiento suele deberse a incertidumbre en tallas, fotos insuficientes o políticas de cambio rígidas. Simplificar devoluciones y mejorar las guías de medidas puede destrabar esta vertical.
     - En `pc_gamer`, realizar una prospección activa para incorporar vendedores especializados con precios competitivos y bundles de hardware.



