/*
Credit Risk Analytics | Phase 2 - Data Understanding
Task 02: Data Quality Audit (read-only; no data modifications)
Precondition: dbo.credit_card_raw imported and raw reconciliation passed.
This script highlights exceptions. Exception != error; investigate before recoding.
*/
USE CreditRiskAnalytics;
GO

-- A. Profile encoded categories. The values are source codes, not yet business labels.
SELECT v.column_name, v.category_code, COUNT_BIG(*) AS customer_count
FROM dbo.credit_card_raw AS r
CROSS APPLY (VALUES
 ('SEX', CAST(r.SEX AS int)),
 ('EDUCATION', CAST(r.EDUCATION AS int)),
 ('MARRIAGE', CAST(r.MARRIAGE AS int))
) AS v(column_name, category_code)
GROUP BY v.column_name, v.category_code
ORDER BY v.column_name, v.category_code;

-- B. Repayment status by historical month. Preserve raw codes -2 and 0.
SELECT v.month_label, v.status_code, COUNT_BIG(*) AS customer_count
FROM dbo.credit_card_raw AS r
CROSS APPLY (VALUES
 ('2005-09', r.PAY_0), ('2005-08', r.PAY_2),
 ('2005-07', r.PAY_3), ('2005-06', r.PAY_4),
 ('2005-05', r.PAY_5), ('2005-04', r.PAY_6)
) AS v(month_label, status_code)
GROUP BY v.month_label, v.status_code
ORDER BY v.month_label, v.status_code;

-- C. Bill amount audit: negatives and zeros by month; do NOT drop or cap.
SELECT v.month_label,
 COUNT_BIG(*) AS rows_checked,
 SUM(CASE WHEN v.bill_amount < 0 THEN 1 ELSE 0 END) AS negative_bills,
 SUM(CASE WHEN v.bill_amount = 0 THEN 1 ELSE 0 END) AS zero_bills,
 MIN(v.bill_amount) AS min_bill,
 MAX(v.bill_amount) AS max_bill
FROM dbo.credit_card_raw AS r
CROSS APPLY (VALUES
 ('2005-09',r.BILL_AMT1),('2005-08',r.BILL_AMT2),
 ('2005-07',r.BILL_AMT3),('2005-06',r.BILL_AMT4),
 ('2005-05',r.BILL_AMT5),('2005-04',r.BILL_AMT6)
) AS v(month_label,bill_amount)
GROUP BY v.month_label
ORDER BY v.month_label;

-- D. Payment amount audit: negative and zero values by month.
SELECT v.month_label,
 COUNT_BIG(*) AS rows_checked,
 SUM(CASE WHEN v.payment_amount < 0 THEN 1 ELSE 0 END) AS negative_payments,
 SUM(CASE WHEN v.payment_amount = 0 THEN 1 ELSE 0 END) AS zero_payments,
 MIN(v.payment_amount) AS min_payment,
 MAX(v.payment_amount) AS max_payment
FROM dbo.credit_card_raw AS r
CROSS APPLY (VALUES
 ('2005-09',r.PAY_AMT1),('2005-08',r.PAY_AMT2),
 ('2005-07',r.PAY_AMT3),('2005-06',r.PAY_AMT4),
 ('2005-05',r.PAY_AMT5),('2005-04',r.PAY_AMT6)
) AS v(month_label,payment_amount)
GROUP BY v.month_label
ORDER BY v.month_label;

-- E. Range and label audit. Check rather than silently modifying outliers.
SELECT COUNT_BIG(*) AS total_customers,
 SUM(CASE WHEN LIMIT_BAL <= 0 THEN 1 ELSE 0 END) AS nonpositive_credit_limit,
 MIN(LIMIT_BAL) AS min_credit_limit,
 MAX(LIMIT_BAL) AS max_credit_limit,
 MIN(AGE) AS min_age,
 MAX(AGE) AS max_age,
 SUM(CASE WHEN AGE <= 0 THEN 1 ELSE 0 END) AS nonpositive_age,
 SUM(CASE WHEN DEFAULT_NEXT_MONTH NOT IN (0,1) OR DEFAULT_NEXT_MONTH IS NULL THEN 1 ELSE 0 END) AS invalid_or_missing_target
FROM dbo.credit_card_raw;

-- F. Reconciliation for six month reshaping expected in later phases.
SELECT COUNT_BIG(*) AS customer_rows,
 COUNT_BIG(*) * 6 AS expected_customer_month_rows,
 COUNT_BIG(DISTINCT ID) AS unique_customer_ids
FROM dbo.credit_card_raw;
GO
