/* @bruin

name: mart.monthly_revenue
type: duckdb.sql
description: Monthly revenue summary for the UK Online Retail dataset. Tracks gross revenue, number of orders, number of customers, quantities sold, cancellation counts and rates over time. Useful for identifying seasonal trends and business growth.

materialization:
  type: table

depends:
  - staging.stg_retail

columns:
  - name: year_month
    type: VARCHAR
    description: Year and month of the transactions (YYYY-MM format).
    checks:
      - name: not_null
      - name: unique
  - name: total_revenue
    type: DOUBLE
    description: Total gross revenue for the month in GBP, excluding cancellations.
    checks:
      - name: not_null
  - name: total_orders
    type: BIGINT
    description: Number of unique invoices in the month, excluding cancellations.
    checks:
      - name: not_null
  - name: total_customers
    type: BIGINT
    description: Number of unique customers who placed orders in the month.
    checks:
      - name: not_null
  - name: total_items_sold
    type: DECIMAL(38,0)
    description: Total units sold in the month, excluding cancellations.
    checks:
      - name: not_null
  - name: cancellation_count
    type: BIGINT
    description: Number of cancellation invoices in the month.
    checks:
      - name: not_null
  - name: cancellation_rate_pct
    type: DOUBLE
    description: Cancellations as a percentage of total invoices (including cancellations).
    checks:
      - name: not_null
  - name: avg_order_value
    type: DOUBLE
    description: Average revenue per order in GBP.
    checks:
      - name: not_null

@bruin */

WITH monthly_sales AS (
    SELECT
        STRFTIME(invoice_date, '%Y-%m')          AS year_month,
        COUNT(DISTINCT invoice)                   AS total_orders,
        COUNT(DISTINCT customer_id)               AS total_customers,
        SUM(quantity)                             AS total_items_sold,
        ROUND(SUM(revenue), 2)                    AS total_revenue
    FROM staging.stg_retail
    WHERE is_cancellation = FALSE
      AND quantity > 0
    GROUP BY 1
),

monthly_cancellations AS (
    SELECT
        STRFTIME(invoice_date, '%Y-%m')          AS year_month,
        COUNT(DISTINCT invoice)                   AS cancellation_count
    FROM staging.stg_retail
    WHERE is_cancellation = TRUE
    GROUP BY 1
)

SELECT
    s.year_month,
    s.total_revenue,
    s.total_orders,
    s.total_customers,
    s.total_items_sold,
    COALESCE(c.cancellation_count, 0)            AS cancellation_count,
    ROUND(
        COALESCE(c.cancellation_count, 0) * 100.0
        / (s.total_orders + COALESCE(c.cancellation_count, 0)),
    2)                                           AS cancellation_rate_pct,
    ROUND(s.total_revenue / s.total_orders, 2)   AS avg_order_value
FROM monthly_sales s
LEFT JOIN monthly_cancellations c
    ON s.year_month = c.year_month
ORDER BY s.year_month
