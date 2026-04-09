/* @bruin
name: mart.country_analysis
type: duckdb.sql
depends:
  - staging.stg_retail

materialization:
  type: table

description: "Revenue, order and customer breakdown by country for the UK Online Retail dataset. Identifies the most valuable international markets and compares their cancellation behaviour. Useful for international expansion and market prioritisation decisions."

columns:
  - name: country
    description: "Customer country."
    checks:
      - name: not_null
      - name: unique
  - name: total_revenue
    description: "Total gross revenue from the country in GBP."
    checks:
      - name: not_null
  - name: total_orders
    description: "Number of distinct invoices from the country."
    checks:
      - name: not_null
  - name: total_customers
    description: "Number of distinct customers from the country."
    checks:
      - name: not_null
  - name: total_items_sold
    description: "Total units sold to customers in the country."
    checks:
      - name: not_null
  - name: avg_order_value
    description: "Average revenue per order in GBP."
    checks:
      - name: not_null
  - name: cancellation_count
    description: "Number of cancellation invoices from the country."
    checks:
      - name: not_null
  - name: cancellation_rate_pct
    description: "Cancellations as a percentage of total invoices from the country."
    checks:
      - name: not_null
  - name: revenue_share_pct
    description: "Country revenue as a percentage of total global revenue."
    checks:
      - name: not_null
  - name: revenue_rank
    description: "Rank of the country by total revenue, 1 being highest."
    checks:
      - name: not_null
@bruin */

WITH sales AS (
    SELECT
        country,
        ROUND(SUM(revenue), 2)                        AS total_revenue,
        COUNT(DISTINCT invoice)                        AS total_orders,
        COUNT(DISTINCT customer_id)                    AS total_customers,
        SUM(quantity)                                  AS total_items_sold
    FROM staging.stg_retail
    WHERE is_cancellation = FALSE
      AND quantity > 0
    GROUP BY country
),

cancellations AS (
    SELECT
        country,
        COUNT(DISTINCT invoice)                        AS cancellation_count
    FROM staging.stg_retail
    WHERE is_cancellation = TRUE
    GROUP BY country
),

global_revenue AS (
    SELECT SUM(revenue) AS grand_total
    FROM staging.stg_retail
    WHERE is_cancellation = FALSE
      AND quantity > 0
)

SELECT
    s.country,
    s.total_revenue,
    s.total_orders,
    s.total_customers,
    s.total_items_sold,
    ROUND(s.total_revenue / s.total_orders, 2)        AS avg_order_value,
    COALESCE(c.cancellation_count, 0)                 AS cancellation_count,
    ROUND(
        COALESCE(c.cancellation_count, 0) * 100.0
        / (s.total_orders + COALESCE(c.cancellation_count, 0)),
    2)                                                AS cancellation_rate_pct,
    ROUND(
        s.total_revenue * 100.0
        / (SELECT grand_total FROM global_revenue),
    2)                                                AS revenue_share_pct,
    RANK() OVER (ORDER BY s.total_revenue DESC)        AS revenue_rank
FROM sales s
LEFT JOIN cancellations c
    ON s.country = c.country
ORDER BY s.total_revenue DESC