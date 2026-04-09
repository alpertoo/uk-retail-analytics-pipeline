/* @bruin
name: mart.mart_cancellation_analysis
type: duckdb.sql
depends:
  - staging.stg_retail

materialization:
  type: table

description: "Monthly cancellation trends and top cancelled SKUs. Helps identify products and time periods with elevated return/cancellation activity."

columns:
  - name: revenue_month
    description: "First day of the calendar month."
    checks:
      - name: not_null
  - name: cancelled_invoices
    description: "Count of distinct cancellation invoices that month."
    checks:
      - name: not_null
  - name: cancelled_revenue
    description: "Absolute value of revenue lost to cancellations in GBP."
    checks:
      - name: not_null
  - name: top_cancelled_stock_code
    description: "SKU with the highest cancelled quantity in that month."
  - name: top_cancelled_description
    description: "Product description for the top cancelled SKU."
  - name: top_cancelled_units
    description: "Units cancelled for the top SKU that month."
@bruin */

WITH cancellations AS (
    SELECT
        DATE_TRUNC('month', invoice_date)::DATE          AS revenue_month,
        COUNT(DISTINCT invoice)                           AS cancelled_invoices,
        ROUND(ABS(SUM(revenue)), 2)                       AS cancelled_revenue,
        stock_code,
        -- Most common description per SKU within month
        MODE() WITHIN GROUP (ORDER BY description)        AS description,
        ABS(SUM(quantity))                                AS cancelled_units
    FROM staging.stg_retail
    WHERE is_cancellation = TRUE
    GROUP BY revenue_month, stock_code
),
monthly_totals AS (
    SELECT
        revenue_month,
        SUM(cancelled_invoices) AS cancelled_invoices,
        SUM(cancelled_revenue)  AS cancelled_revenue
    FROM cancellations
    GROUP BY revenue_month
),
top_per_month AS (
    SELECT DISTINCT ON (revenue_month)
        revenue_month,
        stock_code                                        AS top_cancelled_stock_code,
        description                                       AS top_cancelled_description,
        cancelled_units                                   AS top_cancelled_units
    FROM cancellations
    ORDER BY revenue_month, cancelled_units DESC
)
SELECT
    mt.revenue_month,
    mt.cancelled_invoices,
    mt.cancelled_revenue,
    tp.top_cancelled_stock_code,
    tp.top_cancelled_description,
    tp.top_cancelled_units
FROM monthly_totals mt
LEFT JOIN top_per_month tp USING (revenue_month)
ORDER BY mt.revenue_month
