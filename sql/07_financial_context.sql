/*
07 | FINANCIAL CONTEXT BY RISK SEGMENT  (SQL Server, read-only)
Business question: Do candidate risk segments differ in credit limit and recent bill/payment amounts?
Important: LIMIT_BAL and BILL_AMT are NOT EAD. No causal or intervention effect claims.
*/
USE CreditRiskAnalytics;
GO

-- 1. Add financial context to the eight validated risk segments (one row per customer).
WITH customer_context AS (
    SELECT
        f.customer_id,
        m.status_group AS september_status,
        CASE
            WHEN f.documented_delay_months = 0 THEN '0_DELAY_MONTHS'
            WHEN f.documented_delay_months = 1 THEN '1_DELAY_MONTH'
            ELSE '2PLUS_DELAY_MONTHS'
        END AS delay_history,
        f.default_next_month,
        f.credit_limit,
        m.bill_amount AS september_bill,
        m.payment_amount AS september_payment
    FROM dbo.vw_credit_customer_features AS f
    JOIN dbo.vw_credit_customer_month AS m
      ON f.customer_id = m.customer_id
     AND m.month_start = CONVERT(date, '20050901', 112)
)
SELECT
    september_status,
    delay_history,
    COUNT(*) AS customers,
    SUM(default_next_month) AS default_cases,
    CAST(100.0 * SUM(default_next_month) / NULLIF(COUNT(*), 0) AS decimal(8,2)) AS default_rate_pct,
    CAST(AVG(CAST(credit_limit AS decimal(18,2))) AS decimal(18,0)) AS avg_credit_limit,
    CAST(AVG(CAST(september_bill AS decimal(18,2))) AS decimal(18,0)) AS avg_september_bill,
    CAST(AVG(CAST(september_payment AS decimal(18,2))) AS decimal(18,0)) AS avg_september_payment,
    SUM(CASE WHEN september_bill <= 0 THEN 1 ELSE 0 END) AS nonpositive_bills
FROM customer_context
GROUP BY september_status, delay_history
ORDER BY default_cases DESC;

-- 2. Validate that the September JOIN still has 30,000 customers and 6,636 defaults.
SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT f.customer_id) AS unique_customers,
    SUM(f.default_next_month) AS default_cases
FROM dbo.vw_credit_customer_features AS f
JOIN dbo.vw_credit_customer_month AS m
  ON f.customer_id = m.customer_id
 AND m.month_start = CONVERT(date, '20050901', 112);
-- Expected: 30000 | 30000 | 6636.
GO
