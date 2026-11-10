/*
CREDIT CARD DELINQUENCY EARLY WARNING | 04 - ANALYTICAL MODEL
Business question: How does repayment history relate to next-month default?
Source: dbo.credit_card_raw (UCI dataset, Apr-Sep 2005).
Output: 2 views, data checks, and a behavioral baseline.
Run after raw data validation. Raw data is not modified.
*/
USE CreditRiskAnalytics;
GO

-- 1. Customer-month view: one row per customer per month for analyzing repayment changes.
CREATE OR ALTER VIEW dbo.vw_credit_customer_month AS
SELECT
    r.ID AS customer_id,
    m.month_start,
    m.month_order,
    m.repayment_status_raw,
    CASE
        WHEN m.repayment_status_raw BETWEEN 1 AND 9 THEN 'DELAY'
        WHEN m.repayment_status_raw = -1 THEN 'PAY_DULY'
        ELSE 'UNKNOWN'
    END AS status_group,
    CASE WHEN m.repayment_status_raw BETWEEN 1 AND 9 THEN 1 ELSE 0 END AS documented_delay_flag,
    CASE WHEN m.repayment_status_raw IS NULL
              OR (m.repayment_status_raw <> -1 AND m.repayment_status_raw NOT BETWEEN 1 AND 9)
         THEN 1 ELSE 0 END AS unknown_status_flag,
    m.bill_amount,
    m.payment_amount,
    CASE WHEN m.bill_amount < 0 THEN 1 ELSE 0 END AS negative_bill_flag,
    CASE WHEN m.bill_amount = 0 THEN 1 ELSE 0 END AS zero_bill_flag,
    CASE WHEN m.payment_amount = 0 THEN 1 ELSE 0 END AS zero_payment_flag,
    r.LIMIT_BAL AS credit_limit,
    r.DEFAULT_NEXT_MONTH AS default_next_month
FROM dbo.credit_card_raw AS r
CROSS APPLY (VALUES
    (1, CONVERT(date, '20050401', 112), r.PAY_6, r.BILL_AMT6, r.PAY_AMT6),
    (2, CONVERT(date, '20050501', 112), r.PAY_5, r.BILL_AMT5, r.PAY_AMT5),
    (3, CONVERT(date, '20050601', 112), r.PAY_4, r.BILL_AMT4, r.PAY_AMT4),
    (4, CONVERT(date, '20050701', 112), r.PAY_3, r.BILL_AMT3, r.PAY_AMT3),
    (5, CONVERT(date, '20050801', 112), r.PAY_2, r.BILL_AMT2, r.PAY_AMT2),
    (6, CONVERT(date, '20050901', 112), r.PAY_0, r.BILL_AMT1, r.PAY_AMT1)
) AS m(month_order, month_start, repayment_status_raw, bill_amount, payment_amount);
GO

-- 2. Customer features: summarize six months into one row per customer.
CREATE OR ALTER VIEW dbo.vw_credit_customer_features AS
SELECT
    customer_id,
    COUNT(*) AS observed_months,
    SUM(documented_delay_flag) AS documented_delay_months,
    SUM(unknown_status_flag) AS unknown_status_months,
    MAX(CASE WHEN documented_delay_flag = 1 THEN repayment_status_raw END) AS max_documented_delay_code,
    MAX(CASE WHEN month_order = 6 THEN repayment_status_raw END) AS september_status_raw,
    MAX(credit_limit) AS credit_limit,
    MAX(CAST(default_next_month AS int)) AS default_next_month
FROM dbo.vw_credit_customer_month
GROUP BY customer_id;
GO

-- 3. Reconcile row counts and default cases before using analytical views.
SELECT
    (SELECT COUNT(*) FROM dbo.credit_card_raw) AS raw_customers,
    (SELECT COUNT(*) FROM dbo.vw_credit_customer_month) AS customer_month_rows,
    (SELECT COUNT(*) FROM dbo.vw_credit_customer_features) AS feature_customers,
    (SELECT SUM(CAST(DEFAULT_NEXT_MONTH AS int)) FROM dbo.credit_card_raw) AS raw_default_cases,
    (SELECT SUM(default_next_month) FROM dbo.vw_credit_customer_features) AS feature_default_cases;
-- Expected for this UCI file: 30000 | 180000 | 30000 | 6636 | 6636.

-- 4. Find duplicate customer-month records (expected: no rows).
SELECT customer_id, month_start, COUNT(*) AS records
FROM dbo.vw_credit_customer_month
GROUP BY customer_id, month_start
HAVING COUNT(*) > 1;

-- 5. Find customers without exactly six months (expected: no rows).
SELECT customer_id, observed_months
FROM dbo.vw_credit_customer_features
WHERE observed_months <> 6;

-- 6. Review all repayment codes, including any new UNKNOWN values.
SELECT repayment_status_raw, status_group, COUNT(*) AS customer_month_records
FROM dbo.vw_credit_customer_month
GROUP BY repayment_status_raw, status_group
ORDER BY repayment_status_raw;

-- 7. Check financial flags (customer-month counts, not unique customer counts).
SELECT
    SUM(negative_bill_flag) AS negative_bill_months,
    SUM(zero_bill_flag) AS zero_bill_months,
    SUM(zero_payment_flag) AS zero_payment_months
FROM dbo.vw_credit_customer_month;
-- Expected for this UCI file: 3932 | 18105 | 36897.

-- 8. Behavioral baseline: next-month default rate by documented delay months.
SELECT
    documented_delay_months,
    COUNT(*) AS customers,
    SUM(default_next_month) AS default_cases,
    CAST(100.0 * SUM(default_next_month) / NULLIF(COUNT(*), 0) AS decimal(8,2)) AS default_rate_pct,
    SUM(CASE WHEN unknown_status_months > 0 THEN 1 ELSE 0 END) AS customers_with_unknown_status
FROM dbo.vw_credit_customer_features
GROUP BY documented_delay_months
ORDER BY documented_delay_months;
-- Interpret 0 delay months carefully: UNKNOWN does not mean PAY_DULY.
GO
