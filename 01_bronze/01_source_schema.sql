-- =============================================================================
-- Order-to-Cash Case Study: Source Schema (Bronze / Raw Layer)
-- Company: Data GmbH (fictional FMCG)
--
-- These tables represent a direct extraction from an SAP ECC system.
-- Field names follow SAP naming conventions (VBAK, VBAP, LIKP, etc.).
-- Compatible with: DuckDB, PostgreSQL, SQLite, Databricks SQL (Delta Lake)
--
-- NOTE: Primary keys are logical only — no constraint enforcement.
--       You MUST handle duplicates defensively in your transformations.
-- =============================================================================
--
-- =============================================================================
-- ENTITY-RELATIONSHIP OVERVIEW — Order-to-Cash Flow
-- =============================================================================
--
-- MASTER DATA (lookup / dimension tables)
-- ─────────────────────────────────────────────────────────────────────────────
--   src_kna1    Customer master           PK: kunnr
--   src_mara    Material master           PK: matnr
--   src_makt    Material descriptions     PK: (matnr, spras)   FK: matnr -> src_mara
--   src_t001w   Plants / warehouses       PK: werks
--   src_tvkot   Sales organizations       PK: vkorg
--   src_tvtwt   Distribution channels     PK: vtweg
--   src_tvagt   Rejection reason codes    PK: abgru
--
-- TRANSACTIONAL CHAIN (follows the O2C process step by step)
-- ─────────────────────────────────────────────────────────────────────────────
--
--   [1] SALES ORDER
--       src_vbak  (header)   PK: vbeln
--                             FK: kunnr  -> src_kna1
--                             FK: vkorg  -> src_tvkot
--       src_vbap  (items)    PK: (vbeln, posnr)
--                             FK: vbeln  -> src_vbak           ← order header
--                             FK: matnr  -> src_mara           ← material
--                             FK: werks  -> src_t001w          ← delivering plant
--                             FK: abgru  -> src_tvagt          ← rejection reason (nullable)
--
--   [2] OUTBOUND DELIVERY  (created when warehouse ships goods)
--       src_likp  (header)   PK: vbeln
--                             FK: kunnr  -> src_kna1           ← ship-to customer
--       src_lips  (items)    PK: (vbeln, posnr)
--                             FK: vbeln  -> src_likp           ← delivery header
--                             FK: vgbel  -> src_vbak           ← originating sales order
--                             FK: vgpos  -> src_vbap.posnr     ← originating sales order item
--                             ⚠ One sales order item can appear in MULTIPLE delivery items
--                               (partial deliveries).
--
--   [3] BILLING DOCUMENT  (invoice or credit memo issued to customer)
--       src_vbrk  (header)   PK: vbeln
--                             FK: kunrg  -> src_kna1           ← payer customer
--                             FK: vkorg  -> src_tvkot
--       src_vbrp  (items)    PK: (vbeln, posnr)
--                             FK: vbeln  -> src_vbrk           ← billing header
--                             FK: aubel  -> src_vbak           ← originating sales order
--                             FK: aupos  -> src_vbap.posnr     ← originating sales order item
--                             FK: vgbel  → CONTEXT-DEPENDENT (see below)
--
--       ⚠ VBRP.VGBEL IS CONTEXT-DEPENDENT — critical for joining:
--           fkart = 'F2' (Invoice)     → vgbel is a DELIVERY number  (-> src_likp.vbeln)
--           fkart = 'G2' (Credit memo) → vgbel is a BILLING document (-> src_vbrk.vbeln)
--           Always check src_vbrk.fkart before joining vgbel.
--
--   [4] ACCOUNTS RECEIVABLE  (FI — tracks payment status of invoices)
--       src_bsid  (open AR)    — invoices NOT YET paid
--                             FK: rebzg  -> src_vbrk           ← billing document
--                             FK: kunnr  -> src_kna1
--       src_bsad  (cleared AR) — invoices ALREADY paid (historical record)
--                             FK: rebzg  -> src_vbrk           ← billing document
--                             FK: kunnr  -> src_kna1
--
--       ⚠ SAP CLEARS AR BY MOVING ROWS — a paid invoice is DELETED from BSID
--         and INSERTED into BSAD. 
--

-- =============================================================================
-- MASTER DATA
-- =============================================================================

-- Sales Organizations
CREATE TABLE IF NOT EXISTS src_tvkot (
    vkorg VARCHAR(4),       -- Sales organization key (PK)
    vtext VARCHAR(60)       -- Description
);

-- Distribution Channels
CREATE TABLE IF NOT EXISTS src_tvtwt (
    vtweg VARCHAR(2),       -- Distribution channel key (PK)
    vtext VARCHAR(60)       -- Description
);

-- Plants / Warehouses
CREATE TABLE IF NOT EXISTS src_t001w (
    werks VARCHAR(4),       -- Plant key (PK)
    name1 VARCHAR(60),      -- Plant name
    land1 VARCHAR(3)        -- Country (ISO-2)
);

-- Customer Master
CREATE TABLE IF NOT EXISTS src_kna1 (
    kunnr VARCHAR(10),      -- Customer number (PK)
    name1 VARCHAR(60),      -- Customer name
    land1 VARCHAR(3),       -- Country (ISO-2)
    regio VARCHAR(3),       -- Region / State
    ktokd VARCHAR(4)        -- Account group
);

-- Material Master (General Data)
CREATE TABLE IF NOT EXISTS src_mara (
    matnr VARCHAR(18),      -- Material number (PK)
    matkl VARCHAR(9),       -- Material group
    meins VARCHAR(3),       -- Base unit of measure
    mtart VARCHAR(4)        -- Material type (FERT=Finished, HALB=Semi-finished, ROH=Raw)
);

-- Material Descriptions (one row per material per language)
CREATE TABLE IF NOT EXISTS src_makt (
    matnr VARCHAR(18),      -- Material number (PK part 1)
    spras VARCHAR(2),       -- Language key (PK part 2)
    maktx VARCHAR(40)       -- Material description
);

-- Rejection Reason Codes
CREATE TABLE IF NOT EXISTS src_tvagt (
    abgru VARCHAR(2),       -- Rejection reason code (PK)
    bezei VARCHAR(40)       -- Description
);


-- =============================================================================
-- SALES — SD MODULE
-- =============================================================================

-- Sales Order Header (VBAK)
-- One record per sales order.
CREATE TABLE IF NOT EXISTS src_vbak (
    vbeln  VARCHAR(10),     -- Sales order number (PK)
    erdat  DATE,            -- Order creation date
    auart  VARCHAR(4),      -- Order type: TA=Standard, KR=Credit memo request, RE=Returns
    kunnr  VARCHAR(10),     -- Sold-to customer (FK -> src_kna1)
    vkorg  VARCHAR(4),      -- Sales organization (FK -> src_tvkot)
    vtweg  VARCHAR(2),      -- Distribution channel
    spart  VARCHAR(2),      -- Division (e.g. HA=Hair, AD=Adhesives)
    netwr  DECIMAL(15,2),   -- Net order value (active items only, in document currency)
    waerk  VARCHAR(5),      -- Document currency
    vdatu  DATE             -- Customer-requested delivery date (header level)
);

-- Sales Order Items (VBAP)
-- One record per line item within a sales order.
-- PK: (vbeln, posnr)
CREATE TABLE IF NOT EXISTS src_vbap (
    vbeln  VARCHAR(10),     -- Sales order number          FK -> src_vbak.vbeln
    posnr  VARCHAR(6),      -- Item number (000010, 000020, ...) — part of PK
    matnr  VARCHAR(18),     -- Material number             FK -> src_mara.matnr
    kwmeng DECIMAL(13,3),   -- Ordered quantity (in base UOM)
    meins  VARCHAR(3),      -- Unit of measure
    netpr  DECIMAL(11,2),   -- Net price per UOM (in document currency)
    waerk  VARCHAR(5),      -- Currency (matches src_vbak.waerk for same order)
    werks  VARCHAR(4),      -- Delivering plant            FK -> src_t001w.werks
    pstyv  VARCHAR(4),      -- Item category: TAN=Standard, KRN=Credit memo, TANN=Free item
    abgru  VARCHAR(2)       -- Rejection reason            FK -> src_tvagt.abgru
                            --   NULL or '' = item is ACTIVE (not rejected)
                            --   Any other value = item is REJECTED and must NOT be shipped/billed
);


-- =============================================================================
-- SHIPPING / LOGISTICS — LE MODULE
-- =============================================================================

-- Outbound Delivery Header (LIKP)
-- One record per outbound delivery.
CREATE TABLE IF NOT EXISTS src_likp (
    vbeln     VARCHAR(10),  -- Delivery number (PK)
    erdat     DATE,         -- Delivery creation date
    wadat_ist DATE,         -- Actual goods issue date (NULL if goods not yet issued)
    kunnr     VARCHAR(10),  -- Ship-to customer
    vstel     VARCHAR(4)    -- Shipping point
);

-- Outbound Delivery Items (LIPS)
-- One record per delivery line item.
-- PK: (vbeln, posnr)
-- ⚠ A single sales order item can appear across MULTIPLE delivery items (partial shipments).
--   To get total shipped qty per order item: SUM(lfimg) GROUP BY (vgbel, vgpos)
CREATE TABLE IF NOT EXISTS src_lips (
    vbeln  VARCHAR(10),     -- Delivery number             FK -> src_likp.vbeln
    posnr  VARCHAR(6),      -- Delivery item number — part of PK
    matnr  VARCHAR(18),     -- Material number             FK -> src_mara.matnr
    lfimg  DECIMAL(13,3),   -- Delivered quantity for THIS delivery item (not cumulative)
    meins  VARCHAR(3),      -- UOM
    werks  VARCHAR(4),      -- Plant                       FK -> src_t001w.werks
    vgbel  VARCHAR(10),     -- Originating sales order     FK -> src_vbak.vbeln
    vgpos  VARCHAR(6)       -- Originating sales order item FK -> src_vbap.posnr (for that vgbel)
);


-- =============================================================================
-- BILLING — SD-BIL MODULE
-- =============================================================================

-- Billing Document Header (VBRK)
-- One record per billing document (invoice, credit memo, cancellation).
CREATE TABLE IF NOT EXISTS src_vbrk (
    vbeln  VARCHAR(10),     -- Billing document number (PK)
    erdat  DATE,            -- Creation date
    fkart  VARCHAR(4),      -- Billing type: F2=Invoice, G2=Credit memo, S1=Cancellation
    kunrg  VARCHAR(10),     -- Payer customer (FK -> src_kna1)
    waerk  VARCHAR(5),      -- Document currency
    netwr  DECIMAL(15,2),   -- Net billing value (NEGATIVE for credit memos and cancellations)
    mwsbp  DECIMAL(15,2),   -- Tax amount
    fkdat  DATE,            -- Billing date (use this for revenue recognition, NOT erdat)
    vkorg  VARCHAR(4)       -- Sales organization
);

-- Billing Document Items (VBRP)
-- One record per billing line item.
-- PK: (vbeln, posnr)
CREATE TABLE IF NOT EXISTS src_vbrp (
    vbeln  VARCHAR(10),     -- Billing document number     FK -> src_vbrk.vbeln
    posnr  VARCHAR(6),      -- Billing item number — part of PK
    matnr  VARCHAR(18),     -- Material number             FK -> src_mara.matnr
    fkimg  DECIMAL(13,3),   -- Billed quantity (negative for credit memos)
    meins  VARCHAR(3),      -- UOM
    netwr  DECIMAL(15,2),   -- Item net value (NEGATIVE for credit memos and cancellations)
    aubel  VARCHAR(10),     -- Originating sales order     FK -> src_vbak.vbeln
    aupos  VARCHAR(6),      -- Originating sales order item FK -> src_vbap.posnr (for that aubel)
    vgbel  VARCHAR(10),     -- ⚠ CONTEXT-DEPENDENT reference — join logic differs by fkart:
                            --   fkart = 'F2' (Invoice)    → vgbel is a DELIVERY  FK -> src_likp.vbeln
                            --   fkart = 'G2' (Credit memo) → vgbel is a BILLING  FK -> src_vbrk.vbeln
                            --   Always resolve src_vbrk.fkart BEFORE joining this column.
    vgpos  VARCHAR(6)       -- Reference item number within the vgbel document
);


-- =============================================================================
-- FINANCE — FI-AR MODULE
-- =============================================================================

-- Open Accounts Receivable Items (BSID)
-- Contains AR line items NOT YET CLEARED (payment not yet received).
-- PK: (bukrs, belnr, gjahr, buzei)
--
-- ⚠ SAP CLEARING MECHANICS: When a customer pays, the row is PHYSICALLY DELETED
--   from BSID and INSERTED into BSAD with augdt set to the payment date.
--   A row present in BSID right now may have existed in BSAD yesterday — or vice versa.
CREATE TABLE IF NOT EXISTS src_bsid (
    bukrs  VARCHAR(4),      -- Company code — part of PK
    kunnr  VARCHAR(10),     -- Customer number             FK -> src_kna1.kunnr
    belnr  VARCHAR(10),     -- FI document number — part of PK
    gjahr  INTEGER,         -- Fiscal year — part of PK
    buzei  VARCHAR(3),      -- Line item number — part of PK
    bldat  DATE,            -- FI document posting date
    faedt  DATE,            -- Net due date (payment expected by this date)
    wrbtr  DECIMAL(15,2),   -- Amount in document currency
    waers  VARCHAR(5),      -- Currency
    rebzg  VARCHAR(10)      -- Reference billing document  FK -> src_vbrk.vbeln
);

-- Cleared Accounts Receivable Items (BSAD)
-- Contains AR line items where payment has been received (cleared).
-- PK: (bukrs, belnr, gjahr, buzei) — same key structure as BSID
-- This is the permanent historical record of all paid invoices.
-- ⚠ Same row structure as BSID, plus the augdt (clearing/payment date) column.
CREATE TABLE IF NOT EXISTS src_bsad (
    bukrs  VARCHAR(4),      -- Company code — part of PK
    kunnr  VARCHAR(10),     -- Customer number             FK -> src_kna1.kunnr
    belnr  VARCHAR(10),     -- FI document number — part of PK
    gjahr  INTEGER,         -- Fiscal year — part of PK
    buzei  VARCHAR(3),      -- Line item number — part of PK
    bldat  DATE,            -- FI document posting date
    faedt  DATE,            -- Original due date
    augdt  DATE,            -- Clearing date = actual date payment was received
    wrbtr  DECIMAL(15,2),   -- Amount in document currency
    waers  VARCHAR(5),      -- Currency
    rebzg  VARCHAR(10)      -- Reference billing document (FK -> src_vbrk)
);
