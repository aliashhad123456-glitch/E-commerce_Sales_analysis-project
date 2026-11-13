-- E-commerce Sales Analysis |
-- 1) Create database
CREATE DATABASE IF NOT EXISTS ecommerce_analysis;
USE ecommerce_analysis;


-- Import data/ecommerce_sales.csv using MySQL Workbench Table Data Import Wizard
-- Set order_date and ship_date as DATE columns

UPDATE ecommerce_sales
SET order_date = STR_TO_DATE(order_date, '%Y-%m-%d'),
    ship_date = STR_TO_DATE(ship_date, '%Y-%m-%d' );
    
-- 2) KPI overview
SELECT
    ROUND(SUM(sales),2) AS total_revenue,
    ROUND(SUM(profit),2) AS total_profit,
    ROUND(100*SUM(profit)/NULLIF(SUM(sales),0),2) AS profit_margin_pct,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(quantity) AS units_sold,
    ROUND(SUM(sales)/NULLIF(COUNT(DISTINCT order_id),0),2) AS average_order_value
FROM ecommerce_sales;

-- 3) Monthly revenue and profit trend
SELECT
    DATE_FORMAT(order_date,'%Y-%m') AS order_month,
    ROUND(SUM(sales),2) AS revenue,
    ROUND(SUM(profit),2) AS profit
FROM ecommerce_sales
GROUP BY DATE_FORMAT(order_date,'%Y-%m')
ORDER BY order_month;

-- 4) Category performance
SELECT category, ROUND(SUM(sales),2) as revenue,
       ROUND(SUM(profit),2) as profit,
       ROUND(100*SUM(profit)/NULLIF(SUM(sales),0),2) as profit_margin_pct
FROM ecommerce_sales
GROUP BY category
ORDER BY revenue DESC;

-- 5) Top 10 products by revenue
SELECT product_name, category, ROUND(SUM(sales),2) as revenue,
       ROUND(SUM(profit),2) profit, SUM(quantity) as units_sold
FROM ecommerce_sales
GROUP BY product_name, category
ORDER BY revenue DESC
LIMIT 10;

-- 6) Loss-making products
SELECT product_name, category, ROUND(SUM(sales),2) as revenue,
       ROUND(SUM(profit),2) as profit
FROM ecommerce_sales
GROUP BY product_name, category
HAVING SUM(profit) < 0
ORDER BY profit;

-- 7) Regional performance
SELECT region, ROUND(SUM(sales),2) revenue,
       ROUND(SUM(profit),2) profit,
       ROUND(100*SUM(profit)/NULLIF(SUM(sales),0),2) as profit_margin_pct
FROM ecommerce_sales
GROUP BY region
ORDER BY profit DESC;

-- 8) Discount impact bands
SELECT
  CASE
    WHEN discount_pct = 0 THEN '0%'
    WHEN discount_pct <= 10 THEN '1-10%'
    WHEN discount_pct <= 20 THEN '11-20%'
    ELSE 'Above 20%'
  END AS discount_band,
  COUNT(*) AS line_items,
  ROUND(SUM(sales),2) as revenue,
  ROUND(SUM(profit),2) as profit,
  ROUND(100*SUM(profit)/NULLIF(SUM(sales),0),2) as margin_pct
FROM ecommerce_sales
GROUP BY discount_band
ORDER BY MIN(discount_pct);

-- 9) Customer value: top 10 customers by revenue
SELECT customer_id, customer_segment,
       COUNT(DISTINCT order_id) orders,
       ROUND(SUM(sales),2) lifetime_revenue,
       ROUND(SUM(profit),2) lifetime_profit
FROM ecommerce_sales
GROUP BY customer_id, customer_segment
ORDER BY lifetime_revenue DESC
LIMIT 10;

-- 10) Month-over-month growth using LAG
WITH monthly AS (
  SELECT DATE_FORMAT(order_date,'%Y-%m-01') AS month_start,
         SUM(sales) AS revenue
  FROM ecommerce_sales
  GROUP BY DATE_FORMAT(order_date,'%Y-%m-01')
),
with_previous AS (
  SELECT month_start, revenue,
         LAG(revenue) OVER (ORDER BY month_start) AS previous_month_revenue
  FROM monthly
)
SELECT month_start, ROUND(revenue,2) revenue,
       ROUND(previous_month_revenue,2) previous_month_revenue,
       ROUND(100*(revenue-previous_month_revenue)/NULLIF(previous_month_revenue,0),2) mom_growth_pct
FROM with_previous
ORDER BY month_start;

-- 11) Shipping duration and profit
SELECT
  CASE WHEN DATEDIFF(ship_date,order_date) <= 2 THEN '0-2 days'
       WHEN DATEDIFF(ship_date,order_date) <= 5 THEN '3-5 days'
       ELSE '6+ days' END AS shipping_bucket,
  COUNT(DISTINCT order_id) as orders,
  ROUND(AVG(profit),2) as avg_line_profit
FROM ecommerce_sales
GROUP BY shipping_bucket;

-- 12) Rank products within category
WITH product_profit AS (
  SELECT category, product_name, SUM(profit) AS total_profit
  FROM ecommerce_sales
  GROUP BY category, product_name
)
SELECT category, product_name, ROUND(total_profit,2) total_profit,
       DENSE_RANK() OVER (PARTITION BY category ORDER BY total_profit DESC) AS profit_rank
FROM product_profit;
