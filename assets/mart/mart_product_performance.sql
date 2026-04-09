/* @bruin
name: mart.mart_product_performance
type: duckdb.sql
depends:
  - staging.stg_retail

materialization:
  type: table

description: "Per-SKU revenue and return rate. Identifies top and bottom performing products across the full dataset period."

columns:
  - name: stock_code
    description: "Product code (SKU)."
    checks:
      - name: not_null
      - name: unique
  - name: description
    description: "Most recent product description for this SKU."
  - name: total_revenue
    description: "Cumulative gross revenue (non-cancelled lines) in GBP."
    checks:
      - name: not_null
  - name: total_units_sold
    description: "Total units sold across non-cancelled transactions."
    checks:
      - name: not_null
  - name: total_orders
    description: "Number of distinct invoices containing this SKU."
    checks:
      - name: not_null
      - name: positive
  - name: return_rate
    description: "Ratio of cancelled quantity to sold quantity (0.0 to 1.0)."
    checks:
      - name: not_null
  - name: revenue_rank
    description: "Revenue rank ascending (1 = highest revenue SKU)."
    checks:
      - name: not_null
@bruin */

WITH product_stats AS (
    SELECT
        stock_code,
        -- Pick the most common description per SKU
        MODE() WITHIN GROUP (ORDER BY description)       AS description,
        ROUND(SUM(CASE WHEN NOT is_cancellation THEN revenue ELSE 0 END), 2)  AS total_revenue,
        SUM(CASE WHEN NOT is_cancellation THEN quantity ELSE 0 END)           AS total_units_sold,
        COUNT(DISTINCT CASE WHEN NOT is_cancellation THEN invoice END)        AS total_orders,
        ABS(SUM(CASE WHEN is_cancellation THEN quantity ELSE 0 END))          AS returned_units
    FROM staging.stg_retail
    GROUP BY stock_code
)
SELECT
    stock_code,
    description,
    total_revenue,
    total_units_sold,
    total_orders,
    ROUND(
        returned_units * 1.0 / NULLIF(total_units_sold + returned_units, 0),
        4
    )                                                     AS return_rate,
    RANK() OVER (ORDER BY total_revenue DESC)             AS revenue_rank
FROM product_stats
WHERE total_orders > 0
ORDER BY total_revenue DESC
