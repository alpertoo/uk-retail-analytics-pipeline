# UK Retail Analytics Pipeline

A data engineering pipeline that transforms 2 years of raw UK wholesale retail transactions into a structured analytical system built entirely with Bruin.

---

## Problem Statement

A UK based online retailer selling gift-ware to wholesalers across 40 countries generated over 1 million transactions between December 2009 and December 2011. The raw data lived in Excel sheets with no structure, no quality checks, and no analytical layer on top.

This pipeline transforms that raw data into an analytical system that answers five business questions:

1. How is revenue trending month by month, and what does the seasonal pattern look like?
2. Which products generate the most revenue and which ones have dangerously high return rates?
3. Which customers are Champions, which are At Risk, and which are already Lost?
4. Which international markets are the most valuable and which have the highest cancellation rates?
5. How much revenue is being lost to cancellations each month, and is it getting worse over time?

---

## Architecture

The pipeline follows a three layer medallion architecture, all running locally on DuckDB.

**Layer 1 — Raw** (`raw.uk_retail`)
A Python asset that reads both Excel sheets from the source file and loads all 1,067,371 rows into DuckDB without any transformations.

**Layer 2 — Staging** (`staging.stg_retail`)
A SQL asset that cleans the raw data, flags cancellations, derives revenue, removes bad stock codes, and casts columns to the correct types.

**Layer 3 — Marts** (5 tables)
Five SQL assets that produce analytics ready tables for business consumption:

| Table | Description |
|---|---|
| `mart.monthly_revenue` | 25 months of revenue, orders, customers and cancellation rates |
| `mart.product_performance` | All products ranked by revenue with return rate analysis |
| `mart.customer_rfm` | RFM segmentation — Champions, Loyal, At Risk, Lost |
| `mart.country_analysis` | 40 countries ranked by revenue with cancellation behaviour |
| `mart.cancellation_analysis` | Monthly cancellation trends and revenue lost |

GitHub Actions validates the full pipeline on every push to main and runs on a daily schedule.

---

## Tech Stack

| Tool | Role |
|---|---|
| [Bruin CLI](https://getbruin.com/) | Ingestion, transformation, orchestration and quality checks |
| [DuckDB](https://duckdb.org/) | Local analytical database, zero setup required |
| [Python + pandas](https://pandas.pydata.org/) | Reading and loading the source Excel file |
| [GitHub Actions](https://github.com/features/actions) | CI/CD pipeline validation on every push |

---

## Dataset

The dataset is the Online Retail II dataset published by the UCI Machine Learning Repository, sourced from a real UK based non-store online retailer that sells unique gift-ware mainly to wholesalers.

- **Source**: [UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/502/online+retail+ii)
- **Provider**: London South Bank University
- **Size**: 1,067,371 rows across two years
- **Coverage**: December 2009 to December 2011
- **Geography**: 40 countries, predominantly UK wholesale customers
- **Key fields**: Invoice, StockCode, Description, Quantity, InvoiceDate, Price, CustomerID, Country

The dataset is not included in this repository due to its size. Download it from the UCI link above and place it at `seeds/online_retail_II.xlsx` before running the pipeline.

---

## Key Findings

### Revenue Seasonality
November is the peak month in both years, with £1.44M in November 2010 and £1.46M in November 2011. This is driven by Christmas gift wholesale orders placed well in advance. January drops sharply each year, confirming strong seasonal dependence that the business should plan around.

### Product Return Rates
Two of the top 10 products by revenue have critical return rate problems. PAPER CRAFT, LITTLE BIRDIE sits at rank 4 with £168K in revenue but a 100% return rate, meaning every single unit sold was eventually returned. MEDIUM CERAMIC TOP STORAGE JAR at rank 9 has a 95.46% return rate. Both products are generating revenue on paper but losing it entirely through returns, which is a serious operational and financial risk.

### Customer Segments
The RFM analysis segmented 5,865 customers into six groups:

| Segment | Customers | Avg Spend | Avg Orders |
|---|---|---|---|
| Champion | 655 | £14,444 | 24.2 |
| Loyal | 1,476 | £2,724 | 7.2 |
| At Risk | 801 | £2,720 | 6.9 |
| Potential Loyalist | 801 | £814 | 1.6 |
| Others | 1,277 | £675 | 1.9 |
| Lost | 855 | £325 | 1.0 |

The 801 At Risk customers have almost identical spending patterns to Loyal customers but have not purchased recently. A targeted retention campaign focused on this group could recover a significant amount of revenue before they move to Lost.

### International Markets
The UK accounts for 85.68% of total revenue, confirming this is primarily a domestic wholesale business. Ireland stands out with only 5 customers generating £640K, which points to a small number of very high value wholesale accounts. Germany has the highest cancellation rate among the top 10 markets at 27.38%, which warrants investigation.

### Cancellation Losses
December 2011 recorded £204,650 in revenue lost to cancellations in just 9 days, the highest of any month in the dataset. This is likely driven by large year end wholesale order cancellations and suggests the business carries significant exposure from bulk orders placed but not fulfilled.

---

## Data Quality

The pipeline runs 66 automated quality checks across all 7 assets, all passing. These include:

- `not_null` checks on every key column across all layers
- `unique` checks on primary keys such as `year_month`, `stock_code`, `customer_id` and `country`
- Business logic checks such as cancellation flags, revenue derivation and RFM score assignment

---

## How to Reproduce

### Prerequisites
- Python 3.11 or higher
- Bruin CLI: `curl -LsSf https://getbruin.com/install/cli | sh`

### 1. Clone the repo
```bash
git clone https://github.com/alpertoo/uk-retail-analytics-pipeline.git
cd uk-retail-analytics-pipeline
```

### 2. Download the dataset
Download `online_retail_II.xlsx` from the [UCI Repository](https://archive.ics.uci.edu/dataset/502/online+retail+ii) and place it at:

seeds/online_retail_II.xlsx

### 3. Create the connection config
Create a `.bruin.yml` file in the project root with the following content:
```yaml
default_environment: default

environments:
  default:
    connections:
      duckdb:
        - name: duckdb-default
          path: ./uk_retail.duckdb
```

### 4. Run the full pipeline
```bash
bruin run . --config-file .bruin.yml
```

Expected output:
✓ Assets executed 7 succeeded
✓ Quality checks 66 succeeded

---

## Project Structure
uk-retail-analytics-pipeline/
├── .github/
│ └── workflows/
│ └── bruin-pipeline.yml # CI/CD validation on every push
├── assets/
│ ├── raw/
│ │ ├── raw_uk_retail.py # Python ingestion asset
│ │ └── requirements.txt # pandas, openpyxl
│ ├── staging/
│ │ └── stg_retail.sql # Cleaning and enrichment
│ └── mart/
│ ├── mart_monthly_revenue.sql
│ ├── mart_product_performance.sql
│ ├── mart_customer_rfm.sql
│ ├── mart_country_analysis.sql
│ └── mart_cancellation_analysis.sql
├── seeds/ # Dataset lives here, not tracked in git
├── .bruin.yml # DuckDB connection config, not tracked in git
├── .gitignore
└── pipeline.yml # Pipeline definition and daily schedule

---

## Resources

- [Bruin Documentation](https://getbruin.com/docs/bruin/)
- [UCI Online Retail II Dataset](https://archive.ics.uci.edu/dataset/502/online+retail+ii)
- [Bruin Project Competition](https://getbruin.com/competition/)
- [Bruin GitHub](https://github.com/bruin-data/bruin)

---

*Built for the Data Engineering Zoomcamp 2026 — Bruin Project Competition*