/* @bruin
name: mart.mart_monthly_revenue
type: duckdb.sql
depends:
  - staging.stg_retail

materialization:
  type: table

description: "Monthly revenue summary. Aggregates gross revenue, order count, unique customer count, and cancellation rate by calendar month."

columns:
  - name: revenue_month
    description: "First day of the calendar month (YYYY-MM-01)."
    checks:
      - name: not_null
  - name: gross_revenue
    description: "Total revenue from non-cancelled transactions in GBP."
    checks:
      - name: not_null
      - name: positive
  - name: total_orders
    description: "Count of distinct invoice numbers (excluding cancellations)."
    checks:
      - name: not_null
      - name: positive
  - name: unique_customers
    description: "Count of distinct customer_ids who placed an order that month."
    checks:
      - name: not_null
  - name: cancellation_rate
    description: "Ratio of cancelled invoices to all invoices in the month (0.0 to 1.0)."
    checks:
      - name: not_null
@bruin */

WITH monthly AS (
    SELECT
        DATE_TRUNC('month', invoice_date)::DATE          AS revenue_month,
        -- Non-cancelled revenue
        ROUND(SUM(CASE WHEN NOT is_cancellation THEN revenue ELSE 0 END), 2)  AS gross_revenue,
        -- Distinct non-cancelled invoices
        COUNT(DISTINCT CASE WHEN NOT is_cancellation THEN invoice END)         AS total_orders,
        -- Distinct customers who ordered
        COUNT(DISTINCT CASE WHEN NOT is_cancellation THEN customer_id END)     AS unique_customers,
        -- All invoices (for cancellation rate)
        COUNT(DISTINCT invoice)                                                  AS all_invoices,
        COUNT(DISTINCT CASE WHEN is_cancellation THEN invoice END)              AS cancelled_invoices
    FROM staging.stg_retail
    GROUP BY 1
)
SELECT
    revenue_month,
    gross_revenue,
    total_orders,
    unique_customers,
    ROUND(cancelled_invoices * 1.0 / NULLIF(all_invoices, 0), 4) AS cancellation_rate
FROM monthly
ORDER BY revenue_month
