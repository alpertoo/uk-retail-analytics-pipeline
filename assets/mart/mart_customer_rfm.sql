/* @bruin
name: mart.mart_customer_rfm
type: duckdb.sql
depends:
  - staging.stg_retail

materialization:
  type: table

description: "RFM (Recency, Frequency, Monetary) segmentation for registered customers. Each customer is scored 1-5 on each dimension and assigned a segment label."

columns:
  - name: customer_id
    description: "Unique customer identifier."
    checks:
      - name: not_null
      - name: unique
  - name: last_order_date
    description: "Date of the customer's most recent non-cancelled order."
    checks:
      - name: not_null
  - name: recency_days
    description: "Days since the customer's last order, relative to the dataset snapshot date."
    checks:
      - name: not_null
  - name: frequency
    description: "Number of distinct non-cancelled invoices."
    checks:
      - name: not_null
      - name: positive
  - name: monetary
    description: "Total revenue from non-cancelled orders in GBP."
    checks:
      - name: not_null
  - name: r_score
    description: "Recency score 1-5 (5 = most recent)."
    checks:
      - name: not_null
  - name: f_score
    description: "Frequency score 1-5 (5 = most frequent)."
    checks:
      - name: not_null
  - name: m_score
    description: "Monetary score 1-5 (5 = highest spend)."
    checks:
      - name: not_null
  - name: rfm_segment
    description: "Human-readable segment label derived from RFM scores."
    checks:
      - name: not_null
@bruin */

WITH snapshot AS (
    -- Use the day after the latest transaction as the reference point
    SELECT (MAX(invoice_date)::DATE + INTERVAL 1 DAY) AS snapshot_date
    FROM staging.stg_retail
),
customer_base AS (
    SELECT
        customer_id,
        MAX(invoice_date)::DATE                                                 AS last_order_date,
        COUNT(DISTINCT invoice)                                                  AS frequency,
        ROUND(SUM(revenue), 2)                                                   AS monetary
    FROM staging.stg_retail
    WHERE customer_id IS NOT NULL
      AND NOT is_cancellation
    GROUP BY customer_id
),
with_recency AS (
    SELECT
        cb.*,
        (s.snapshot_date - cb.last_order_date)                                  AS recency_days
    FROM customer_base cb
    CROSS JOIN snapshot s
),
scored AS (
    SELECT
        *,
        -- R: lower recency_days = better = higher score
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM with_recency
)
SELECT
    customer_id,
    last_order_date,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                   THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                   THEN 'New Customers'
        WHEN r_score >= 3 AND m_score >= 4                   THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3  THEN 'At Risk'
        WHEN r_score = 1 AND f_score >= 4                    THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score <= 2                   THEN 'Lost'
        ELSE 'Needs Attention'
    END                                                                          AS rfm_segment
FROM scored
ORDER BY monetary DESC
