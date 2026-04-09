"""@bruin

name: raw.uk_retail
description: Raw ingestion of the UK Online Retail II dataset (2009-2011). Contains all transactions from both year sheets of the source Excel file before any cleaning or transformation.
connection: duckdb-default

materialization:
  type: table

secrets:
  - key: duckdb-default
    inject_as: duckdb-default

columns:
  - name: invoice
    type: VARCHAR
    description: Invoice number. If it starts with 'C', it indicates a cancellation.
    checks:
      - name: not_null
  - name: stock_code
    type: VARCHAR
    description: Product code. A 5-digit number uniquely assigned to each product.
    checks:
      - name: not_null
  - name: description
    type: VARCHAR
    description: Product name.
  - name: quantity
    type: BIGINT
    description: Number of units per transaction. Negative values indicate returns or cancellations.
    checks:
      - name: not_null
  - name: invoice_date
    type: TIMESTAMP
    description: Date and time of the transaction.
    checks:
      - name: not_null
  - name: price
    type: DOUBLE
    description: Unit price in GBP sterling.
    checks:
      - name: not_null
  - name: customer_id
    type: VARCHAR
    description: Unique customer identifier. NULLs exist where customer was not registered.
  - name: country
    type: VARCHAR
    description: Country where the customer resides.
    checks:
      - name: not_null
  - name: source_sheet
    type: VARCHAR
    description: Source Excel sheet — either '2009-2010' or '2010-2011'.

@bruin"""

import pandas as pd

def materialize():
    # Read both sheets from the Excel file
    df_2009 = pd.read_excel("seeds/online_retail_II.xlsx", sheet_name="Year 2009-2010", engine="openpyxl")
    df_2010 = pd.read_excel("seeds/online_retail_II.xlsx", sheet_name="Year 2010-2011", engine="openpyxl")

    # Add a source sheet column for traceability before combining
    df_2009["source_sheet"] = "2009-2010"
    df_2010["source_sheet"] = "2010-2011"

    # Combine both sheets into one dataframe
    df = pd.concat([df_2009, df_2010], ignore_index=True)

    # Explicitly cast columns to correct types to avoid Arrow conversion errors
    df["Invoice"] = df["Invoice"].astype(str)
    df["StockCode"] = df["StockCode"].astype(str)
    df["Description"] = df["Description"].astype(str)
    df["Customer ID"] = df["Customer ID"].astype(str)
    df["Country"] = df["Country"].astype(str)

    print(f"Total rows loaded: {len(df):,}")
    print(f"Columns: {list(df.columns)}")

    return df
