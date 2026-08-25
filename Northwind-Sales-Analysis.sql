/* =========================================================
   NORTHWIND SALES ANALYSIS — FULL SQL SCRIPT (T-SQL / SQL Server)
   Tables: dbo.northwind_orders, dbo.northwind_order_details
   ========================================================= */


/* =========================================================
   SECTION 1 — CUSTOMER VALUE ANALYSIS (initial, Top by sales)
   ========================================================= */
SELECT
    o.customer_id,
    COUNT(DISTINCT o.order_id)                                   AS Total_Orders,
    SUM(od.quantity)                                             AS Total_Quantity,
    SUM(od.unit_price * od.quantity * (1 - od.discount))         AS Total_Sales
FROM dbo.northwind_orders AS o
JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id
GROUP BY o.customer_id
ORDER BY Total_Sales DESC;


/* =========================================================
   SECTION 2 — PRODUCT PERFORMANCE
   ========================================================= */
SELECT
    od.product_id,
    SUM(od.quantity)                                             AS Total_Quantity,
    SUM(od.unit_price * od.quantity * (1 - od.discount))         AS Total_Sales
FROM dbo.northwind_order_details AS od
GROUP BY od.product_id
ORDER BY Total_Sales DESC;


/* =========================================================
   SECTION 3 — DISCOUNT ANALYSIS
   ========================================================= */
SELECT
    od.discount,
    COUNT(DISTINCT od.order_id)                                  AS Total_Orders,
    SUM(od.quantity)                                             AS Total_Quantity,
    SUM(od.unit_price * od.quantity * (1 - od.discount))         AS Total_Sales,
    SUM(od.unit_price * od.quantity * (1 - od.discount))
        / COUNT(DISTINCT od.order_id)                            AS Avg_Order_Value
FROM dbo.northwind_order_details AS od
GROUP BY od.discount
ORDER BY od.discount;


/* =========================================================
   SECTION 4 — CROSS-SELL ANALYSIS (self join, no mirrored pairs)
   ========================================================= */
SELECT
    a.product_id  AS Product_A,
    b.product_id  AS Product_B,
    COUNT(DISTINCT a.order_id) AS Orders_Together
FROM dbo.northwind_order_details AS a
JOIN dbo.northwind_order_details AS b
    ON a.order_id = b.order_id
   AND a.product_id < b.product_id
GROUP BY a.product_id, b.product_id
ORDER BY Orders_Together DESC;


/* =========================================================
   SECTION 5 — SHIPPING PERFORMANCE (days & freight per ship_via)
   ========================================================= */
SELECT
    o.ship_via,
    COUNT(*)                                                     AS Total_Orders,
    AVG(DATEDIFF(DAY, o.order_date, o.shipped_date))             AS Avg_Delivery_Days,
    AVG(o.freight)                                                AS Avg_Freight
FROM dbo.northwind_orders AS o
WHERE o.shipped_date IS NOT NULL
GROUP BY o.ship_via
ORDER BY o.ship_via;


/* =========================================================
   SECTION 6 — SHIPPING vs SALES
   ========================================================= */
SELECT
    o.ship_via,
    COUNT(DISTINCT o.order_id)                                   AS Total_Orders,
    SUM(od.unit_price * od.quantity * (1 - od.discount))         AS Total_Sales
FROM dbo.northwind_orders AS o
JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id
GROUP BY o.ship_via
ORDER BY Total_Sales DESC;


/* =========================================================
   SECTION 7 — AVERAGE ORDER VALUE (AOV) PER SHIP VIA
   ========================================================= */
SELECT
    o.ship_via,
    COUNT(DISTINCT o.order_id)                                   AS Total_Orders,
    SUM(od.unit_price * od.quantity * (1 - od.discount))         AS Total_Sales,
    SUM(od.unit_price * od.quantity * (1 - od.discount))
        / COUNT(DISTINCT o.order_id)                             AS AOV
FROM dbo.northwind_orders AS o
JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id
GROUP BY o.ship_via
ORDER BY AOV DESC;


/* =========================================================
   SECTION 8 — TIME TREND (Yearly & Monthly)
   ========================================================= */

-- 8.1 Yearly
SELECT
    YEAR(o.order_date)                                           AS Order_Year,
    COUNT(DISTINCT o.order_id)                                   AS Total_Orders,
    SUM(od.unit_price * od.quantity * (1 - od.discount))         AS Total_Sales
FROM dbo.northwind_orders AS o
JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id
GROUP BY YEAR(o.order_date)
ORDER BY Order_Year;

-- 8.2 Monthly (with AOV, to separate volume-driven vs value-driven swings)
SELECT
    FORMAT(o.order_date, 'yyyy-MM')                              AS Order_Month,
    COUNT(DISTINCT o.order_id)                                   AS Total_Orders,
    SUM(od.unit_price * od.quantity * (1 - od.discount))         AS Total_Sales,
    SUM(od.unit_price * od.quantity * (1 - od.discount))
        / COUNT(DISTINCT o.order_id)                             AS AOV
FROM dbo.northwind_orders AS o
JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id
GROUP BY FORMAT(o.order_date, 'yyyy-MM')
ORDER BY Order_Month;


-- 9. CUSTOMER ANALYSIS
-- =====================================================


-- =====================================================
-- 9.1 ORDER FREQUENCY
-- Business Question:
-- How many distinct orders does each customer place?
-- =====================================================

SELECT
    customer_id,
    COUNT(DISTINCT order_id) AS Total_Orders
FROM dbo.northwind_orders
GROUP BY customer_id
ORDER BY Total_Orders DESC;


-- =====================================================
-- 9.2 CUSTOMER AOV
-- Business Question:
-- Which customers have the highest average order value?
-- =====================================================

SELECT
    o.customer_id,

    COUNT(DISTINCT o.order_id) AS Total_Orders,

    SUM(
        od.unit_price * od.quantity * (1 - od.discount)
    ) AS Total_Sales,

    SUM(
        od.unit_price * od.quantity * (1 - od.discount)
    ) / COUNT(DISTINCT o.order_id) AS AOV

FROM dbo.northwind_orders AS o

JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id

GROUP BY o.customer_id

ORDER BY AOV DESC;


-- =====================================================
-- 9.3 REPEAT CUSTOMERS
-- Business Question:
-- Which customers placed more than one order?
-- Definition:
-- Repeat Customer = 2 or more distinct orders
-- =====================================================

SELECT
    customer_id,
    COUNT(DISTINCT order_id) AS Total_Orders

FROM dbo.northwind_orders

GROUP BY customer_id

HAVING COUNT(DISTINCT order_id) >= 2

ORDER BY Total_Orders DESC;


-- =====================================================
-- 9.4 CUSTOMER SEGMENTATION
-- Business Question:
-- Are high-frequency customers also high-value customers?
--
-- Frequency:
-- Above or equal to median orders = High Frequency
--
-- Value:
-- Above or equal to median sales = High Value
-- =====================================================

WITH CustomerMetrics AS
(
    SELECT
        o.customer_id,

        COUNT(DISTINCT o.order_id) AS Total_Orders,

        SUM(
            od.unit_price * od.quantity * (1 - od.discount)
        ) AS Total_Sales,

        SUM(
            od.unit_price * od.quantity * (1 - od.discount)
        )
        / COUNT(DISTINCT o.order_id) AS AOV

    FROM dbo.northwind_orders AS o

    JOIN dbo.northwind_order_details AS od
        ON o.order_id = od.order_id

    GROUP BY o.customer_id
),

Benchmarks AS
(
    SELECT DISTINCT

        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY Total_Orders)
        OVER () AS Median_Orders,

        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY Total_Sales)
        OVER () AS Median_Sales

    FROM CustomerMetrics
)

SELECT

    c.customer_id,

    c.Total_Orders,

    c.Total_Sales,

    c.AOV,

    CASE
        WHEN c.Total_Orders >= b.Median_Orders
            THEN 'High Frequency'
        ELSE 'Low Frequency'
    END AS Frequency_Level,

    CASE
        WHEN c.Total_Sales >= b.Median_Sales
            THEN 'High Value'
        ELSE 'Low Value'
    END AS Value_Level,

    CASE

        WHEN c.Total_Orders >= b.Median_Orders
             AND c.Total_Sales >= b.Median_Sales
            THEN 'VIP'

        WHEN c.Total_Orders >= b.Median_Orders
             AND c.Total_Sales < b.Median_Sales
            THEN 'Frequent - Upsell'

        WHEN c.Total_Orders < b.Median_Orders
             AND c.Total_Sales >= b.Median_Sales
            THEN 'Premium - Retention'

        ELSE 'Low Priority'

    END AS Customer_Segment

FROM CustomerMetrics AS c

CROSS JOIN Benchmarks AS b

ORDER BY c.Total_Sales DESC;


-- =====================================================
-- 9.5 PARETO ANALYSIS
-- Business Question:
-- How much of total sales is generated by top customers?
-- =====================================================

WITH CustomerSales AS
(
    SELECT

        o.customer_id,

        SUM(
            od.unit_price * od.quantity * (1 - od.discount)
        ) AS Total_Sales

    FROM dbo.northwind_orders AS o

    JOIN dbo.northwind_order_details AS od
        ON o.order_id = od.order_id

    GROUP BY o.customer_id
),

RankedCustomers AS
(
    SELECT

        customer_id,

        Total_Sales,

        RANK() OVER (
            ORDER BY Total_Sales DESC
        ) AS Sales_Rank,

        SUM(Total_Sales) OVER () AS Grand_Total_Sales,

        SUM(Total_Sales) OVER (
            ORDER BY Total_Sales DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS Cumulative_Sales

    FROM CustomerSales
)

SELECT

    customer_id,

    Sales_Rank,

    Total_Sales,

    Cumulative_Sales,

    Cumulative_Sales / Grand_Total_Sales * 100
        AS Cumulative_Sales_Percentage

FROM RankedCustomers

ORDER BY Sales_Rank;


-- =====================================================
-- 9.6 CUSTOMER LIFETIME SPAN
-- Business Question:
-- How long has each customer been active?
-- =====================================================

SELECT

    customer_id,

    MIN(order_date) AS First_Order_Date,

    MAX(order_date) AS Last_Order_Date,

    DATEDIFF(
        DAY,
        MIN(order_date),
        MAX(order_date)
    ) AS Lifetime_Days,

    COUNT(DISTINCT order_id) AS Total_Orders

FROM dbo.northwind_orders

GROUP BY customer_id

ORDER BY Lifetime_Days DESC;

/* =====================================================
   STAGE 2 - STEP 3
   CUSTOMER SEGMENTATION
   ===================================================== */

;WITH OrderTotals AS
(
    SELECT
        o.order_id,
        o.customer_id,

        SUM(
            od.unit_price
            * od.quantity
            * (1 - od.discount)
        ) AS order_value

    FROM dbo.northwind_orders AS o

    JOIN dbo.northwind_order_details AS od
        ON o.order_id = od.order_id

    GROUP BY
        o.order_id,
        o.customer_id
),

CustomerMetrics AS
(
    SELECT
        customer_id,

        COUNT(order_id) AS total_orders,

        SUM(order_value) AS total_sales,

        AVG(order_value) AS aov

    FROM OrderTotals

    GROUP BY
        customer_id
),

CustomerThresholds AS
(
    SELECT
        AVG(total_orders) AS avg_orders,
        AVG(total_sales) AS avg_sales

    FROM CustomerMetrics
)

SELECT
    cm.customer_id,
    cm.total_orders,
    cm.total_sales,
    cm.aov,

    CASE

        WHEN cm.total_orders >= ct.avg_orders
         AND cm.total_sales >= ct.avg_sales
            THEN 'High Frequency + High Value'

        WHEN cm.total_orders >= ct.avg_orders
         AND cm.total_sales < ct.avg_sales
            THEN 'High Frequency + Low Value'

        WHEN cm.total_orders < ct.avg_orders
         AND cm.total_sales >= ct.avg_sales
            THEN 'Low Frequency + High Value'

        ELSE
            'Low Frequency + Low Value'

    END AS customer_segment

FROM CustomerMetrics AS cm

CROSS JOIN CustomerThresholds AS ct

ORDER BY
    cm.total_sales DESC;

    /* =====================================================
   STAGE 2 - STEP 4
   CUSTOMER SEGMENT SUMMARY
   ===================================================== */

;WITH OrderTotals AS
(
    SELECT
        o.order_id,
        o.customer_id,

        SUM(
            od.unit_price
            * od.quantity
            * (1 - od.discount)
        ) AS order_value

    FROM dbo.northwind_orders AS o

    JOIN dbo.northwind_order_details AS od
        ON o.order_id = od.order_id

    GROUP BY
        o.order_id,
        o.customer_id
),

CustomerMetrics AS
(
    SELECT
        customer_id,

        COUNT(order_id) AS total_orders,

        SUM(order_value) AS total_sales,

        AVG(order_value) AS aov

    FROM OrderTotals

    GROUP BY
        customer_id
),

CustomerThresholds AS
(
    SELECT
        AVG(total_orders) AS avg_orders,
        AVG(total_sales) AS avg_sales

    FROM CustomerMetrics
),

CustomerSegments AS
(
    SELECT
        cm.customer_id,
        cm.total_orders,
        cm.total_sales,
        cm.aov,

        CASE

            WHEN cm.total_orders >= ct.avg_orders
             AND cm.total_sales >= ct.avg_sales
                THEN 'High Frequency + High Value'

            WHEN cm.total_orders >= ct.avg_orders
             AND cm.total_sales < ct.avg_sales
                THEN 'High Frequency + Low Value'

            WHEN cm.total_orders < ct.avg_orders
             AND cm.total_sales >= ct.avg_sales
                THEN 'Low Frequency + High Value'

            ELSE
                'Low Frequency + Low Value'

        END AS customer_segment

    FROM CustomerMetrics AS cm

    CROSS JOIN CustomerThresholds AS ct
),

SegmentSummary AS
(
    SELECT
        customer_segment,

        COUNT(customer_id) AS customer_count,

        SUM(total_sales) AS segment_sales,

        AVG(total_orders) AS avg_orders,

        AVG(aov) AS avg_aov

    FROM CustomerSegments

    GROUP BY
        customer_segment
),

OverallTotals AS
(
    SELECT
        SUM(customer_count) AS total_customers,
        SUM(segment_sales) AS total_sales

    FROM SegmentSummary
)

SELECT
    ss.customer_segment,

    ss.customer_count,

    ROUND(
        100.0 * ss.customer_count
        / ot.total_customers,
        2
    ) AS customer_percentage,

    ROUND(
        ss.segment_sales,
        2
    ) AS segment_sales,

    ROUND(
        100.0 * ss.segment_sales
        / ot.total_sales,
        2
    ) AS sales_percentage,

    ROUND(
        ss.avg_orders,
        2
    ) AS avg_orders,

    ROUND(
        ss.avg_aov,
        2
    ) AS avg_aov

FROM SegmentSummary AS ss

CROSS JOIN OverallTotals AS ot

ORDER BY
    ss.segment_sales DESC;


    /* =====================================================
   STAGE 2 - STEP 5
   CUSTOMER PARETO ANALYSIS
   ===================================================== */

;WITH OrderTotals AS
(
    SELECT
        o.order_id,
        o.customer_id,

        SUM(
            od.unit_price
            * od.quantity
            * (1 - od.discount)
        ) AS order_value

    FROM dbo.northwind_orders AS o

    JOIN dbo.northwind_order_details AS od
        ON o.order_id = od.order_id

    GROUP BY
        o.order_id,
        o.customer_id
),

CustomerSales AS
(
    SELECT
        customer_id,
        SUM(order_value) AS total_sales

    FROM OrderTotals

    GROUP BY
        customer_id
),

RankedCustomers AS
(
    SELECT
        customer_id,
        total_sales,

        ROW_NUMBER() OVER (
            ORDER BY total_sales DESC
        ) AS customer_rank,

        SUM(total_sales) OVER (
            ORDER BY total_sales DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_sales,

        SUM(total_sales) OVER () AS total_sales_all

    FROM CustomerSales
)

SELECT
    customer_id,
    customer_rank,
    total_sales,

    cumulative_sales,

    ROUND(
        cumulative_sales * 100.0
        / total_sales_all,
        2
    ) AS cumulative_sales_percentage

FROM RankedCustomers

ORDER BY
    customer_rank;


/* =====================================================
   STAGE 2 - STEP 6
   CUSTOMER RETENTION / REPEAT CUSTOMERS
   ===================================================== */

;WITH CustomerOrders AS
(
    SELECT
        o.customer_id,

        COUNT(DISTINCT o.order_id) AS total_orders

    FROM dbo.northwind_orders AS o

    GROUP BY
        o.customer_id
),

RetentionMetrics AS
(
    SELECT
        customer_id,
        total_orders,

        CASE
            WHEN total_orders = 1
                THEN 'One-Time Customer'

            WHEN total_orders > 1
                THEN 'Repeat Customer'

        END AS customer_type

    FROM CustomerOrders
)

SELECT
    customer_id,
    total_orders,
    customer_type

FROM RetentionMetrics

ORDER BY
    total_orders DESC;


/* =====================================================
   STAGE 2 - STEP 7
   CUSTOMER RECENCY ANALYSIS
   ===================================================== */

;WITH CustomerActivity AS
(
    SELECT
        o.customer_id,

        MIN(o.order_date) AS first_order_date,

        MAX(o.order_date) AS last_order_date,

        COUNT(DISTINCT o.order_id) AS total_orders

    FROM dbo.northwind_orders AS o

    GROUP BY
        o.customer_id
),

CustomerRecency AS
(
    SELECT
        customer_id,

        first_order_date,

        last_order_date,

        total_orders,

        DATEDIFF(
            DAY,
            first_order_date,
            last_order_date
        ) AS customer_lifetime_days,

        DATEDIFF(
            DAY,
            last_order_date,
            (SELECT MAX(order_date)
             FROM dbo.northwind_orders)
        ) AS days_since_last_order

    FROM CustomerActivity
)

SELECT
    customer_id,
    first_order_date,
    last_order_date,
    total_orders,
    customer_lifetime_days,
    days_since_last_order,

    CASE
        WHEN days_since_last_order <= 90
            THEN 'Active'

        WHEN days_since_last_order <= 180
            THEN 'At Risk'

        ELSE
            'Inactive'

    END AS customer_status

FROM CustomerRecency

ORDER BY
    days_since_last_order ASC;


/* =====================================================
   STAGE 2 - STEP 8
   CUSTOMER PRIORITY ANALYSIS
   ===================================================== */

;WITH OrderTotals AS
(
    SELECT
        o.order_id,
        o.customer_id,

        SUM(
            od.unit_price
            * od.quantity
            * (1 - od.discount)
        ) AS order_value

    FROM dbo.northwind_orders AS o

    JOIN dbo.northwind_order_details AS od
        ON o.order_id = od.order_id

    GROUP BY
        o.order_id,
        o.customer_id
),

CustomerMetrics AS
(
    SELECT
        customer_id,

        COUNT(order_id) AS total_orders,

        SUM(order_value) AS total_sales,

        AVG(order_value) AS aov

    FROM OrderTotals

    GROUP BY
        customer_id
),

CustomerThresholds AS
(
    SELECT
        AVG(total_orders) AS avg_orders,
        AVG(total_sales) AS avg_sales

    FROM CustomerMetrics
),

CustomerActivity AS
(
    SELECT
        o.customer_id,

        MIN(o.order_date) AS first_order_date,

        MAX(o.order_date) AS last_order_date

    FROM dbo.northwind_orders AS o

    GROUP BY
        o.customer_id
),

CustomerAnalysis AS
(
    SELECT
        cm.customer_id,

        cm.total_orders,

        cm.total_sales,

        cm.aov,

        ca.first_order_date,

        ca.last_order_date,

        DATEDIFF(
            DAY,
            ca.last_order_date,
            (
                SELECT MAX(order_date)
                FROM dbo.northwind_orders
            )
        ) AS days_since_last_order,

        CASE

            WHEN cm.total_orders >= ct.avg_orders
             AND cm.total_sales >= ct.avg_sales
                THEN 'High Frequency + High Value'

            WHEN cm.total_orders >= ct.avg_orders
             AND cm.total_sales < ct.avg_sales
                THEN 'High Frequency + Low Value'

            WHEN cm.total_orders < ct.avg_orders
             AND cm.total_sales >= ct.avg_sales
                THEN 'Low Frequency + High Value'

            ELSE
                'Low Frequency + Low Value'

        END AS customer_segment

    FROM CustomerMetrics AS cm

    CROSS JOIN CustomerThresholds AS ct

    JOIN CustomerActivity AS ca
        ON cm.customer_id = ca.customer_id
)

SELECT

    customer_id,

    total_orders,

    total_sales,

    aov,

    first_order_date,

    last_order_date,

    days_since_last_order,

    customer_segment,

    CASE

        /* ==========================================
           HIGH VALUE CUSTOMERS
           ========================================== */

        WHEN customer_segment = 'High Frequency + High Value'
             AND days_since_last_order <= 90
            THEN 'Protect & Retain'

        WHEN customer_segment = 'High Frequency + High Value'
             AND days_since_last_order <= 180
            THEN 'Immediate Retention'

        WHEN customer_segment = 'High Frequency + High Value'
             AND days_since_last_order > 180
            THEN 'High Priority Reactivation'


        /* ==========================================
           LOW FREQUENCY + HIGH VALUE
           ========================================== */

        WHEN customer_segment = 'Low Frequency + High Value'
             AND days_since_last_order <= 90
            THEN 'Protect & Retain'

        WHEN customer_segment = 'Low Frequency + High Value'
             AND days_since_last_order <= 180
            THEN 'Immediate Retention'

        WHEN customer_segment = 'Low Frequency + High Value'
             AND days_since_last_order > 180
            THEN 'High Priority Reactivation'


        /* ==========================================
           HIGH FREQUENCY + LOW VALUE
           ========================================== */

        WHEN customer_segment = 'High Frequency + Low Value'
             AND days_since_last_order <= 90
            THEN 'Upsell Opportunity'

        WHEN customer_segment = 'High Frequency + Low Value'
             AND days_since_last_order <= 180
            THEN 'Retention + Upsell'

        WHEN customer_segment = 'High Frequency + Low Value'
             AND days_since_last_order > 180
            THEN 'Reactivation'


        /* ==========================================
           LOW FREQUENCY + LOW VALUE
           ========================================== */

        WHEN customer_segment = 'Low Frequency + Low Value'
             AND days_since_last_order <= 90
            THEN 'Low Priority'

        WHEN customer_segment = 'Low Frequency + Low Value'
             AND days_since_last_order <= 180
            THEN 'Monitor'

        ELSE
            'Low Priority Reactivation'

    END AS priority_level

FROM CustomerAnalysis

ORDER BY
    CASE

        WHEN customer_segment = 'High Frequency + High Value'
             AND days_since_last_order > 180
            THEN 1

        WHEN customer_segment = 'High Frequency + High Value'
             AND days_since_last_order <= 180
            THEN 2

        WHEN customer_segment = 'Low Frequency + High Value'
             AND days_since_last_order > 180
            THEN 3

        WHEN customer_segment = 'Low Frequency + High Value'
             AND days_since_last_order <= 180
            THEN 4

        WHEN customer_segment = 'High Frequency + Low Value'
             AND days_since_last_order <= 180
            THEN 5

        ELSE 6

    END,

    total_sales DESC;
    /* =====================================================
   STAGE 3 - ORDERS ANALYSIS
   ===================================================== */

-- 1. Orders & Sales by Year
SELECT
    YEAR(o.order_date) AS order_year,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS total_sales,
    AVG(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS avg_line_value
FROM dbo.northwind_orders AS o
JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id
GROUP BY
    YEAR(o.order_date)
ORDER BY
    order_year;


-- 2. Monthly Sales Trend
SELECT
    YEAR(o.order_date) AS order_year,
    MONTH(o.order_date) AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS total_sales
FROM dbo.northwind_orders AS o
JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id
GROUP BY
    YEAR(o.order_date),
    MONTH(o.order_date)
ORDER BY
    order_year,
    order_month;


-- 3. Top Orders by Value
SELECT TOP 10
    o.order_id,
    o.customer_id,
    o.order_date,

    SUM(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS order_value

FROM dbo.northwind_orders AS o
JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id

GROUP BY
    o.order_id,
    o.customer_id,
    o.order_date

ORDER BY
    order_value DESC;



/* =====================================================
   STAGE 4 - PRODUCT ANALYSIS
   ===================================================== */

-- 1. Best-Selling Products
SELECT TOP 20
    od.product_id,

    SUM(od.quantity) AS total_quantity_sold,

    SUM(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS total_sales

FROM dbo.northwind_order_details AS od

GROUP BY
    od.product_id

ORDER BY
    total_sales DESC;


-- 2. Products by Revenue + Order Count
SELECT
    od.product_id,

    COUNT(DISTINCT od.order_id) AS order_count,

    SUM(od.quantity) AS total_quantity,

    SUM(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS total_sales,

    AVG(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS avg_line_value

FROM dbo.northwind_order_details AS od

GROUP BY
    od.product_id

ORDER BY
    total_sales DESC;


-- 3. Lowest Performing Products
SELECT TOP 20
    od.product_id,

    SUM(od.quantity) AS total_quantity_sold,

    SUM(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS total_sales

FROM dbo.northwind_order_details AS od

GROUP BY
    od.product_id

ORDER BY
    total_sales ASC;


/* =====================================================
   STAGE 5 - EMPLOYEE & SHIPPING ANALYSIS
   ===================================================== */

-- 1. Employee Performance
SELECT
    o.employee_id,

    COUNT(DISTINCT o.order_id) AS total_orders,

    SUM(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS total_sales,

    AVG(
        od.unit_price
        * od.quantity
        * (1 - od.discount)
    ) AS avg_line_value

FROM dbo.northwind_orders AS o

JOIN dbo.northwind_order_details AS od
    ON o.order_id = od.order_id

GROUP BY
    o.employee_id

ORDER BY
    total_sales DESC;


-- 2. Shipping Performance
SELECT
    o.ship_via,

    COUNT(DISTINCT o.order_id) AS total_orders,

    AVG(
        DATEDIFF(
            DAY,
            o.order_date,
            o.shipped_date
        )
    ) AS avg_shipping_days

FROM dbo.northwind_orders AS o

GROUP BY
    o.ship_via

ORDER BY
    avg_shipping_days ASC;


-- 3. Late Shipping Analysis
SELECT
    CASE
        WHEN DATEDIFF(
            DAY,
            o.order_date,
            o.shipped_date
        ) <= 3
            THEN 'On Time'

        WHEN DATEDIFF(
            DAY,
            o.order_date,
            o.shipped_date
        ) <= 7
            THEN 'Delayed'

        ELSE
            'Highly Delayed'
    END AS shipping_status,

    COUNT(DISTINCT o.order_id) AS total_orders,

    AVG(
        DATEDIFF(
            DAY,
            o.order_date,
            o.shipped_date
        )
    ) AS avg_shipping_days

FROM dbo.northwind_orders AS o

GROUP BY
    CASE
        WHEN DATEDIFF(
            DAY,
            o.order_date,
            o.shipped_date
        ) <= 3
            THEN 'On Time'

        WHEN DATEDIFF(
            DAY,
            o.order_date,
            o.shipped_date
        ) <= 7
            THEN 'Delayed'

        ELSE
            'Highly Delayed'
    END

ORDER BY
    avg_shipping_days;


SELECT @@SERVERNAME AS ServerName,
       DB_NAME() AS DatabaseName;

SELECT order_id, COUNT(*) AS cnt
FROM dbo.northwind_orders
GROUP BY order_id
HAVING COUNT(*) > 1;