<p align="center">
  <img width="100%" src="docs/header.svg" alt="Henkel order-to-cash case study. 89 raw SAP rows, 5 layers, 43 data checks: one report that shows where 16,050 EUR waits between order and cash: 4,350 EUR ordered but not shipped, 4,200 EUR shipped but not billed, 7,500 EUR billed but not paid.">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/DuckDB-1.5-FFF000?style=for-the-badge&logo=duckdb&logoColor=black" alt="DuckDB 1.5">
  <img src="https://img.shields.io/badge/SQL-5_layers-3B82F6?style=for-the-badge" alt="SQL in 5 layers">
  <img src="https://img.shields.io/badge/Python-pandas-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python and pandas">
  <img src="https://img.shields.io/badge/Power_BI-PBIP-F2C811?style=for-the-badge&logo=powerbi&logoColor=black" alt="Power BI project">
</p>

<p align="center">
  <img width="100%" src="docs/o2c.gif" alt="Order to cash: a coin walks Order (VBAK/VBAP), Delivery (LIKP/LIPS), Invoice (VBRK/VBRP) and Payment (BSID open, BSAD paid); 4,350 EUR waits ordered but not shipped, 4,200 EUR shipped but not billed, 7,500 EUR billed but not paid: 16,050 EUR in total">
</p>

![Architecture, left to right: the two given SQL files load the Bronze layer (15 src_* tables, 89 rows); Silver cleans them and enforces the keys (18 tables); Gold holds the business rules (9 tables); Semantic is the star schema (3 facts, 7 dimensions); Analytical has one data mart per department (12 views); Power BI reads the marts only (5 pages)](docs/architecture.drawio.svg)

## 📈 Result

| What (EUR, as of 2026-05-04) | Number |
|---|---|
| Net revenue | 13,950 (and 6,000 USD) |
| Ordered, not shipped | 4,350 |
| Shipped, not billed | 4,200 |
| Billed, not paid | 7,500, of which 5,500 overdue |
| Shipped on time | 6 of 8 lines |
| Days to pay | 23.67 |
| Data checks | 43, all passing |

| Overview | Finance |
|---|---|
| ![Overview page](06_reporting/screenshots/02_overview.png) | ![Finance page](06_reporting/screenshots/03_finance.png) |
| **Sales** | **Operations** |
| ![Sales page](06_reporting/screenshots/04_sales.png) | ![Operations page](06_reporting/screenshots/05_operations.png) |

Slides: [pptx](06_reporting/presentation/Henkel_O2C_presentation.pptx) · [pdf](06_reporting/presentation/Henkel_O2C_presentation.pdf)

## 🏗️ Data flow

![Data flow, table by table: 15 Bronze src_* tables (89 rows) feed 18 Silver tables, 9 Gold tables, the star schema of 3 facts and 7 dimensions, and 12 mart views that Power BI reads on 5 pages](docs/data-flow.drawio.svg)

![The star schema in the semantic layer: fact_order_line (13 rows), fact_billing_line (10) and fact_receivable (8) share seven dimensions; every column, primary key and foreign key, one line per foreign key](docs/star-schema.drawio.svg)

## ▶️ Run

```
python setup.py
python run_sql.py
```

Power BI: open `06_reporting/henkel_o2c.pbip`, set the `DuckDbPath` parameter to your `data.duckdb`, refresh.

Details: [`docs/technical.md`](docs/technical.md) · exploration: [`01_exploration.ipynb`](01_exploration.ipynb) · brief: [`case_study.md`](case_study.md)

<p align="center">
  <img width="100%" src="docs/footer.svg" alt="From order to cash, every step checked.">
</p>
