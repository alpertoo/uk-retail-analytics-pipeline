/* @bruin

name: staging.stg_retail
type: duckdb.sql
description: Cleaned and standardised UK Online Retail II transactions. Nulls handled, cancellations flagged, customer_id cast to integer, revenue derived.

materialization:
  type: table

depends:
  - raw.uk_retail

columns:
  - name: invoice
    description: Invoice number.
    checks:
      - name: not_null
  - name: stock_code
    description: Product code.
    checks:
      - name: not_null
  - name: description
    description: Product name, trimmed of whitespace.
  - name: quantity
    description: Units per transaction. Negative for cancellations/returns.
    checks:
      - name: not_null
  - name: invoice_date
    description: Timestamp of the transaction.
    checks:
      - name: not_null
  - name: price
    description: Unit price in GBP.
    checks:
      - name: not_null
  - name: customer_id
    description: Customer identifier as integer. NULL where not registered.
  - name: country
    description: Customer country.
    checks:
      - name: not_null
  - name: source_sheet
    description: Source Excel sheet.
    checks:
      - name: not_null
  - name: is_cancellation
    description: True if the invoice starts with C, indicating a cancellation.
    checks:
      - name: not_null
  - name: revenue
    description: Gross revenue for the line item (quantity x price). Negative for cancellations.
    checks:
      - name: not_null

@bruin */

SELECT
    invoice,
    stock_code,
    TRIM(description)                                    AS description,
    quantity,
    invoice_date,
    price,
    -- Clean customer_id: remove the .0 decimal and cast to integer
    CASE
        WHEN customer_id = 'nan' THEN NULL
        ELSE TRY_CAST(TRY_CAST(customer_id AS DOUBLE) AS BIGINT)
    END                                                  AS customer_id,
    country,
    source_sheet,
    -- Flag cancellations where invoice starts with 'C'
    CASE
        WHEN invoice LIKE 'C%' THEN TRUE
        ELSE FALSE
    END                                                  AS is_cancellation,
    -- Derive revenue
    ROUND(quantity * price, 2)                           AS revenue
FROM raw.uk_retail
-- Remove rows with no price or clearly bad data
WHERE price >= 0
  AND stock_code NOT IN ('POST', 'D', 'M', 'BANK CHARGES', 'PADS', 'DOT')
