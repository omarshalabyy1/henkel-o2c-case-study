-- =============================================================================
-- Order-to-Cash Case Study: Sample Data
-- Company: Data GmbH (fictional)
--
-- 8 scenarios covering the full O2C spectrum:
--   1. Clean O2C — full delivery, fully billed, paid on time
--   2. Partial deliveries — two shipments, second billing overdue
--   3. Item rejection — one line cancelled, late delivery
--   4. Open backlog — no delivery, past requested date
--   5. Multi-currency (USD) — clean O2C, North America
--   6. Credit memo — customer return from order 1
--   7. Partial billing — delivery complete, one item not yet billed
--   8. Recent order — billed, payment not yet due
-- =============================================================================


-- =============================================================================
-- MASTER DATA
-- =============================================================================

INSERT INTO src_tvkot VALUES
    ('EU01', 'Europe Sales Organization'),
    ('NA01', 'North America Sales Organization');

INSERT INTO src_tvtwt VALUES
    ('10', 'Direct Sales'),
    ('20', 'Retail / Wholesale');

INSERT INTO src_t001w VALUES
    ('DE01', 'Duesseldorf Warehouse',          'DE'),
    ('DE02', 'Hamburg Distribution Center',    'DE'),
    ('US01', 'New Jersey Fulfillment Center',  'US');

INSERT INTO src_kna1 VALUES
    ('C0000001', 'Arcturus Professional GmbH',   'DE', 'NW',  'GP01'),
    ('C0000002', 'SalonCorp USA Inc.',            'US', 'NJ',  'GP01'),
    ('C0000003', 'Beaute Pro SARL',               'FR', 'IDF', 'GP01'),
    ('C0000004', 'ProCare Italia SpA',            'IT', 'LOM', 'GP01'),
    ('C0000005', 'Nordic Hair Solutions AB',      'SE', '26',  'GP01');

INSERT INTO src_mara VALUES
    ('MAT00001', 'HAIRPRO', 'EA', 'FERT'),  -- Professional Shampoo 1L
    ('MAT00002', 'HAIRPRO', 'EA', 'FERT'),  -- Color Treatment Professional
    ('MAT00003', 'ADHESIV', 'KG', 'FERT'),  -- Adhesive Bond XT
    ('MAT00004', 'ADHESIV', 'L',  'FERT'),  -- Surface Prep Liquid
    ('MAT00005', 'HAIRPRO', 'EA', 'FERT');  -- Conditioner Pro 1L

INSERT INTO src_makt VALUES
    ('MAT00001', 'EN', 'Professional Shampoo 1L'),
    ('MAT00002', 'EN', 'Color Treatment Professional'),
    ('MAT00003', 'EN', 'Adhesive Bond XT'),
    ('MAT00004', 'EN', 'Surface Prep Liquid'),
    ('MAT00005', 'EN', 'Conditioner Pro 1L');

INSERT INTO src_tvagt VALUES
    ('01', 'Cancelled by customer'),
    ('02', 'Out of stock'),
    ('03', 'Pricing dispute');


-- =============================================================================
-- SCENARIO 1: Full O2C — on-time delivery, paid on time
-- Order 4500000001 | Customer C0000001 | EUR | Sales Org EU01
--   Item 000010: MAT00001  100 EA x 25.00 EUR =  2,500.00 EUR
--   Item 000020: MAT00005   50 EA x 18.00 EUR =    900.00 EUR
--   Order total:                                 3,400.00 EUR
--   Delivery:  8000000001 | GI 2025-10-13 (ON TIME — requested 2025-10-15)
--   Billing:   9000000001 | 3,400.00 EUR
--   Payment:   Cleared 2025-11-05 (due 2025-11-13 — paid EARLY)
-- =============================================================================

INSERT INTO src_vbak VALUES
    ('4500000001', '2025-10-01', 'TA', 'C0000001', 'EU01', '10', 'HA', 3400.00, 'EUR', '2025-10-15');

INSERT INTO src_vbap VALUES
    ('4500000001', '000010', 'MAT00001', 100.000, 'EA', 25.00, 'EUR', 'DE01', 'TAN', NULL),
    ('4500000001', '000020', 'MAT00005',  50.000, 'EA', 18.00, 'EUR', 'DE01', 'TAN', NULL);

INSERT INTO src_likp VALUES
    ('8000000001', '2025-10-11', '2025-10-13', 'C0000001', 'SH01');

INSERT INTO src_lips VALUES
    ('8000000001', '000010', 'MAT00001', 100.000, 'EA', 'DE01', '4500000001', '000010'),
    ('8000000001', '000020', 'MAT00005',  50.000, 'EA', 'DE01', '4500000001', '000020');

INSERT INTO src_vbrk VALUES
    ('9000000001', '2025-10-14', 'F2', 'C0000001', 'EUR', 3400.00, 646.00, '2025-10-14', 'EU01');

INSERT INTO src_vbrp VALUES
    ('9000000001', '000010', 'MAT00001', 100.000, 'EA', 2500.00, '4500000001', '000010', '8000000001', '000010'),
    ('9000000001', '000020', 'MAT00005',  50.000, 'EA',  900.00, '4500000001', '000020', '8000000001', '000020');

INSERT INTO src_bsad VALUES
    ('EU01', 'C0000001', '1400000001', 2025, '001', '2025-10-14', '2025-11-13', '2025-11-05', 3400.00, 'EUR', '9000000001');


-- =============================================================================
-- SCENARIO 2: Partial deliveries — two shipments, second billing OVERDUE
-- Order 4500000002 | Customer C0000001 | EUR | Sales Org EU01
--   Item 000010: MAT00003  200 KG x 15.00 EUR =  3,000.00 EUR
--   Item 000020: MAT00004  100 L  x  8.00 EUR =    800.00 EUR
--   Order total:                                 3,800.00 EUR
--   Delivery 1: 8000000002 | GI 2025-10-18 (ON TIME)  — 100 KG MAT00003 + 100 L MAT00004
--   Delivery 2: 8000000003 | GI 2025-11-08 (LATE — requested 2025-10-20) — remaining 100 KG MAT00003
--   Billing 1:  9000000002 | 2,300.00 EUR — cleared 2025-11-15
--   Billing 2:  9000000003 | 1,500.00 EUR — OPEN, OVERDUE since 2025-12-10
-- =============================================================================

INSERT INTO src_vbak VALUES
    ('4500000002', '2025-10-05', 'TA', 'C0000001', 'EU01', '10', 'AD', 3800.00, 'EUR', '2025-10-20');

INSERT INTO src_vbap VALUES
    ('4500000002', '000010', 'MAT00003', 200.000, 'KG', 15.00, 'EUR', 'DE01', 'TAN', NULL),
    ('4500000002', '000020', 'MAT00004', 100.000, 'L',   8.00, 'EUR', 'DE01', 'TAN', NULL);

-- First partial delivery — ON TIME
INSERT INTO src_likp VALUES
    ('8000000002', '2025-10-16', '2025-10-18', 'C0000001', 'SH01');

INSERT INTO src_lips VALUES
    ('8000000002', '000010', 'MAT00003', 100.000, 'KG', 'DE01', '4500000002', '000010'),
    ('8000000002', '000020', 'MAT00004', 100.000, 'L',  'DE01', '4500000002', '000020');

-- Second partial delivery — LATE (after requested date 2025-10-20)
INSERT INTO src_likp VALUES
    ('8000000003', '2025-11-06', '2025-11-08', 'C0000001', 'SH01');

INSERT INTO src_lips VALUES
    ('8000000003', '000010', 'MAT00003', 100.000, 'KG', 'DE01', '4500000002', '000010');

-- Billing after first delivery
INSERT INTO src_vbrk VALUES
    ('9000000002', '2025-10-19', 'F2', 'C0000001', 'EUR', 2300.00, 437.00, '2025-10-19', 'EU01');

INSERT INTO src_vbrp VALUES
    ('9000000002', '000010', 'MAT00003', 100.000, 'KG', 1500.00, '4500000002', '000010', '8000000002', '000010'),
    ('9000000002', '000020', 'MAT00004', 100.000, 'L',   800.00, '4500000002', '000020', '8000000002', '000020');

-- Billing after second delivery
INSERT INTO src_vbrk VALUES
    ('9000000003', '2025-11-10', 'F2', 'C0000001', 'EUR', 1500.00, 285.00, '2025-11-10', 'EU01');

INSERT INTO src_vbrp VALUES
    ('9000000003', '000010', 'MAT00003', 100.000, 'KG', 1500.00, '4500000002', '000010', '8000000003', '000010');

-- FI: Billing 1 cleared
INSERT INTO src_bsad VALUES
    ('EU01', 'C0000001', '1400000002', 2025, '001', '2025-10-19', '2025-11-18', '2025-11-15', 2300.00, 'EUR', '9000000002');

-- FI: Billing 2 OPEN — due 2025-12-10, today 2026-05-04 → ~145 days overdue
INSERT INTO src_bsid VALUES
    ('EU01', 'C0000001', '1400000003', 2025, '001', '2025-11-10', '2025-12-10', 1500.00, 'EUR', '9000000003');


-- =============================================================================
-- SCENARIO 3: Item rejection + late delivery
-- Order 4500000003 | Customer C0000003 | EUR | Sales Org EU01
--   Item 000010: MAT00001   50 EA x 25.00 EUR = 1,250.00 EUR  (ACTIVE — delivered & billed)
--   Item 000020: MAT00002   30 EA x 42.00 EUR = 1,260.00 EUR  (REJECTED — abgru='01')
--   Order netwr = 1,250.00 EUR (SAP removes rejected item value from header)
--   Delivery:  8000000004 | GI 2025-10-28 (LATE — requested 2025-10-25, 3 days late)
--   Billing:   9000000004 | 1,250.00 EUR — cleared 2025-11-20
-- =============================================================================

INSERT INTO src_vbak VALUES
    ('4500000003', '2025-10-10', 'TA', 'C0000003', 'EU01', '10', 'HA', 1250.00, 'EUR', '2025-10-25');

INSERT INTO src_vbap VALUES
    ('4500000003', '000010', 'MAT00001', 50.000, 'EA', 25.00, 'EUR', 'DE01', 'TAN', NULL),   -- Active
    ('4500000003', '000020', 'MAT00002', 30.000, 'EA', 42.00, 'EUR', 'DE01', 'TAN', '01');   -- REJECTED

-- Only active item delivered — no delivery for rejected item
INSERT INTO src_likp VALUES
    ('8000000004', '2025-10-26', '2025-10-28', 'C0000003', 'SH01');

INSERT INTO src_lips VALUES
    ('8000000004', '000010', 'MAT00001', 50.000, 'EA', 'DE01', '4500000003', '000010');

INSERT INTO src_vbrk VALUES
    ('9000000004', '2025-10-29', 'F2', 'C0000003', 'EUR', 1250.00, 237.50, '2025-10-29', 'EU01');

INSERT INTO src_vbrp VALUES
    ('9000000004', '000010', 'MAT00001', 50.000, 'EA', 1250.00, '4500000003', '000010', '8000000004', '000010');

INSERT INTO src_bsad VALUES
    ('EU01', 'C0000003', '1400000004', 2025, '001', '2025-10-29', '2025-11-28', '2025-11-20', 1250.00, 'EUR', '9000000004');


-- =============================================================================
-- SCENARIO 4: Open backlog — no delivery, past requested delivery date
-- Order 4500000004 | Customer C0000003 | EUR | Sales Org EU01
--   Item 000010: MAT00005  200 EA x 18.00 EUR =  3,600.00 EUR
--   Item 000020: MAT00003   50 KG x 15.00 EUR =    750.00 EUR
--   Order total:                                 4,350.00 EUR
--   Requested delivery: 2026-04-01 — today 2026-05-04 → 33 days OVERDUE with no shipment
-- =============================================================================

INSERT INTO src_vbak VALUES
    ('4500000004', '2026-03-15', 'TA', 'C0000003', 'EU01', '10', 'HA', 4350.00, 'EUR', '2026-04-01');

INSERT INTO src_vbap VALUES
    ('4500000004', '000010', 'MAT00005', 200.000, 'EA', 18.00, 'EUR', 'DE01', 'TAN', NULL),
    ('4500000004', '000020', 'MAT00003',  50.000, 'KG', 15.00, 'EUR', 'DE01', 'TAN', NULL);

-- No LIKP/LIPS records — no delivery created yet
-- No VBRK/VBRP records — not billed
-- No FI records


-- =============================================================================
-- SCENARIO 5: Multi-currency USD — clean O2C, North America
-- Order 4500000005 | Customer C0000002 | USD | Sales Org NA01
--   Item 000010: MAT00003  500 KG x 12.00 USD =  6,000.00 USD
--   Delivery:  8000000005 | GI 2025-11-17 (ON TIME — requested 2025-11-20)
--   Billing:   9000000005 | 6,000.00 USD — cleared 2025-12-10
-- =============================================================================

INSERT INTO src_vbak VALUES
    ('4500000005', '2025-11-01', 'TA', 'C0000002', 'NA01', '10', 'AD', 6000.00, 'USD', '2025-11-20');

INSERT INTO src_vbap VALUES
    ('4500000005', '000010', 'MAT00003', 500.000, 'KG', 12.00, 'USD', 'US01', 'TAN', NULL);

INSERT INTO src_likp VALUES
    ('8000000005', '2025-11-15', '2025-11-17', 'C0000002', 'SH02');

INSERT INTO src_lips VALUES
    ('8000000005', '000010', 'MAT00003', 500.000, 'KG', 'US01', '4500000005', '000010');

INSERT INTO src_vbrk VALUES
    ('9000000005', '2025-11-18', 'F2', 'C0000002', 'USD', 6000.00, 0.00, '2025-11-18', 'NA01');

INSERT INTO src_vbrp VALUES
    ('9000000005', '000010', 'MAT00003', 500.000, 'KG', 6000.00, '4500000005', '000010', '8000000005', '000010');

INSERT INTO src_bsad VALUES
    ('NA01', 'C0000002', '1400000005', 2025, '001', '2025-11-18', '2025-12-18', '2025-12-10', 6000.00, 'USD', '9000000005');


-- =============================================================================
-- SCENARIO 6: Credit memo — customer C0000001 returns 20 units from order 1
-- Order 4500000006 | auart='KR' (Credit Memo Request) | EUR | Sales Org EU01
--   Item 000010: MAT00001  20 EA x -25.00 EUR = -500.00 EUR
--   Credit memo billing: 9000000006 | fkart='G2' | netwr = -500.00 EUR
--   FI: Cleared (offset against next open invoice from C0000001)
--
-- NOTE: vgbel in VBRP for credit memos references the ORIGINAL BILLING DOCUMENT,
--       not a delivery (there is no outbound delivery for a credit memo).
-- =============================================================================

INSERT INTO src_vbak VALUES
    ('4500000006', '2025-10-20', 'KR', 'C0000001', 'EU01', '10', 'HA', -500.00, 'EUR', NULL);
    --                                                                              ^^^^^ no requested delivery date for credit memos

INSERT INTO src_vbap VALUES
    ('4500000006', '000010', 'MAT00001', 20.000, 'EA', -25.00, 'EUR', 'DE01', 'KRN', NULL);

-- No delivery (credit memos do not have outbound deliveries)

INSERT INTO src_vbrk VALUES
    ('9000000006', '2025-10-22', 'G2', 'C0000001', 'EUR', -500.00, -95.00, '2025-10-22', 'EU01');

INSERT INTO src_vbrp VALUES
    -- vgbel references original invoice 9000000001 (not a delivery)
    ('9000000006', '000010', 'MAT00001', 20.000, 'EA', -500.00, '4500000006', '000010', '9000000001', '000010');

INSERT INTO src_bsad VALUES
    ('EU01', 'C0000001', '1400000006', 2025, '001', '2025-10-22', '2025-11-21', '2025-11-05', -500.00, 'EUR', '9000000006');


-- =============================================================================
-- SCENARIO 7: Full delivery but PARTIAL billing — item 000020 in billing backlog
-- Order 4500000007 | Customer C0000005 | EUR | Sales Org EU01
--   Item 000010: MAT00004  500 L  x  8.00 EUR =  4,000.00 EUR  (delivered AND billed)
--   Item 000020: MAT00002  100 EA x 42.00 EUR =  4,200.00 EUR  (delivered, NOT YET billed)
--   Order total:                                 8,200.00 EUR
--   Delivery:  8000000006 | GI 2026-01-29 (ON TIME — requested 2026-02-01) — FULL delivery
--   Billing:   9000000007 | 4,000.00 EUR (item 000010 only)
--   FI: OPEN — due 2026-03-31, today 2026-05-04 → ~34 days overdue
--   Billing backlog: 4,200.00 EUR (item 000020 — delivered but not billed)
-- =============================================================================

INSERT INTO src_vbak VALUES
    ('4500000007', '2026-01-10', 'TA', 'C0000005', 'EU01', '10', 'HA', 8200.00, 'EUR', '2026-02-01');

INSERT INTO src_vbap VALUES
    ('4500000007', '000010', 'MAT00004', 500.000, 'L',   8.00, 'EUR', 'DE02', 'TAN', NULL),
    ('4500000007', '000020', 'MAT00002', 100.000, 'EA', 42.00, 'EUR', 'DE02', 'TAN', NULL);

INSERT INTO src_likp VALUES
    ('8000000006', '2026-01-27', '2026-01-29', 'C0000005', 'SH01');

INSERT INTO src_lips VALUES
    ('8000000006', '000010', 'MAT00004', 500.000, 'L',  'DE02', '4500000007', '000010'),
    ('8000000006', '000020', 'MAT00002', 100.000, 'EA', 'DE02', '4500000007', '000020');

-- Only item 000010 billed — item 000020 (4,200 EUR) still in billing backlog
INSERT INTO src_vbrk VALUES
    ('9000000007', '2026-01-30', 'F2', 'C0000005', 'EUR', 4000.00, 760.00, '2026-01-30', 'EU01');

INSERT INTO src_vbrp VALUES
    ('9000000007', '000010', 'MAT00004', 500.000, 'L', 4000.00, '4500000007', '000010', '8000000006', '000010');
    -- Item 000020 (MAT00002) has NO billing record yet

INSERT INTO src_bsid VALUES
    ('EU01', 'C0000005', '1400000007', 2026, '001', '2026-01-30', '2026-03-31', 4000.00, 'EUR', '9000000007');


-- =============================================================================
-- SCENARIO 8: Recent order — delivered, billed, payment NOT YET DUE
-- Order 4500000008 | Customer C0000001 | EUR | Sales Org EU01
--   Item 000010: MAT00001  80 EA x 25.00 EUR =  2,000.00 EUR
--   Delivery:  8000000007 | GI 2026-04-25 (ON TIME — requested 2026-05-01)
--   Billing:   9000000008 | 2,000.00 EUR
--   FI: OPEN — due 2026-05-26 (not yet due as of 2026-05-04)
-- =============================================================================

INSERT INTO src_vbak VALUES
    ('4500000008', '2026-04-15', 'TA', 'C0000001', 'EU01', '10', 'HA', 2000.00, 'EUR', '2026-05-01');

INSERT INTO src_vbap VALUES
    ('4500000008', '000010', 'MAT00001', 80.000, 'EA', 25.00, 'EUR', 'DE01', 'TAN', NULL);

INSERT INTO src_likp VALUES
    ('8000000007', '2026-04-23', '2026-04-25', 'C0000001', 'SH01');

INSERT INTO src_lips VALUES
    ('8000000007', '000010', 'MAT00001', 80.000, 'EA', 'DE01', '4500000008', '000010');

INSERT INTO src_vbrk VALUES
    ('9000000008', '2026-04-26', 'F2', 'C0000001', 'EUR', 2000.00, 380.00, '2026-04-26', 'EU01');

INSERT INTO src_vbrp VALUES
    ('9000000008', '000010', 'MAT00001', 80.000, 'EA', 2000.00, '4500000008', '000010', '8000000007', '000010');

INSERT INTO src_bsid VALUES
    ('EU01', 'C0000001', '1400000008', 2026, '001', '2026-04-26', '2026-05-26', 2000.00, 'EUR', '9000000008');
