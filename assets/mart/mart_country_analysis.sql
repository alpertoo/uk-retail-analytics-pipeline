/* @bruin
name: mart.mart_country_analysis
type: duckdb.sql
depends:
  - staging.stg_retail

materialization:
  type: table

description: "Revenue, order volume, and customer count broken down by country. Useful for understanding international sales distribution."

columns:
  - name: country
    description: "Customer country."
    checks:
      - name: not_null
      - name: unique
  - name: gross_revenue
    description: "Total non-cancelled revenue in GBP."
    checks:
      - name: not_null
      - name: positive
  - name: total_orders
    description: "Distinct non-cancelled invoices."
    checks:
      - name: not_null
      - name: positive
  - name: unique_customers
    description: "Distinct registered customer IDs."
    checks:
      - name: not_null
  - name: avg_order_value
    description: "Average revenue per non-cancelled invoice in GBP."
    checks:
      - name: not_null
  - name: revenue_share
    description: "Country's share of total pipeline gross revenue (0.0 to 1.0)."
    checks:
      - name: not_null
  - name: revenue_rank
    description: "Rank by gross revenue (1 = highest)."
    checks:
      - name: not_null
@bruin */

WITH country_stats AS (
    SELECT
        country,
        ROUND(SUM(CASE WHEN NOT is_cancellation THEN revenue ELSE 0 END), 2)   AS gross_revenue,
        COUNT(DISTINCT CASE WHEN NOT is_cancellation THEN invoice END)          AS total_orders,
        COUNT(DISTINCT CASE WHEN NOT is_cancellation THEN customer_id END)      AS unique_customers
    FROM staging.stg_retail
    GROUP BY country
),
total AS (
    SELECT SUM(gross_revenue) AS pipeline_revenue FROM country_stats
)
SELECT
    cs.country,
    cs.gross_revenue,
    cs.total_orders,
    cs.unique_customers,
    ROUND(cs.gross_revenue / NULLIF(cs.total_orders, 0), 2)                    AS avg_order_value,
    ROUND(cs.gross_revenue / NULLIF(t.pipeline_revenue, 0), 4)                 AS revenue_share,
    RANK() OVER (ORDER BY cs.gross_revenue DESC)                               AS revenue_rank
FROM country_stats cs
CROSS JOIN total t
WHERE cs.total_orders > 0
ORDER BY cs.gross_revenue DESC
