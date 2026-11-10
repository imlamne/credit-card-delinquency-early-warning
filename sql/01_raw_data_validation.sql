/*
Credit Card Delinquency Early Warning — Phase 2 / Task 01
Run in SQL Server Management Studio after using SSMS > Tasks > Import Flat File.
Database: CreditRiskAnalytics
Table name in wizard: dbo.credit_card_raw
Prepared from user-supplied UCI XLS, 2026-11-03.
Preserve this raw table. Do not delete, recode or cap any values at this stage.
*/
USE CreditRiskAnalytics;
GO

-- 1. Check number of rows and uniqueness of customer IDs.
SELECT
    COUNT_BIG(*) AS total_rows,
    COUNT_BIG(DISTINCT ID) AS unique_customer_ids,
    SUM(CASE WHEN ID IS NULL THEN 1 ELSE 0 END) AS null_ids
FROM dbo.credit_card_raw;

-- 2. Check exact duplicate IDs, if any.
SELECT ID, COUNT(*) AS records_per_id
FROM dbo.credit_card_raw
GROUP BY ID
HAVING COUNT(*) > 1;

-- 3. Validate outcome label. The label is an observed outcome, not an intervention effect.
SELECT DEFAULT_NEXT_MONTH AS default_label, COUNT(*) AS customers
FROM dbo.credit_card_raw
GROUP BY DEFAULT_NEXT_MONTH
ORDER BY DEFAULT_NEXT_MONTH;

-- 4. Check all six repayment-status fields, including undocumented codes.
SELECT v.column_name, v.status_code, COUNT(*) AS customers
FROM dbo.credit_card_raw AS r
CROSS APPLY (VALUES
  ('PAY_0',r.PAY_0), ('PAY_2',r.PAY_2), ('PAY_3',r.PAY_3),
  ('PAY_4',r.PAY_4), ('PAY_5',r.PAY_5), ('PAY_6',r.PAY_6)
) AS v(column_name,status_code)
GROUP BY v.column_name,v.status_code
ORDER BY v.column_name,v.status_code;

-- 5. Check negative bill amounts and zero/negative limits; do not auto-fix.
SELECT
  SUM(CASE WHEN LIMIT_BAL <= 0 THEN 1 ELSE 0 END) AS nonpositive_limit_rows,
  SUM(CASE WHEN BILL_AMT1 < 0 OR BILL_AMT2 < 0 OR BILL_AMT3 < 0
             OR BILL_AMT4 < 0 OR BILL_AMT5 < 0 OR BILL_AMT6 < 0 THEN 1 ELSE 0 END) AS customers_with_any_negative_bill,
  MIN(LIMIT_BAL) AS min_credit_limit,
  MAX(LIMIT_BAL) AS max_credit_limit,
  MIN(AGE) AS min_age,
  MAX(AGE) AS max_age
FROM dbo.credit_card_raw;

-- 6. Verify the expected key columns have no nulls.
SELECT
  SUM(CASE WHEN ID IS NULL THEN 1 ELSE 0 END) AS missing_id,
  SUM(CASE WHEN LIMIT_BAL IS NULL THEN 1 ELSE 0 END) AS missing_limit,
  SUM(CASE WHEN PAY_0 IS NULL OR PAY_2 IS NULL OR PAY_3 IS NULL
             OR PAY_4 IS NULL OR PAY_5 IS NULL OR PAY_6 IS NULL THEN 1 ELSE 0 END) AS missing_any_repayment_status,
  SUM(CASE WHEN DEFAULT_NEXT_MONTH IS NULL THEN 1 ELSE 0 END) AS missing_target
FROM dbo.credit_card_raw;
GO
