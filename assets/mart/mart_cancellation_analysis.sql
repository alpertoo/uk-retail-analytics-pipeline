/* @bruin

name: mart.cancellation_analysis
type: duckdb.sql
description: Cancellation trends and most frequently cancelled products for the UK Online Retail dataset. Tracks monthly cancellation volumes, revenue lost to cancellations, and identifies the products and countries with the highest cancellation activity. Critical for operational risk management.

materialization:
  type: table

depends:
  - staging.stg_retail

columns:
  - name: year_month
    type: VARCHAR
    description: Year and month of the cancellations (YYYY-MM format).
    checks:
      - name: not_null
      - name: unique
  - name: cancellation_count
    type: BIGINT
    description: Number of cancellation invoices in the month.
    checks:
      - name: not_null
  - name: cancelled_items
    type: DECIMAL(38,0)
    description: Total units cancelled in the month.
    checks:
      - name: not_null
  - name: revenue_lost
    type: DOUBLE
    description: Total revenue lost to cancellations in the month in GBP.
    checks:
      - name: not_null
  - name: unique_customers_cancelled
    type: BIGINT
    description: Number of distinct customers who cancelled in the month.
    checks:
      - name: not_null
  - name: unique_products_cancelled
    type: BIGINT
    description: Number of distinct products cancelled in the month.
    checks:
      - name: not_null
  - name: top_cancelled_product
    type: VARCHAR
    description: The stock code of the most cancelled product in the month by quantity.
    checks:
      - name: not_null
  - name: top_cancelled_country
    type: VARCHAR
    description: The country with the most cancellation invoices in the month.
    checks:
      - name: not_null

@bruin */

WITH monthly_cancellations AS (
    SELECT
        STRFTIME(invoice_date, '%Y-%m')              AS year_month,
        COUNT(DISTINCT invoice)                       AS cancellation_count,
        ABS(SUM(quantity))                            AS cancelled_items,
        ROUND(ABS(SUM(revenue)), 2)                   AS revenue_lost,
        COUNT(DISTINCT customer_id)                   AS unique_customers_cancelled,
        COUNT(DISTINCT stock_code)                    AS unique_products_cancelled
    FROM staging.stg_retail
    WHERE is_cancellation = TRUE
    GROUP BY 1
),

top_cancelled_product AS (
    SELECT
        STRFTIME(invoice_date, '%Y-%m')              AS year_month,
        stock_code,
        ABS(SUM(quantity))                            AS cancelled_qty,
        ROW_NUMBER() OVER (
            PARTITION BY STRFTIME(invoice_date, '%Y-%m')
            ORDER BY ABS(SUM(quantity)) DESC
        )                                             AS rn
    FROM staging.stg_retail
    WHERE is_cancellation = TRUE
    GROUP BY 1, 2
),

top_cancelled_country AS (
    SELECT
        STRFTIME(invoice_date, '%Y-%m')              AS year_month,
        country,
        COUNT(DISTINCT invoice)                       AS cancel_count,
        ROW_NUMBER() OVER (
            PARTITION BY STRFTIME(invoice_date, '%Y-%m')
            ORDER BY COUNT(DISTINCT invoice) DESC
        )                                             AS rn
    FROM staging.stg_retail
    WHERE is_cancellation = TRUE
    GROUP BY 1, 2
)

SELECT
    m.year_month,
    m.cancellation_count,
    m.cancelled_items,
    m.revenue_lost,
    m.unique_customers_cancelled,
    m.unique_products_cancelled,
    p.stock_code                                      AS top_cancelled_product,
    c.country                                         AS top_cancelled_country
FROM monthly_cancellations m
LEFT JOIN top_cancelled_product p
    ON m.year_month = p.year_month AND p.rn = 1
LEFT JOIN top_cancelled_country c
    ON m.year_month = c.year_month AND c.rn = 1
ORDER BY m.year_month
