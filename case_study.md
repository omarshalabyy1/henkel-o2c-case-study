# Analytics Engineering Case Study
## Order-to-Cash Analytics

**Role:** Senior Analytics Engineer  
**Deliverable:** Code repository + presentation

---

## Background

Data GmbH is a global FMCG company with two main business divisions: **Professional Hair Care (HAIRPRO)** and **Industrial Adhesives (ADHESIV)**. The company operates across Europe and North America, with sales organizations in both regions.

You have been given a raw extract from the company's SAP ERP system, covering the **Order-to-Cash (O2C)** process. The data spans from October 2025 to April 2026.

The O2C process at Data GmbH follows this sequence:

```
Customer places order
       ↓
Sales Order created (VBAK / VBAP)
       ↓
Warehouse picks & ships goods
       ↓
Goods Issue posted → Outbound Delivery confirmed (LIKP / LIPS)
       ↓
Finance creates invoice
       ↓
Billing Document issued (VBRK / VBRP)
       ↓
Customer pays
       ↓
Payment matched to invoice → AR item cleared (BSID → BSAD)
```

Your task is to build an **analytics stack** on top of this raw data that enables the Finance, Sales and Operations teams to answer key business questions.

---

## Dataset

You are provided with two SQL files:

| File | Contents |
|---|---|
| `01_source_schema.sql` | DDL for all source tables - run this first |
| `02_sample_data.sql` | INSERT statements with realistic transactional data |

### Source Tables

| Table | SAP Module | Description |
|---|---|---|
| `src_tvkot` | Master | Sales organizations |
| `src_tvtwt` | Master | Distribution channels |
| `src_t001w` | Master | Plants / warehouses |
| `src_kna1` | Master | Customer master |
| `src_mara` | Master | Material master (general) |
| `src_makt` | Master | Material descriptions |
| `src_tvagt` | Master | Rejection reason codes |
| `src_vbak` | SD | Sales order headers |
| `src_vbap` | SD | Sales order items |
| `src_likp` | LE | Outbound delivery headers |
| `src_lips` | LE | Outbound delivery items |
| `src_vbrk` | Billing | Billing document headers |
| `src_vbrp` | Billing | Billing document items |
| `src_bsid` | FI-AR | Open accounts receivable items |
| `src_bsad` | FI-AR | Cleared (paid) accounts receivable items |

You may use **any SQL-based environment**. We recommend DuckDB - it requires no installation or server.

> **Note on the data:** The table relationships and O2C join chain are documented in `01_source_schema.sql`. Read the header section carefully before starting.

---

## Technical Setup

### Option A - DuckDB + Jupyter Notebook (recommended)

Everything runs locally with no server, no admin rights and no external dependencies beyond Python.

**Step 1 - Run the setup script**

```bash
python setup.py
```

This installs the required packages and creates `data.duckdb` with all 15 source tables loaded. Run it once.

**Step 2 - Open the notebook**

Open `starter_notebook.ipynb` in VS Code, select any Python kernel and run the first cell. A ready-to-use DuckDB connection (`con`) is available for the rest of the notebook.

---

### Option B - Any other database

If you prefer a different environment (PostgreSQL, Snowflake, Databricks SQL, etc.), run the two SQL files directly:

```bash
psql -U youruser -d yourdb -f 01_source_schema.sql
psql -U youruser -d yourdb -f 02_sample_data.sql
```

> **Important:** Use the provided schema and sample data files unchanged. Do not modify the source tables (`src_*`).

---

## Your Task

Explore the data and build an analytics layer that enables Finance, Sales and Operations to understand the O2C process. Use any tool, language, or framework you prefer - dbt, plain SQL, Python, notebooks, or any combination.


We expect to see:

- **Data exploration** - Get to know the data before modeling. Surface quality issues, edge cases and anything that would affect downstream analysis.
- **Analytics layer** - Transform the raw source tables into something a business user or analyst can work with directly. Make your design decisions explicit.
- **Business insight** - Derive meaningful conclusions from the data. What story does the O2C data tell about this business?

---

## Deliverables

Share your work as a Git repository, ZIP archive, or equivalent.

---

## Presentation

Prepare a **15-minute presentation** for a mixed audience of engineers and business stakeholders.

Cover whatever you consider most important. At a minimum, address:

1. **What you found** - Data quality, structure, surprises
2. **How you built it** - Your approach and the decisions behind it
3. **What it tells us** - Business-facing conclusions
4. **What comes next** - How would you take this to production?